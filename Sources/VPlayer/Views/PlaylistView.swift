import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            List {
                ForEach(player.filteredTracks) { track in
                    row(for: track)
                        .moveDisabled(!player.searchText.isEmpty)
                }
                .onMove(perform: move)
            }
            .listStyle(.inset)
            .overlay {
                if player.tracks.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma faixa",
                        systemImage: "music.note.list",
                        description: Text("Arraste arquivos aqui ou use ⌘O para adicionar.")
                    )
                } else if player.filteredTracks.isEmpty {
                    ContentUnavailableView.search(text: player.searchText)
                }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
        }
        .background(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Fila", systemImage: "music.note.list")
                    .font(.headline)
                Spacer()
                Text("\(player.tracks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button {
                    FilePicker.openAudio(player: player)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Adicionar arquivos")
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar na fila", text: $player.searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !player.searchText.isEmpty {
                    Button {
                        player.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(12)
    }

    @ViewBuilder
    private func row(for track: Track) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        HStack(spacing: 10) {
            ArtworkView(track: track, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.callout.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if isCurrent {
                Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }

            Text(Self.format(duration: track.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isCurrent ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            player.play(track: track)
        }
        .contextMenu {
            Button("Tocar") {
                player.play(track: track)
            }
            Button("Mostrar no Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([track.url])
            }
            Divider()
            Button("Remover", role: .destructive) {
                player.removeTrack(track)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard player.filteredTracks.count == player.tracks.count else { return }
        player.moveTracks(from: source, to: destination)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                DispatchQueue.main.async {
                    player.addFiles(urls: [url])
                }
            }
        }
        return accepted
    }

    static func format(duration: TimeInterval) -> String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
