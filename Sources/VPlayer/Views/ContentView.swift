import SwiftUI

enum ConsoleTab: String, CaseIterable, Identifiable {
    case equalizer
    case effects
    case lyrics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equalizer: return "Equalizador"
        case .effects: return "Efeitos"
        case .lyrics: return "Letras"
        }
    }

    var symbol: String {
        switch self {
        case .equalizer: return "slider.vertical.3"
        case .effects: return "wand.and.stars"
        case .lyrics: return "text.quote"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @State private var consoleTab: ConsoleTab = .equalizer

    var body: some View {
        HSplitView {
            if player.showPlaylist {
                PlaylistView()
                    .frame(minWidth: 230, idealWidth: 270, maxWidth: 380)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                NowPlayingView(consoleTab: $consoleTab)
                Divider()
                PlayerBarView()
            }
            .frame(minWidth: player.showPlaylist ? 580 : 480)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.showPlaylist)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        player.showPlaylist.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .foregroundStyle(player.showPlaylist ? Color.accentColor : Color.secondary)
                .help(player.showPlaylist ? "Ocultar Fila (⌘L)" : "Exibir Fila (⌘L)")
                .accessibilityLabel(player.showPlaylist ? "Ocultar fila de reprodução" : "Exibir fila de reprodução")
            }

            ToolbarItemGroup {
                Button {
                    FilePicker.openAudio(player: player)
                } label: {
                    Label("Adicionar", systemImage: "plus")
                }
                .help("Adicionar arquivos ou pastas de áudio (⌘O)")
                .accessibilityLabel("Adicionar arquivos ou pastas de áudio")

                Menu {
                    Button("Abrir playlist…") {
                        FilePicker.openPlaylist(player: player)
                    }
                    Button("Salvar playlist…") {
                        FilePicker.exportPlaylist(player: player)
                    }
                    Divider()
                    Button("Limpar playlist", role: .destructive) {
                        player.clearPlaylist()
                    }
                    .disabled(player.tracks.isEmpty)
                } label: {
                    Label("Playlist", systemImage: "list.bullet")
                }

                ControlGroup {
                    ForEach(ConsoleTab.allCases) { tab in
                        let isSelected = player.showConsole && consoleTab == tab
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if player.showConsole && consoleTab == tab {
                                    player.showConsole = false
                                } else {
                                    consoleTab = tab
                                    player.showConsole = true
                                }
                            }
                        } label: {
                            Image(systemName: tab.symbol)
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        }
                        .help(isSelected ? "Ocultar \(tab.title)" : "Exibir \(tab.title)")
                        .accessibilityLabel(isSelected ? "Ocultar \(tab.title)" : "Exibir \(tab.title)")
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        player.showConsole.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .foregroundStyle(player.showConsole ? Color.accentColor : Color.secondary)
                .help(player.showConsole ? "Ocultar Painel Lateral (⇧⌘P)" : "Exibir Painel Lateral (⇧⌘P)")
                .accessibilityLabel(player.showConsole ? "Ocultar painel lateral" : "Exibir painel lateral")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vplayerOpenFiles)) { _ in
            FilePicker.openAudio(player: player)
        }
        .alert(
            "VPlayer",
            isPresented: Binding(
                get: { player.errorMessage != nil },
                set: { if !$0 { player.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { player.errorMessage = nil }
        } message: {
            Text(player.errorMessage ?? "")
        }
    }
}
