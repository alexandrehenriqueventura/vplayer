import AppKit
import SwiftUI

struct AlbumCoverView: View {
    let artworkData: Data?
    var cornerRadius: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.04, green: 0.10, blue: 0.16).opacity(0.60),
                                    Color(red: 0.02, green: 0.04, blue: 0.08).opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.14), lineWidth: 1)
                        .frame(width: size * 0.66, height: size * 0.66)

                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.24), lineWidth: 1)
                        .frame(width: size * 0.44, height: size * 0.44)

                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.28, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color(red: 0.15, green: 0.92, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.cyan.opacity(0.70), radius: 10, x: 0, y: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.cyan.opacity(0.45),
                                    Color.cyan.opacity(0.08),
                                    Color.white.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct AlbumCardView: View {
    let album: Album
    let isPlayingAlbum: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    let onShuffle: () -> Void
    let onEnqueue: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AlbumCoverView(artworkData: album.artworkData, cornerRadius: 12)
                    .shadow(
                        color: .black.opacity(isHovering ? 0.28 : 0.16),
                        radius: isHovering ? 12 : 6,
                        x: 0,
                        y: isHovering ? 6 : 3
                    )

                if isHovering || isPlayingAlbum {
                    Button {
                        onPlay()
                    } label: {
                        Image(systemName: isPlayingAlbum ? "waveform" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor, in: Circle())
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .accessibilityLabel("Tocar álbum \(album.title)")
                }
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.16), value: isHovering)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(album.artist)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                Text("\(album.tracks.count) \(album.tracks.count == 1 ? "faixa" : "faixas")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Tocar Álbum") { onPlay() }
            Button("Tocar em Modo Aleatório") { onShuffle() }
            Button("Adicionar à Fila") { onEnqueue() }
            Divider()
            Button("Mostrar no Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([album.folderURL])
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.title), de \(album.artist), \(album.tracks.count) faixas")
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var player: PlayerViewModel
    let album: Album
    let onBack: () -> Void
    let onOpenNowPlaying: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Label("Biblioteca", systemImage: "chevron.left")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Voltar para a biblioteca")

                Spacer()

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([album.folderURL])
                } label: {
                    Label("Finder", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Mostrar pasta do álbum no Finder")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .bottom, spacing: 22) {
                        AlbumCoverView(artworkData: album.artworkData, cornerRadius: 14)
                            .frame(width: 170, height: 170)
                            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(album.title)
                                .font(.title2.weight(.bold))
                                .lineLimit(2)

                            Text(album.artist)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text("\(album.tracks.count) \(album.tracks.count == 1 ? "faixa" : "faixas") • \(PlaylistView.format(duration: album.totalDuration))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.bottom, 8)

                            HStack(spacing: 10) {
                                Button {
                                    player.playAlbum(album, shuffled: false, startingAt: 0)
                                    onOpenNowPlaying()
                                } label: {
                                    Label("Tocar", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)

                                Button {
                                    player.playAlbum(album, shuffled: true)
                                    onOpenNowPlaying()
                                } label: {
                                    Label("Aleatório", systemImage: "shuffle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)

                                Button {
                                    player.enqueueAlbum(album)
                                } label: {
                                    Label("Fila", systemImage: "text.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .help("Adicionar álbum à fila atual")
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    VStack(spacing: 2) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            let isCurrent = player.currentTrack?.url.standardizedFileURL == track.url.standardizedFileURL

                            HStack(spacing: 12) {
                                Group {
                                    if isCurrent && player.isPlaying {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 24, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.callout.weight(isCurrent ? .semibold : .regular))
                                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                                        .lineLimit(1)

                                    if track.artist != album.artist && track.artist != "Artista desconhecido" {
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(PlaylistView.format(duration: track.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isCurrent ? Color.accentColor.opacity(0.10) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.playAlbum(album, shuffled: false, startingAt: index)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @EnvironmentObject private var library: LibraryViewModel
    let onOpenNowPlaying: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 155, maximum: 190), spacing: 20)
    ]

    var body: some View {
        Group {
            if let album = library.selectedAlbum {
                AlbumDetailView(
                    album: album,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            library.selectedAlbum = nil
                        }
                    },
                    onOpenNowPlaying: onOpenNowPlaying
                )
            } else {
                libraryGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var libraryGrid: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if library.isScanning && library.albums.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Carregando álbuns em \(library.libraryDirectory.lastPathComponent)…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if library.albums.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum álbum encontrado", systemImage: "square.stack")
                } description: {
                    Text("Não encontramos arquivos de áudio em \"\(library.libraryDirectory.path)\".")
                } actions: {
                    HStack(spacing: 10) {
                        Button("Escolher Pasta de Músicas…") {
                            FilePicker.chooseLibraryFolder(library: library)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Atualizar") {
                            library.refresh()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if library.filteredAlbums.isEmpty {
                ContentUnavailableView.search(text: library.searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(library.filteredAlbums) { album in
                            let isPlayingAlbum = player.isPlaying
                                && player.currentTrack.map { current in
                                    album.tracks.contains { $0.url.standardizedFileURL == current.url.standardizedFileURL }
                                } ?? false

                            AlbumCardView(
                                album: album,
                                isPlayingAlbum: isPlayingAlbum,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        library.selectedAlbum = album
                                    }
                                },
                                onPlay: {
                                    player.playAlbum(album, shuffled: false, startingAt: 0)
                                    onOpenNowPlaying()
                                },
                                onShuffle: {
                                    player.playAlbum(album, shuffled: true)
                                    onOpenNowPlaying()
                                },
                                onEnqueue: {
                                    player.enqueueAlbum(album)
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Biblioteca")
                        .font(.title3.weight(.semibold))

                    if library.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text("\(library.albums.count) \(library.albums.count == 1 ? "álbum" : "álbuns") • \(library.totalTrackCount) \(library.totalTrackCount == 1 ? "faixa" : "faixas") • \(library.libraryDirectory.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar álbum ou artista", text: $library.searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !library.searchText.isEmpty {
                    Button {
                        library.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Limpar busca da biblioteca")
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(width: 210)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Picker("Ordenar", selection: $library.sortOrder) {
                ForEach(AlbumSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .labelsHidden()
            .frame(width: 135)
            .accessibilityLabel("Ordenar álbuns")

            Button {
                FilePicker.chooseLibraryFolder(library: library)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Escolher pasta da biblioteca")
            .accessibilityLabel("Escolher pasta da biblioteca")

            Button {
                library.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(library.isScanning)
            .help("Atualizar biblioteca")
            .accessibilityLabel("Atualizar biblioteca")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
}
