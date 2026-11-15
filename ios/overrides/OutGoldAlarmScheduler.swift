import Foundation
import SwiftUI
import AlarmKit

/// AlarmKit engine for OutGold Start iOS 26+.
/// Keeps the existing approved HTML/branding untouched.
struct OutGoldMetadata: AlarmMetadata { }

@MainActor
final class OutGoldAlarmScheduler {
    static let shared = OutGoldAlarmScheduler()

    private let manager = AlarmManager.shared
    private let defaults = UserDefaults.standard
    private let mappingKey = "outgold_ios_alarm_identifiers_v1"
    private let signatureKey = "outgold_ios_alarm_signatures_v2"

    private init() {}

    /// Returns true only when the desired alarm set has been synchronized.
    /// New/changed alarms are scheduled BEFORE previous alarms are cancelled.
    /// A scheduling error therefore doesn't erase previously working alarms.
    func synchronize(json: String) async -> Bool {
        guard let data = json.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return false
        }

        var desired: [(key: String, schedule: Alarm.Schedule, signature: String)] = []
        var seen = Set<String>()
        for item in items where isEnabled(item) {
            guard let key = alarmID(item), !key.isEmpty,
                  !seen.contains(key),
                  let schedule = makeSchedule(item),
                  let signatureData = try? JSONSerialization.data(withJSONObject: item, options: [.sortedKeys]),
                  let signature = String(data: signatureData, encoding: .utf8) else {
                return false
            }
            seen.insert(key)
            desired.append((key, schedule, signature))
        }

        if !desired.isEmpty {
            do {
                guard try await manager.requestAuthorization() == .authorized else {
                    return false
                }
            } catch {
                NSLog("OutGold: AlarmKit authorization failed: %@", String(describing: error))
                return false
            }
        }

        let existing = defaults.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
        let signatures = defaults.dictionary(forKey: signatureKey) as? [String: String] ?? [:]
        var next = existing
        var nextSignatures = signatures
        let wanted = Set(desired.map(\.key))
        var newlyScheduled: [UUID] = []

        // Phase 1: do not cancel the existing alerts until replacements are ready.
        for item in desired {
            if existing[item.key] != nil, signatures[item.key] == item.signature {
                continue
            }
            let id = UUID()
            let alert = AlarmPresentation.Alert(
                title: "OutGold Start",
                stopButton: AlarmButton(text: "Parar", textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: nil,
                secondaryButtonBehavior: nil
            )
            let attributes = AlarmAttributes<OutGoldMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: OutGoldMetadata(),
                tintColor: Color(red: 0.91, green: 0.70, blue: 0.25)
            )
            let config: AlarmManager.AlarmConfiguration<OutGoldMetadata> = .alarm(
                schedule: item.schedule,
                attributes: attributes
            )
            do {
                _ = try await manager.schedule(id: id, configuration: config)
                newlyScheduled.append(id)
                next[item.key] = id.uuidString
                nextSignatures[item.key] = item.signature
            } catch {
                // Roll back ONLY the new alarms. Previously working alarms remain.
                for newID in newlyScheduled { try? manager.cancel(id: newID) }
                NSLog("OutGold: AlarmKit scheduling failed: %@", String(describing: error))
                return false
            }
        }

        // Phase 2: remove alarms the user disabled/deleted or replaced.
        for (key, uuidString) in existing {
            if !wanted.contains(key) || next[key] != uuidString {
                if let id = UUID(uuidString: uuidString) {
                    do {
                        try manager.cancel(id: id)
                    } catch {
                        // Persist the replacement mapping, but do not report full success.
                        defaults.set(next, forKey: mappingKey)
                        defaults.set(nextSignatures, forKey: signatureKey)
                        NSLog("OutGold: Could not cancel outdated alarm: %@", String(describing: error))
                        return false
                    }
                }
            }
        }

        for key in Array(next.keys) where !wanted.contains(key) {
            next.removeValue(forKey: key)
            nextSignatures.removeValue(forKey: key)
        }

        defaults.set(next, forKey: mappingKey)
        defaults.set(nextSignatures, forKey: signatureKey)
        return true
    }

    func scheduleShortTest() async -> Bool {
        do {
            guard try await manager.requestAuthorization() == .authorized else { return false }
            let presentation = AlarmPresentation.Alert(
                title: "Teste OutGold Start",
                stopButton: AlarmButton(text: "Parar", textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: nil,
                secondaryButtonBehavior: nil
            )
            let attributes = AlarmAttributes<OutGoldMetadata>(
                presentation: AlarmPresentation(alert: presentation),
                metadata: OutGoldMetadata(),
                tintColor: .yellow
            )
            let configuration: AlarmManager.AlarmConfiguration<OutGoldMetadata> = .alarm(
                schedule: .fixed(Date().addingTimeInterval(15)),
                attributes: attributes
            )
            _ = try await manager.schedule(id: UUID(), configuration: configuration)
            return true
        } catch {
            NSLog("OutGold: Test alarm failed: %@", String(describing: error))
            return false
        }
    }

    private func isEnabled(_ alarm: [String: Any]) -> Bool {
        if let enabled = alarm["enabled"] as? Bool { return enabled }
        if let enabled = alarm["enabled"] as? NSNumber { return enabled.boolValue }
        return false
    }

    private func alarmID(_ alarm: [String: Any]) -> String? {
        if let id = alarm["id"] as? String { return id }
        if let id = alarm["id"] as? NSNumber { return id.stringValue }
        return nil
    }

    private func makeSchedule(_ alarm: [String: Any]) -> Alarm.Schedule? {
        guard let time = alarm["time"] as? String else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }

        if let timestamp = alarm["oneTimeAt"] as? NSNumber, timestamp.doubleValue > 0 {
            let date = Date(timeIntervalSince1970: timestamp.doubleValue / 1_000)
            return date > Date() ? .fixed(date) : nil
        }

        if let day = alarm["date"] as? String, !day.isEmpty {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            guard let date = formatter.date(from: "\(day) \(time)"), date > Date() else {
                return nil
            }
            return .fixed(date)
        }

        let at = Alarm.Schedule.Relative.Time(hour: parts[0], minute: parts[1])
        let weekdays: [Locale.Weekday] = (alarm["days"] as? [Int] ?? []).compactMap {
            switch $0 {
            case 0: .sunday
            case 1: .monday
            case 2: .tuesday
            case 3: .wednesday
            case 4: .thursday
            case 5: .friday
            case 6: .saturday
            default: nil
            }
        }
        return .relative(.init(time: at, repeats: weekdays.isEmpty ? .never : .weekly(weekdays)))
    }
}
