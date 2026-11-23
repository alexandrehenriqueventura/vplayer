import SwiftUI

struct ProgressScrubber: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isEnabled: Bool
    @Binding var isSeeking: Bool
    @Binding var scrubValue: Double
    let onBeginSeeking: () -> Void
    let onCommitSeek: (TimeInterval) -> Void

    @State private var isHovering = false

    private var displayedTime: TimeInterval {
        isSeeking ? scrubValue : currentTime
    }

    private var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(displayedTime / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let trackHeight: CGFloat = (isHovering || isSeeking) ? 6 : 4
            let thumbSize: CGFloat = (isHovering || isSeeking) ? 14 : 11
            let fillWidth = max(0, min(width, width * fraction))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.4))
                    .frame(width: fillWidth, height: trackHeight)

                if isEnabled {
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.85), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .offset(x: max(0, min(width - thumbSize, fillWidth - thumbSize / 2)))
                }
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled, duration > 0 else { return }
                        if !isSeeking {
                            onBeginSeeking()
                        }
                        let ratio = max(0, min(1, gesture.location.x / width))
                        scrubValue = Double(ratio) * duration
                    }
                    .onEnded { gesture in
                        guard isEnabled, duration > 0 else { return }
                        let ratio = max(0, min(1, gesture.location.x / width))
                        let target = Double(ratio) * duration
                        scrubValue = target
                        onCommitSeek(target)
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Posição da reprodução")
        .accessibilityValue("\(PlaylistView.format(duration: displayedTime)) de \(PlaylistView.format(duration: duration))")
        .accessibilityAdjustableAction { direction in
            guard isEnabled, duration > 0 else { return }
            let step: TimeInterval = 5
            switch direction {
            case .increment:
                onCommitSeek(min(duration, currentTime + step))
            case .decrement:
                onCommitSeek(max(0, currentTime - step))
            @unknown default:
                break
            }
        }
    }
}

struct PlayerBarView: View {
    @EnvironmentObject private var player: PlayerViewModel
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(PlaylistView.format(duration: player.isSeeking ? scrubValue : player.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)

                ProgressScrubber(
                    currentTime: player.currentTime,
                    duration: player.duration,
                    isEnabled: player.currentTrack != nil,
                    isSeeking: $player.isSeeking,
                    scrubValue: $scrubValue,
                    onBeginSeeking: {
                        scrubValue = player.currentTime
                        player.beginSeeking()
                    },
                    onCommitSeek: { target in
                        player.seek(to: target)
                        player.endSeeking()
                    }
                )

                Text(PlaylistView.format(duration: player.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
            }

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 200, height: 1)

                Spacer()

                HStack(spacing: 18) {
                    Button {
                        player.shuffle.toggle()
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(player.shuffle ? Color.accentColor : Color.secondary)
                    .help("Aleatório (⇧⌘S)")
                    .accessibilityLabel("Modo aleatório")
                    .accessibilityValue(player.shuffle ? "Ativado" : "Desativado")

                    Button {
                        player.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.borderless)
                    .font(.title3)
                    .disabled(player.currentTrack == nil)
                    .accessibilityLabel("Faixa anterior")

                    Button {
                        player.togglePlay()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                    }
                    .buttonStyle(.borderless)
                    .disabled(player.currentTrack == nil)
                    .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproduzir")

                    Button {
                        player.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.borderless)
                    .font(.title3)
                    .disabled(player.currentTrack == nil)
                    .accessibilityLabel("Próxima faixa")

                    Button {
                        player.cycleRepeatMode()
                    } label: {
                        Image(systemName: player.repeatMode.symbol)
                            .overlay(alignment: .bottomTrailing) {
                                if player.repeatMode == .one {
                                    Text("1")
                                        .font(.system(size: 8, weight: .bold))
                                        .offset(x: 5, y: 3)
                                }
                            }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(player.repeatMode == .off ? Color.secondary : Color.accentColor)
                    .help(player.repeatMode.title)
                    .accessibilityLabel("Modo de repetição")
                    .accessibilityValue(player.repeatMode.title)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            player.showPlaylist.toggle()
                        }
                    } label: {
                        Image(systemName: "music.note.list")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(player.showPlaylist ? Color.accentColor : Color.secondary)
                    .help(player.showPlaylist ? "Ocultar Fila (⌘L)" : "Exibir Fila (⌘L)")
                    .accessibilityLabel(player.showPlaylist ? "Ocultar fila de reprodução" : "Exibir fila de reprodução")

                    Button {
                        player.toggleMute()
                    } label: {
                        Image(systemName: volumeSymbol)
                    }
                    .buttonStyle(.borderless)
                    .help("Silenciar")
                    .accessibilityLabel(player.isMuted ? "Ativar som" : "Silenciar")

                    Slider(
                        value: Binding(
                            get: { player.isMuted ? 0 : player.volume },
                            set: { player.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 100)
                    .accessibilityLabel("Volume")
                    .accessibilityValue("\(Int((player.isMuted ? 0 : player.volume) * 100)) por cento")
                }
                .frame(width: 200, alignment: .trailing)
            }
            .font(.title3)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var volumeSymbol: String {
        if player.isMuted || player.volume == 0 {
            return "speaker.slash.fill"
        }
        if player.volume < 0.33 {
            return "speaker.wave.1.fill"
        }
        if player.volume < 0.66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }
}
