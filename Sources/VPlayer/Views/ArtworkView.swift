import AppKit
import SwiftUI

struct ArtworkView: View {
    let track: Track?
    var size: CGFloat

    var body: some View {
        Group {
            if let data = track?.artworkData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
            } else {
                smokedGlassPlaceholder
            }
        }
    }

    private var smokedGlassPlaceholder: some View {
        ZStack {
            // 1. Native macOS frosted glass material
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(.ultraThinMaterial)

            // 2. Smoked obsidian & cyan glass tint
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.10, blue: 0.16).opacity(0.55),
                            Color(red: 0.02, green: 0.04, blue: 0.08).opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 3. Acoustic halo resonance rings
            Circle()
                .strokeBorder(Color.cyan.opacity(0.12), lineWidth: 1)
                .frame(width: size * 0.68, height: size * 0.68)

            Circle()
                .strokeBorder(Color.cyan.opacity(0.22), lineWidth: 1)
                .frame(width: size * 0.46, height: size * 0.46)

            // 4. Glowing Neon Cyan musical symbol
            Image(systemName: "music.note")
                .font(.system(size: size * 0.30, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.15, green: 0.92, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.cyan.opacity(0.80), radius: 14, x: 0, y: 0)
                .shadow(color: Color.cyan.opacity(0.35), radius: 26, x: 0, y: 0)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
        .overlay(
            // Specular glass refraction rim
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.cyan.opacity(0.60),
                            Color.cyan.opacity(0.10),
                            Color.white.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.cyan.opacity(0.22), radius: 24, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.38), radius: 16, x: 0, y: 10)
    }
}
