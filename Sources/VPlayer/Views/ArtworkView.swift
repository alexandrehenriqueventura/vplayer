import AppKit
import SwiftUI

struct ArtworkView: View {
    let track: Track?
    var size: CGFloat
    var isPlaying: Bool = false

    @State private var isPulsing = false

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
                    .scaleEffect(isPlaying && isPulsing ? 1.018 : 1.0)
                    .shadow(color: .black.opacity(isPlaying && isPulsing ? 0.45 : 0.35), radius: isPlaying && isPulsing ? 18 : 14, x: 0, y: isPlaying && isPulsing ? 10 : 8)
            } else {
                smokedGlassPlaceholder
            }
        }
        .onAppear {
            updateAnimation()
        }
        .onChange(of: isPlaying) { _, _ in
            updateAnimation()
        }
    }

    private func updateAnimation() {
        if isPlaying {
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                isPulsing = false
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

            // 3. Acoustic halo resonance rings (Vibrating soundwaves)
            Circle()
                .strokeBorder(Color.cyan.opacity(isPulsing ? 0.16 : 0.04), lineWidth: 1)
                .frame(width: size * 0.86, height: size * 0.86)
                .scaleEffect(isPulsing ? 1.06 : 0.96)

            Circle()
                .strokeBorder(Color.cyan.opacity(isPulsing ? 0.28 : 0.12), lineWidth: isPulsing ? 1.4 : 1)
                .frame(width: size * 0.68, height: size * 0.68)
                .scaleEffect(isPulsing ? 1.08 : 0.98)

            Circle()
                .strokeBorder(Color.cyan.opacity(isPulsing ? 0.38 : 0.22), lineWidth: isPulsing ? 1.6 : 1)
                .frame(width: size * 0.46, height: size * 0.46)
                .scaleEffect(isPulsing ? 1.10 : 1.0)

            // 4. Glowing Neon Cyan musical symbol (Speaker cone core pulse)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.30, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.15, green: isPulsing ? 0.98 : 0.92, blue: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(isPulsing ? 1.12 : 1.0)
                .shadow(color: Color.cyan.opacity(isPulsing ? 0.95 : 0.80), radius: isPulsing ? 20 : 14, x: 0, y: 0)
                .shadow(color: Color.cyan.opacity(isPulsing ? 0.55 : 0.35), radius: isPulsing ? 34 : 26, x: 0, y: 0)
        }
        .frame(width: size, height: size)
        .scaleEffect(isPulsing ? 1.02 : 1.0)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
        .overlay(
            // Specular glass refraction rim
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isPulsing ? 0.60 : 0.45),
                            Color.cyan.opacity(isPulsing ? 0.75 : 0.60),
                            Color.cyan.opacity(0.10),
                            Color.white.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isPulsing ? 1.4 : 1.2
                )
        )
        .shadow(color: Color.cyan.opacity(isPulsing ? 0.38 : 0.22), radius: isPulsing ? 32 : 24, x: 0, y: 8)
        .shadow(color: Color.black.opacity(isPulsing ? 0.46 : 0.38), radius: isPulsing ? 20 : 16, x: 0, y: 10)
    }
}
