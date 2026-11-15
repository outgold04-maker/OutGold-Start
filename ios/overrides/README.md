# OutGold Start — Continuação iOS (15/11/2026)

**Referência visual obrigatória:** Android OutGold Start Signature 5D **v5.1.6**, sem decoração natalina.

## O que está preservado

O pacote original `ios/OutGoldStart_iOS26_SOURCE.zip` contém a interface HTML e o ícone utilizados na adaptação. O pipeline descompacta esse pacote e **não modifica** `OutGoldStart/Resources/index.html` nem `Assets.xcassets`. Assim, ficam preservados o logotipo original OutGold, fundo de mármore preto, ouro metálico, animações/brilho, painel de alarmes, as cores RGB fixas e a disposição visual aprovada.

## O que esta alteração implementa

- `OutGoldAlarmScheduler.swift`: sincronização idempotente por assinatura do alarme; cria substitutos antes de cancelar alarmes existentes; se um agendamento falhar, tenta desfazer apenas os novos, preservando os alarmes anteriores; aceita IDs numéricos ou em texto.
- `OutGoldWebView.swift`: sincronização após carregar a interface, interface com AlarmKit para teste de 15 segundos, áudio falado em português brasileiro pelo sintetizador do iOS **enquanto o app está em primeiro plano**, feedback tátil básico, e relatório de status sem afirmar que possui uma Activity Android de tela cheia.
- `.github/workflows/verificar-ios.yml`: prepara a fonte já aprovada, sobrepõe apenas os dois arquivos nativos e tenta compilar para iOS Simulator usando Xcode em macOS. A automação também é executada em pull requests.

## Como compilar

No Mac, obtenha o repositório e execute:

```sh
unzip ios/OutGoldStart_iOS26_SOURCE.zip
cp ios/overrides/OutGoldAlarmScheduler.swift outgold-ios-project/OutGoldStart/OutGoldAlarmScheduler.swift
cp ios/overrides/OutGoldWebView.swift outgold-ios-project/OutGoldStart/OutGoldWebView.swift
cd outgold-ios-project
brew install xcodegen
xcodegen generate
open OutGoldStart.xcodeproj
```

Configure sua equipe Apple e o identificador do app no Xcode. O destino mínimo é **iOS 26**. Uma compilação para simulador sem assinatura **não equivale** a um IPA instalável.

## Testes necessários em iPhone físico

1. Conferir a identidade visual e a fidelidade do HTML v5.1.6, incluindo as 120 cores e o brilho.
2. Dar permissão ao AlarmKit e testar o alarme nativo de 15 segundos.
3. Testar alarme com tela apagada, aparelho bloqueado, modo silencioso e modo Foco.
4. Criar, modificar, desativar e excluir alarmes únicos e semanais; verificar que não há duplicações ou alarmes perdidos.
5. Reiniciar o aparelho e validar que os alarmes continuam agendados.
6. Verificar a voz no aplicativo aberto.
7. Avaliar a integração de sons importados, músicas, seleção de vozes, fala simultânea ao toque, vibração avançada, soneca e férias: **não são equivalentes ao Android nesta etapa**.

## Status transparente

**Projeto fonte em evolução; não publicado para instalação iOS.** Não há evidência de homologação em iPhone real, certificado Apple ou build assinado para TestFlight/App Store. A voz em segundo plano e a personalização do alarme do sistema dependem de implementação adicional e dos limites documentados do AlarmKit. A aprovação da versão Android não deve ser interpretada como aprovação da versão iOS.

Fontes técnicas: [Apple AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit), [Apple TestFlight](https://developer.apple.com/testflight/).

*OutGold Tecnologia — respeitar integralmente o visual aprovado.*
