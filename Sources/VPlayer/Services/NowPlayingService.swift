import AppKit
import Foundation
import MediaPlayer

@MainActor
final class NowPlayingService {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?

    private var registered = false

    init() {
        registerCommands()
    }

    private func registerCommands() {
        guard !registered else { return }
        registered = true
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0 > 0 {
                    self.onPause?()
                } else {
                    self.onPlay?()
                }
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onNext?() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPrevious?() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .vplayerSeek,
                    object: nil,
                    userInfo: ["position": event.positionTime]
                )
            }
            return .success
        }
    }

    func update(track: Track?, elapsed: TimeInterval, duration: TimeInterval, isPlaying: Bool, rate: Float) {
        var info: [String: Any] = [:]
        if let track {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyAlbumTitle] = track.album
            if let data = track.artworkData, let image = NSImage(data: data) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(rate) : 0.0
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}

extension Notification.Name {
    static let vplayerSeek = Notification.Name("vplayer.seek")
    static let vplayerTogglePlay = Notification.Name("vplayer.togglePlay")
    static let vplayerNext = Notification.Name("vplayer.next")
    static let vplayerPrevious = Notification.Name("vplayer.previous")
    static let vplayerVolumeUp = Notification.Name("vplayer.volumeUp")
    static let vplayerVolumeDown = Notification.Name("vplayer.volumeDown")
    static let vplayerOpenFiles = Notification.Name("vplayer.openFiles")
    static let vplayerToggleShuffle = Notification.Name("vplayer.toggleShuffle")
    static let vplayerCycleRepeat = Notification.Name("vplayer.cycleRepeat")
    static let vplayerTogglePlaylist = Notification.Name("vplayer.togglePlaylist")
    static let vplayerToggleConsole = Notification.Name("vplayer.toggleConsole")
}
