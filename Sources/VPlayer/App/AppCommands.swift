import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandMenu("Controle") {
            Button("Tocar ou Pausar") {
                NotificationCenter.default.post(name: .vplayerTogglePlay, object: nil)
            }
            .keyboardShortcut(" ", modifiers: [.option])

            Button("Próxima Faixa") {
                NotificationCenter.default.post(name: .vplayerNext, object: nil)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Button("Faixa Anterior") {
                NotificationCenter.default.post(name: .vplayerPrevious, object: nil)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Divider()

            Button("Aumentar Volume") {
                NotificationCenter.default.post(name: .vplayerVolumeUp, object: nil)
            }
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button("Diminuir Volume") {
                NotificationCenter.default.post(name: .vplayerVolumeDown, object: nil)
            }
            .keyboardShortcut(.downArrow, modifiers: .command)

            Divider()

            Button("Abrir Arquivos…") {
                NotificationCenter.default.post(name: .vplayerOpenFiles, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Aleatório") {
                NotificationCenter.default.post(name: .vplayerToggleShuffle, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Repetição") {
                NotificationCenter.default.post(name: .vplayerCycleRepeat, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Exibir/Ocultar Fila") {
                NotificationCenter.default.post(name: .vplayerTogglePlaylist, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Exibir/Ocultar Painel Lateral") {
                NotificationCenter.default.post(name: .vplayerToggleConsole, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .newItem) {
            Button("Abrir Arquivos…") {
                NotificationCenter.default.post(name: .vplayerOpenFiles, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}
