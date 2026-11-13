import SwiftUI

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

                Slider(
                    value: Binding(
                        get: { player.isSeeking ? scrubValue : player.currentTime },
                        set: { newValue in
                            if player.isSeeking {
                                scrubValue = newValue
                            } else {
                                player.seek(to: newValue)
                            }
                        }
                    ),
                    in: 0...max(player.duration, 0.001),
                    onEditingChanged: { editing in
                        if editing {
                            scrubValue = player.currentTime
                            player.beginSeeking()
                        } else {
                            player.seek(to: scrubValue)
                            player.endSeeking()
                        }
                    }
                )
                .disabled(player.currentTrack == nil)
                .accessibilityLabel("Posição da reprodução")
                .accessibilityValue("\(PlaylistView.format(duration: player.isSeeking ? scrubValue : player.currentTime)) de \(PlaylistView.format(duration: player.duration))")

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
