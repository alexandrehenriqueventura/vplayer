import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @Binding var consoleTab: ConsoleTab

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(spacing: 14) {
                ArtworkView(track: player.currentTrack, size: player.showConsole ? 240 : 320)

                VStack(spacing: 4) {
                    Text(player.currentTrack?.title ?? "Nada tocando")
                        .font((player.showConsole ? Font.title3 : Font.title2).weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(player.currentTrack?.artist ?? "—")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(player.currentTrack?.album ?? "")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: player.showConsole ? 250 : 360)

            if player.showConsole {
                ConsoleView(selection: $consoleTab)
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: player.showConsole ? .topLeading : .center)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.showConsole)
    }
}
