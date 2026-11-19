import Foundation

enum AlbumSortOrder: String, CaseIterable, Identifiable {
    case title
    case artist
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: return "Álbum (A–Z)"
        case .artist: return "Artista (A–Z)"
        case .recent: return "Mais Recentes"
        }
    }
}

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let folderURL: URL
    var tracks: [Track]
    var artworkData: Data?
    var latestModified: Date

    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id && lhs.tracks.count == rhs.tracks.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
