import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id: UUID
    var url: URL
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artworkData: Data?
    var addedAt: Date
    var lyricsData: String?

    init(
        url: URL,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkData: Data? = nil,
        lyricsData: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = UUID()
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist ?? "Artista desconhecido"
        self.album = album ?? "Álbum desconhecido"
        self.duration = duration
        self.artworkData = artworkData
        self.lyricsData = lyricsData
        self.addedAt = addedAt
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
