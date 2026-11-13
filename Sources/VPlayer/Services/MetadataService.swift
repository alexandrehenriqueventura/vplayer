import AVFoundation
import Foundation

enum MetadataService {
    static func load(for url: URL) async throws -> Track {
        var track = Track(url: url)
        let asset = AVURLAsset(url: url)

        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        if seconds.isFinite, seconds > 0 {
            track.duration = seconds
        }

        let items = try await asset.load(.commonMetadata)
        for item in items {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    track.title = value
                }
            case .commonKeyArtist:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    track.artist = value
                }
            case .commonKeyAlbumName:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    track.album = value
                }
            case .commonKeyArtwork:
                if let data = try? await item.load(.dataValue), !data.isEmpty {
                    track.artworkData = data
                }
            default:
                if let value = try? await item.load(.stringValue),
                   let identifier = item.identifier?.rawValue,
                   identifier.localizedCaseInsensitiveContains("lyric") {
                    track.lyricsData = value
                }
            }
        }

        if track.duration == 0 {
            track.duration = probeDuration(url: url)
        }

        return track
    }

    static func probeDuration(url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return 0 }
        return Double(file.length) / rate
    }

    static func artworkImage(for track: Track) -> Data? {
        track.artworkData
    }
}
