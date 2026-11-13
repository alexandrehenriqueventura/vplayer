import SwiftUI

struct FrequencyResponseCurveView: View {
    let gains: [Float]
    let enabled: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let midY = height / 2
            let points = controlPoints(width: width, height: height)

            ZStack {
                // Background glass track
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                // Grid lines (+6 dB, 0 dB, -6 dB)
                Path { path in
                    path.move(to: CGPoint(x: 8, y: height * 0.25))
                    path.addLine(to: CGPoint(x: width - 8, y: height * 0.25))
                    path.move(to: CGPoint(x: 8, y: height * 0.75))
                    path.addLine(to: CGPoint(x: width - 8, y: height * 0.75))
                }
                .stroke(Color.primary.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                // 0 dB center reference line
                Path { path in
                    path.move(to: CGPoint(x: 8, y: midY))
                    path.addLine(to: CGPoint(x: width - 8, y: midY))
                }
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)

                // Gradient fill under/over 0 dB baseline
                if points.count >= 2 {
                    filledCurvePath(points: points, baselineY: midY)
                        .fill(
                            LinearGradient(
                                colors: enabled
                                    ? [Color.accentColor.opacity(0.28), Color.purple.opacity(0.14)]
                                    : [Color.secondary.opacity(0.12), Color.secondary.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Smooth frequency response stroke
                    smoothCurvePath(points: points)
                        .stroke(
                            LinearGradient(
                                colors: enabled
                                    ? [Color.accentColor, Color.purple]
                                    : [Color.secondary.opacity(0.5), Color.secondary.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                    // Band nodes
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(enabled ? Color.white : Color.secondary.opacity(0.5))
                            .frame(width: 5, height: 5)
                            .overlay(
                                Circle()
                                    .strokeBorder(enabled ? Color.accentColor : Color.secondary, lineWidth: 1.2)
                            )
                            .position(point)
                    }
                }
            }
        }
        .frame(height: 54)
        .animation(.easeOut(duration: 0.18), value: gains)
        .animation(.easeOut(duration: 0.18), value: enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Curva de resposta de frequência do equalizador")
        .accessibilityValue(enabled ? "Ativa" : "Desativada")
    }

    private func controlPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let count = max(1, gains.count)
        let paddingX: CGFloat = 14
        let usableWidth = max(1, width - paddingX * 2)
        let paddingY: CGFloat = 8
        let usableHeight = max(1, height - paddingY * 2)

        return gains.enumerated().map { index, gain in
            let x = count > 1
                ? paddingX + usableWidth * (CGFloat(index) / CGFloat(count - 1))
                : width / 2
            let clamped = max(-12, min(12, gain))
            let normalized = CGFloat((clamped + 12) / 24) // 0 at -12dB, 1 at +12dB
            let y = paddingY + usableHeight * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    private func smoothCurvePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        for index in 0..<(points.count - 1) {
            let p0 = index > 0 ? points[index - 1] : points[index]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = (index + 2) < points.count ? points[index + 2] : p2

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }

    private func filledCurvePath(points: [CGPoint], baselineY: CGFloat) -> Path {
        var path = smoothCurvePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.addLine(to: CGPoint(x: first.x, y: baselineY))
        path.closeSubpath()
        return path
    }
}

struct VerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var label: String = "Controle"

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%+.0f dB", value))
        .accessibilityAdjustableAction { direction in
            let step: Float = 1.0
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
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
                .accessibilityLabel("Predefinição do equalizador")
                .onChange(of: player.selectedPreset) { _, newValue in
                    player.applyPreset(newValue)
                }

                Toggle("Ativo", isOn: $player.eqEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityLabel("Ativar equalizador")

                Button {
                    player.resetEQ()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Redefinir equalizador")
                .accessibilityLabel("Redefinir equalizador")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            FrequencyResponseCurveView(gains: player.eqGains, enabled: player.eqEnabled)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

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
                .accessibilityHidden(true)

                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(EQBand.frequencies.enumerated()), id: \.offset) { index, frequency in
                        VStack(spacing: 6) {
                            Text(String(format: "%+.0f", index < player.eqGains.count ? player.eqGains[index] : 0))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            VerticalSlider(
                                value: Binding(
                                    get: { index < player.eqGains.count ? player.eqGains[index] : 0 },
                                    set: { newValue in
                                        guard index < player.eqGains.count else { return }
                                        player.selectedPreset = .flat
                                        player.eqGains[index] = newValue
                                    }
                                ),
                                range: -12...12,
                                label: "Ganho em \(EQBand.label(frequency))"
                            )
                            .frame(maxWidth: .infinity)

                            Text(EQBand.label(frequency))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
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
