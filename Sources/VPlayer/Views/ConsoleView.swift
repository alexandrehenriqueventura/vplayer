import SwiftUI

struct ConsoleView: View {
    @Binding var selection: ConsoleTab

    var body: some View {
        VStack(spacing: 0) {
            switch selection {
            case .equalizer:
                EqualizerView()
            case .effects:
                EffectsView()
            case .lyrics:
                LyricsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}
