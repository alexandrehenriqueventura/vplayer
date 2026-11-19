import SwiftUI

enum MainViewMode: String, CaseIterable, Identifiable {
    case library
    case nowPlaying

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Biblioteca"
        case .nowPlaying: return "Tocando Agora"
        }
    }

    var symbol: String {
        switch self {
        case .library: return "square.grid.2x2"
        case .nowPlaying: return "music.note"
        }
    }
}

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
    @EnvironmentObject private var library: LibraryViewModel
    @State private var mainMode: MainViewMode = .library
    @State private var consoleTab: ConsoleTab = .equalizer

    var body: some View {
        HSplitView {
            if player.showPlaylist {
                PlaylistView()
                    .frame(minWidth: 230, idealWidth: 270, maxWidth: 380)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                Group {
                    switch mainMode {
                    case .library:
                        LibraryView {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mainMode = .nowPlaying
                            }
                        }
                    case .nowPlaying:
                        NowPlayingView(consoleTab: $consoleTab)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                PlayerBarView()
            }
            .frame(minWidth: player.showPlaylist ? 580 : 480)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.showPlaylist)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
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

                ControlGroup {
                    ForEach(MainViewMode.allCases) { mode in
                        let isSelected = mainMode == mode
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if mode == .library && mainMode == .library {
                                    library.selectedAlbum = nil
                                } else {
                                    mainMode = mode
                                }
                            }
                        } label: {
                            Image(systemName: mode.symbol)
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        }
                        .help(mode.title)
                        .accessibilityLabel(mode.title)
                    }
                }
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
                        let isSelected = mainMode == .nowPlaying && player.showConsole && consoleTab == tab
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if mainMode == .nowPlaying && player.showConsole && consoleTab == tab {
                                    player.showConsole = false
                                } else {
                                    mainMode = .nowPlaying
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
                        if mainMode != .nowPlaying {
                            mainMode = .nowPlaying
                            player.showConsole = true
                        } else {
                            player.showConsole.toggle()
                        }
                    }
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .foregroundStyle(mainMode == .nowPlaying && player.showConsole ? Color.accentColor : Color.secondary)
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
