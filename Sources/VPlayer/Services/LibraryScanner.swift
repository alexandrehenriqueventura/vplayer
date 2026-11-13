import Foundation

enum LibraryScanner {
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "mp4", "flac", "wav", "aac", "aiff", "aif", "caf", "alac", "ogg", "opus"
    ]

    /// Expands a mixed list of file and directory URLs into a sorted, deduplicated list of supported audio file URLs.
    static func expand(urls: [URL], fileManager: FileManager = .default) -> [URL] {
        var result: [URL] = []
        var seen: Set<URL> = []

        for url in urls {
            let standardized = url.standardizedFileURL
            let isDirectory = (try? standardized.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDirectory {
                guard let enumerator = fileManager.enumerator(
                    at: standardized,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                var discovered: [URL] = []
                for case let itemURL as URL in enumerator {
                    let isFile = (try? itemURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                    guard isFile, isSupportedAudio(itemURL) else { continue }
                    discovered.append(itemURL.standardizedFileURL)
                }

                discovered.sort {
                    $0.path.localizedStandardCompare($1.path) == .orderedAscending
                }

                for fileURL in discovered where seen.insert(fileURL).inserted {
                    result.append(fileURL)
                }
            } else if fileManager.fileExists(atPath: standardized.path),
                      isSupportedAudio(standardized),
                      seen.insert(standardized).inserted {
                result.append(standardized)
            }
        }

        return result
    }

    static func isSupportedAudio(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
