import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var isScanning = false
    @Published var searchText = ""
    @Published var sortOrder: AlbumSortOrder {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: Keys.sortOrder)
        }
    }
    @Published var selectedAlbum: Album?
    @Published var libraryDirectory: URL {
        didSet {
            UserDefaults.standard.set(libraryDirectory.path, forKey: Keys.libraryDirectory)
        }
    }

    private var scanTask: Task<Void, Never>?

    private enum Keys {
        static let libraryDirectory = "vplayer.libraryDirectory"
        static let sortOrder = "vplayer.librarySortOrder"
    }

    init() {
        let defaults = UserDefaults.standard
        if let savedPath = defaults.string(forKey: Keys.libraryDirectory),
           FileManager.default.fileExists(atPath: savedPath) {
            self.libraryDirectory = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            self.libraryDirectory = MusicLibraryService.defaultMusicDirectory()
        }

        self.sortOrder = AlbumSortOrder(rawValue: defaults.string(forKey: Keys.sortOrder) ?? "") ?? .title
        refresh()
    }

    deinit {
        scanTask?.cancel()
    }

    var totalTrackCount: Int {
        albums.reduce(0) { $0 + $1.tracks.count }
    }

    var filteredAlbums: [Album] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching: [Album]
        if query.isEmpty {
            matching = albums
        } else {
            matching = albums.filter { album in
                album.title.lowercased().contains(query)
                    || album.artist.lowercased().contains(query)
                    || album.tracks.contains { $0.title.lowercased().contains(query) }
            }
        }

        switch sortOrder {
        case .title:
            return matching.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .artist:
            return matching.sorted { lhs, rhs in
                let artistCmp = lhs.artist.localizedStandardCompare(rhs.artist)
                if artistCmp != .orderedSame { return artistCmp == .orderedAscending }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .recent:
            return matching.sorted { lhs, rhs in
                if lhs.latestModified != rhs.latestModified {
                    return lhs.latestModified > rhs.latestModified
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func refresh() {
        scanTask?.cancel()
        let directory = libraryDirectory
        isScanning = true
        scanTask = Task { [weak self] in
            let scanned = await MusicLibraryService.scan(directory: directory)
            guard !Task.isCancelled, let self else { return }
            self.albums = scanned
            if let selected = self.selectedAlbum {
                self.selectedAlbum = scanned.first(where: { $0.id == selected.id })
            }
            self.isScanning = false
        }
    }

    func setLibraryDirectory(_ url: URL) {
        libraryDirectory = url.standardizedFileURL
        selectedAlbum = nil
        refresh()
    }
}
