import SwiftUI

struct LyricsView: View {
    @EnvironmentObject private var player: PlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Letras", systemImage: "text.quote")
                    .font(.headline)
                Spacer()
                if !player.lyrics.isEmpty {
                    Text("\(player.lyrics.count) linhas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if player.lyrics.isEmpty {
                ContentUnavailableView(
                    "Sem letras",
                    systemImage: "text.quote",
                    description: Text("Coloque um arquivo .lrc com o mesmo nome da música na mesma pasta.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(player.lyrics) { line in
                                let isCurrent = player.currentLyricIndex.map { index in
                                    player.lyrics.indices.contains(index)
                                        && player.lyrics[index].id == line.id
                                } ?? false

                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(isCurrent ? .title3.weight(.semibold) : .body)
                                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                                    .padding(.vertical, 2)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: player.currentLyricIndex) { _, index in
                        guard let index, player.lyrics.indices.contains(index) else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(player.lyrics[index].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
