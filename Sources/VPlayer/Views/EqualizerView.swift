import SwiftUI

struct VerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let usable = max(1, height - 16)
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 7)
                    .padding(.vertical, 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 7, height: max(2, usable * fraction))
                    .padding(.bottom, 8)

                Circle()
                    .fill(Color.white)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .offset(y: -(8 + usable * fraction))
            }
            .frame(width: geometry.size.width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let raw = (height - 8 - gesture.location.y) / usable
                        let clamped = max(0, min(1, raw))
                        value = range.lowerBound + Float(clamped) * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}

struct EqualizerView: View {
    @EnvironmentObject private var player: PlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Equalizador", systemImage: "slider.vertical.3")
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 6)

                Picker("Predefinição", selection: $player.selectedPreset) {
                    ForEach(EQPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .frame(maxWidth: 140)
                .labelsHidden()
                .onChange(of: player.selectedPreset) { _, newValue in
                    player.applyPreset(newValue)
                }

                Toggle("Ativo", isOn: $player.eqEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()

                Button {
                    player.resetEQ()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Redefinir equalizador")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 6) {
                    Text("0 dB")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(String(format: "%+.0f", player.eqPreamp))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34)

                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(EQBand.frequencies.enumerated()), id: \.offset) { index, frequency in
                        VStack(spacing: 6) {
                            Text(String(format: "%+.0f", index < player.eqGains.count ? player.eqGains[index] : 0))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)

                                VerticalSlider(
                                    value: Binding(
                                        get: { index < player.eqGains.count ? player.eqGains[index] : 0 },
                                        set: { newValue in
                                            guard index < player.eqGains.count else { return }
                                            player.selectedPreset = .flat
                                            player.eqGains[index] = newValue
                                        }
                                    ),
                                    range: -12...12
                                )
                            .frame(maxWidth: .infinity)

                            Text(EQBand.label(frequency))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .frame(maxHeight: .infinity)
        }
    }
}
