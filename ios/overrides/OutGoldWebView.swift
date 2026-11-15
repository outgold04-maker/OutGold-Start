import SwiftUI
import WebKit
import AVFoundation
import UIKit

/// Reuses the exact approved OutGold Start v5.1.6 HTML, logo and visual assets.
/// iOS alarms are scheduled using AlarmKit, not background JavaScript timers.
struct OutGoldWebView: UIViewRepresentable {
    func makeCoordinator() -> BridgeCoordinator { BridgeCoordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "outgoldBridge")
        controller.addUserScript(WKUserScript(
            source: Self.bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class BridgeCoordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        private let speechSynthesizer = AVSpeechSynthesizer()

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore/synchronize saved alarms after a restart, without
            // requesting authorization when the user's list is empty.
            webView.evaluateJavaScript(
                "if(window.NativeAlarm && window.NativeAlarm.syncAlarms) { " +
                "window.NativeAlarm.syncAlarms(window.NativeAlarm.getAlarms()); }",
                completionHandler: nil
            )
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let payload = message.body as? [String: Any],
                  let action = payload["action"] as? String else { return }

            switch action {
            case "syncAlarms":
                guard let raw = payload["alarms"] as? String else { return }
                Task { @MainActor in
                    let success = await OutGoldAlarmScheduler.shared.synchronize(json: raw)
                    let active = Self.hasEnabledAlarms(raw)
                    self.updateStatus(
                        available: success && active,
                        speech: true,
                        error: success ? nil : "Verifique a permissao ou os dados do alarme."
                    )
                }

            case "testAlarm":
                Task { @MainActor in
                    let success = await OutGoldAlarmScheduler.shared.scheduleShortTest()
                    self.showMessage(success
                        ? "Teste nativo programado para daqui a 15 segundos."
                        : "Falha no teste. Confira a permissao de AlarmKit no iPhone.")
                }

            case "speak":
                let args = payload["args"] as? [Any] ?? []
                let text = (args.first as? String) ??
                    ((args.first as? [String: Any])?["text"] as? String) ?? ""
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { @MainActor in
                        self.speechSynthesizer.stopSpeaking(at: .immediate)
                        try? AVAudioSession.sharedInstance().setCategory(
                            .playback, mode: .spokenAudio, options: [.duckOthers]
                        )
                        let utterance = AVSpeechUtterance(string: text)
                        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
                        self.speechSynthesizer.speak(utterance)
                    }
                }

            case "stopVoice":
                Task { @MainActor in
                    self.speechSynthesizer.stopSpeaking(at: .immediate)
                }

            case "vibrate":
                Task { @MainActor in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

            default:
                break
            }
        }

        private static func hasEnabledAlarms(_ json: String) -> Bool {
            guard let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let list = object as? [[String: Any]] else {
                return false
            }
            return list.contains { ($0["enabled"] as? Bool) == true }
        }

        @MainActor
        private func updateStatus(available: Bool, speech: Bool, error: String?) {
            // AlarmKit uses Apple's alarm presentation; it doesn't grant a
            // third-party Android-style full-screen Activity.
            var result: [String: Any] = [
                "exactAlarm": available,
                "notifications": available,
                "api": "iOS 26 AlarmKit",
                "fullScreen": false,
                "tts": speech
            ]
            if let error { result["error"] = error }
            guard let data = try? JSONSerialization.data(withJSONObject: result),
                  let status = String(data: data, encoding: .utf8) else { return }
            let literal = Self.javascriptString(status)
            webView?.evaluateJavaScript(
                "localStorage.setItem('outgold_native_status', \(literal));" +
                "window.dispatchEvent(new Event('outgold:native-status'));",
                completionHandler: nil
            )
        }

        @MainActor
        private func showMessage(_ message: String) {
            webView?.evaluateJavaScript("alert(\(Self.javascriptString(message)));", completionHandler: nil)
        }

        private static func javascriptString(_ string: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: string, options: .fragmentsAllowed),
                  let encoded = String(data: data, encoding: .utf8) else { return "\"\"" }
            return encoded
        }
    }

    // The approved page keeps its layout, animations, colors and logo.
    // The bridge only adapts Android-specific native calls to iOS.
    private static let bridgeScript = #"""
    (function() {
      const bridge = (action, data) => {
        try { window.webkit.messageHandlers.outgoldBridge.postMessage(Object.assign({action}, data || {})); }
        catch (e) { console.warn('OutGold native bridge:', e); }
      };
      const json = (key, initial) => localStorage.getItem(key) || initial;
      window.NativeAlarm = {
        getAlarms: () => json('outgold_alarm_v1', '[]'),
        syncAlarms: (alarms) => {
          const raw = typeof alarms === 'string' ? alarms : JSON.stringify(alarms || []);
          localStorage.setItem('outgold_alarm_v1', raw);
          bridge('syncAlarms', {alarms: raw});
        },
        getSounds: () => json('outgold_ios_sounds', '[]'),
        saveSounds: (list) => localStorage.setItem('outgold_ios_sounds', list),
        getSlots: () => json('outgold_ios_slots', '{}'),
        saveSlot: (id, uri) => {
          const slots = JSON.parse(json('outgold_ios_slots', '{}'));
          slots[id] = uri;
          localStorage.setItem('outgold_ios_slots', JSON.stringify(slots));
        },
        removeSlot: (id) => {
          const slots = JSON.parse(json('outgold_ios_slots', '{}'));
          delete slots[id];
          localStorage.setItem('outgold_ios_slots', JSON.stringify(slots));
        },
        getVoices: () => '[]',
        saveVoice: (s) => localStorage.setItem('outgold_ios_voice', s),
        saveLighting: (s) => localStorage.setItem('outgold_alarm_lighting_v1', s),
        setVacationUntil: (v) => localStorage.setItem('outgold_ios_vacation', v || ''),
        getStatus: () => json('outgold_native_status',
          '{"exactAlarm":false,"notifications":false,"api":"iOS 26 AlarmKit","fullScreen":false,"tts":true}'),
        testAlarm: () => bridge('testAlarm'),
        speak: (...args) => bridge('speak', {args}),
        stopVoice: () => bridge('stopVoice'),
        vibrate: (pattern) => bridge('vibrate', {pattern}),
        previewSound: () => {},
        stopPreview: () => {},
        pickSound: () => alert('Importacao de sons ainda indisponivel no iOS.'),
        openFullScreenSettings: () => {}
      };
    })();
    """#
}
