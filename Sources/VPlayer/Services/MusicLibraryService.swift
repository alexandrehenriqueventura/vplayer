import Foundation

enum MusicLibraryService {
    private static let coverBaseNames = ["cover", "folder", "front", "album", "artwork"]
    private static let coverExtensions = ["jpg", "jpeg", "png", "webp"]

    static func defaultMusicDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Music", isDirectory: true)
    }

    static func findFolderArtwork(in directory: URL, fileManager: FileManager = .default) -> Data? {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        // Prefer standard cover filenames first
        for baseName in coverBaseNames {
            for ext in coverExtensions {
                if let match = contents.first(where: {
                    $0.deletingPathExtension().lastPathComponent.lowercased() == baseName
                        && $0.pathExtension.lowercased() == ext
                }), let data = try? Data(contentsOf: match), !data.isEmpty {
                    return data
                }
            }
        }

        // Fallback to any image file in the album folder
        if let anyImage = contents.first(where: { coverExtensions.contains($0.pathExtension.lowercased()) }),
           let data = try? Data(contentsOf: anyImage), !data.isEmpty {
            return data
        }

        return nil
    }

    static func groupIntoAlbums(
        tracks: [Track],
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> [Album] {
        let normalizedRoot = rootDirectory?.resolvingSymlinksInPath().standardizedFileURL.path
        var grouped: [String: (title: String, folders: [URL], tracks: [Track])] = [:]

        for track in tracks {
            let folder = track.url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            let rawAlbum = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
            let isUnknownAlbum = rawAlbum.isEmpty || rawAlbum == "Álbum desconhecido"

            let resolvedTitle: String
            let groupKey: String
            if !isUnknownAlbum {
                resolvedTitle = rawAlbum
                let artistKey = primaryArtistKey(for: track.artist)
                groupKey = artistKey.isEmpty
                    ? "tag:\(rawAlbum.lowercased())"
                    : "tag:\(rawAlbum.lowercased())|\(artistKey)"
            } else if let normalizedRoot, folder.path == normalizedRoot {
                resolvedTitle = "Músicas Avulsas"
                groupKey = "singles:\(folder.path.lowercased())"
            } else {
                resolvedTitle = folder.lastPathComponent
                groupKey = "folder:\(folder.path.lowercased())"
            }

            if var bucket = grouped[groupKey] {
                bucket.tracks.append(track)
                if !bucket.folders.contains(folder) {
                    bucket.folders.append(folder)
                }
                grouped[groupKey] = bucket
            } else {
                grouped[groupKey] = (title: resolvedTitle, folders: [folder], tracks: [track])
            }
        }

        var albums: [Album] = []
        albums.reserveCapacity(grouped.count)

        for (key, bucket) in grouped {
            let deduplicatedTracks = deduplicateTracks(bucket.tracks)
            let sortedTracks = deduplicatedTracks.sorted {
                $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }

            let artist = resolveAlbumArtist(for: sortedTracks)
            let embeddedArt = sortedTracks.first(where: { $0.artworkData != nil })?.artworkData
            let folderArt = embeddedArt ?? bucket.folders.lazy.compactMap {
                findFolderArtwork(in: $0, fileManager: fileManager)
            }.first

            let latestDate = sortedTracks.compactMap { track -> Date? in
                (try? track.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            }.max() ?? Date.distantPast

            // Propagate folder cover to tracks that lack embedded artwork
            let enrichedTracks: [Track]
            if let folderArt {
                enrichedTracks = sortedTracks.map { track in
                    var copy = track
                    if copy.artworkData == nil {
                        copy.artworkData = folderArt
                    }
                    return copy
                }
            } else {
                enrichedTracks = sortedTracks
            }

            albums.append(
                Album(
                    id: key,
                    title: bucket.title,
                    artist: artist,
                    folderURL: bucket.folders.first ?? sortedTracks[0].url.deletingLastPathComponent(),
                    tracks: enrichedTracks,
                    artworkData: folderArt,
                    latestModified: latestDate
                )
            )
        }

        return albums.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private static func primaryArtistKey(for rawArtist: String) -> String {
        let trimmed = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty || trimmed == "artista desconhecido" || trimmed == "vários artistas" || trimmed == "various artists" {
            return ""
        }
        // Strip featured artist suffixes so "Artist feat. Guest" stays with "Artist"
        for separator in [" feat. ", " ft. ", " featuring ", " & "] {
            if let range = trimmed.range(of: separator) {
                let base = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !base.isEmpty { return base }
            }
        }
        return trimmed
    }

    private static func deduplicateTracks(_ tracks: [Track]) -> [Track] {
        var result: [Track] = []
        result.reserveCapacity(tracks.count)

        for track in tracks {
            let titleKey = track.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stemKey = track.url.deletingPathExtension().lastPathComponent.lowercased()

            if let existingIndex = result.firstIndex(where: { existing in
                let existingTitle = existing.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let existingStem = existing.url.deletingPathExtension().lastPathComponent.lowercased()
                let sameIdentity = existingTitle == titleKey && existingStem == stemKey
                let similarDuration = abs(existing.duration - track.duration) <= 2.0
                return sameIdentity && similarDuration
            }) {
                if trackScore(track) > trackScore(result[existingIndex]) {
                    result[existingIndex] = track
                }
            } else {
                result.append(track)
            }
        }

        return result
    }

    private static func trackScore(_ track: Track) -> Int {
        var score = track.artworkData != nil ? 100 : 0
        switch track.url.pathExtension.lowercased() {
        case "flac", "alac", "wav", "aiff", "aif": score += 30
        case "m4a", "aac": score += 20
        case "mp3": score += 10
        default: break
        }
        return score
    }

    static func scan(directory: URL, maxConcurrency: Int = 8) async -> [Album] {
        let urls = LibraryScanner.expand(urls: [directory])
        guard !urls.isEmpty else { return [] }

        let loadedTracks: [Track] = await withTaskGroup(of: Track.self, returning: [Track].self) { group in
            var tracks: [Track] = []
            tracks.reserveCapacity(urls.count)
            var nextIndex = 0

            let initialCount = min(maxConcurrency, urls.count)
            for _ in 0..<initialCount {
                let url = urls[nextIndex]
                nextIndex += 1
                group.addTask {
                    (try? await MetadataService.load(for: url)) ?? Track(url: url)
                }
            }

            for await track in group {
                tracks.append(track)
                if nextIndex < urls.count {
                    let url = urls[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        (try? await MetadataService.load(for: url)) ?? Track(url: url)
                    }
                }
            }

            return tracks
        }

        return groupIntoAlbums(tracks: loadedTracks, rootDirectory: directory)
    }

    private static func resolveAlbumArtist(for tracks: [Track]) -> String {
        let validArtists = tracks
            .map { $0.artist.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "Artista desconhecido" }

        guard !validArtists.isEmpty else { return "Artista desconhecido" }

        var counts: [String: Int] = [:]
        for artist in validArtists {
            counts[artist, default: 0] += 1
        }

        if counts.count > 2, let top = counts.max(by: { $0.value < $1.value }), top.value < validArtists.count / 2 {
            return "Vários Artistas"
        }

        return counts.max(by: { $0.value < $1.value })?.key ?? validArtists[0]
    }
}
