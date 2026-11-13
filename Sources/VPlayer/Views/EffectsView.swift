import AVFoundation
import SwiftUI

struct EffectsView: View {
    @EnvironmentObject private var player: PlayerViewModel

    private let reverbPresets: [(String, AVAudioUnitReverbPreset)] = [
        ("Sala pequena", .smallRoom),
        ("Sala média", .mediumRoom),
        ("Salão médio", .mediumHall),
        ("Salão grande", .largeHall),
        ("Câmara média", .mediumChamber),
        ("Câmara grande", .largeChamber),
        ("Placa", .plate),
        ("Catedral", .cathedral)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Efeitos", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Button {
                    player.resetEffects()
                } label: {
                    Label("Redefinir", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(spacing: 12) {
                effectRow(
                    title: "Velocidade",
                    value: String(format: "%.2fx", player.playbackRate),
                    range: 0.5...2,
                    binding: Binding(
                        get: { Double(player.playbackRate) },
                        set: { player.playbackRate = Float($0) }
                    )
                )

                effectRow(
                    title: "Tom",
                    value: String(format: "%+.1f semitons", player.pitchShift / 100),
                    range: -12...12,
                    binding: Binding(
                        get: { Double(player.pitchShift / 100) },
                        set: { player.pitchShift = Float($0 * 100) }
                    )
                )

                effectRow(
                    title: "Reverb",
                    value: "\(Int(player.reverbMix))%",
                    range: 0...100,
                    binding: Binding(
                        get: { Double(player.reverbMix) },
                        set: { player.reverbMix = Float($0) }
                    )
                )

                effectRow(
                    title: "Crossfade",
                    value: String(format: "%.1fs", player.crossfade),
                    range: 0...12,
                    binding: Binding(
                        get: { player.crossfade },
                        set: { player.crossfade = $0 }
                    )
                )

                HStack {
                    Text("Ambiente")
                        .font(.callout)
                    Spacer()
                    Picker("Ambiente", selection: $player.reverbPreset) {
                        ForEach(reverbPresets, id: \.0) { preset in
                            Text(preset.0).tag(preset.1)
                        }
                    }
                    .frame(width: 180)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func effectRow(
        title: String,
        value: String,
        range: ClosedRange<Double>,
        binding: Binding<Double>
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.callout)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: range)
        }
    }
}
