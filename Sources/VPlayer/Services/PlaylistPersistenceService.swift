import Foundation

struct PersistedTrack: Codable, Equatable {
    let url: URL
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let addedAt: Date

    init(from track: Track) {
        self.url = track.url
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.duration = track.duration
        self.addedAt = track.addedAt
    }

    func toTrack() -> Track {
        Track(
            url: url,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            addedAt: addedAt
        )
    }
}

struct PersistedSession: Codable, Equatable {
    let tracks: [PersistedTrack]
    let currentIndex: Int?
}

final class PlaylistPersistenceService {
    private let storageURL: URL
    private let fileManager: FileManager

    init(storageURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.storageURL = appSupport
                .appendingPathComponent("VPlayer", isDirectory: true)
                .appendingPathComponent("session.json")
        }
    }

    func save(tracks: [Track], currentIndex: Int?) {
        let session = PersistedSession(
            tracks: tracks.map(PersistedTrack.init(from:)),
            currentIndex: currentIndex
        )
        do {
            let directory = storageURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try JSONEncoder().encode(session)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Persistence failure should not interrupt playback
        }
    }

    func load() -> (tracks: [Track], currentIndex: Int?) {
        guard fileManager.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let session = try? JSONDecoder().decode(PersistedSession.self, from: data)
        else {
            return ([], nil)
        }

        let currentURL: URL? = session.currentIndex.flatMap { idx in
            session.tracks.indices.contains(idx) ? session.tracks[idx].url : nil
        }

        let validTracks = session.tracks
            .filter { fileManager.fileExists(atPath: $0.url.path) }
            .map { $0.toTrack() }

        let restoredIndex: Int?
        if let currentURL {
            restoredIndex = validTracks.firstIndex(where: { $0.url == currentURL })
        } else {
            restoredIndex = nil
        }

        return (validTracks, restoredIndex)
    }
}
