import Foundation

enum LyricsService {
    static func load(for track: Track) -> [LyricLine] {
        if let embedded = track.lyricsData, !embedded.isEmpty {
            let parsed = parse(embedded)
            if !parsed.isEmpty { return parsed }
        }

        let sidecar = track.url.deletingPathExtension().appendingPathExtension("lrc")
        if let text = try? String(contentsOf: sidecar, encoding: .utf8) {
            return parse(text)
        }
        return []
    }

    static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for rawLine in text.components(separatedBy: .newlines) {
            let nsLine = rawLine as NSString
            let matches = regex.matches(in: rawLine, range: NSRange(location: 0, length: nsLine.length))
            guard !matches.isEmpty else { continue }

            var timestamps: [TimeInterval] = []
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                let minutes = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.numberOfRanges >= 3, match.range(at: 3).location != NSNotFound {
                    let raw = nsLine.substring(with: match.range(at: 3))
                    let value = Double(raw) ?? 0
                    fraction = raw.count == 1 ? value / 10 : raw.count == 2 ? value / 100 : value / 1000
                }
                timestamps.append(minutes * 60 + seconds + fraction)
            }

            let lastMatch = matches[matches.count - 1]
            let contentStart = NSMaxRange(lastMatch.range)
            let content = nsLine.substring(from: contentStart).trimmingCharacters(in: .whitespaces)

            for (i, timestamp) in timestamps.enumerated() {
                lines.append(LyricLine(time: timestamp, text: content, id: "\(i)-\(timestamp)-\(content)"))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    static func plainText(lines: [LyricLine]) -> String {
        lines.map(\.text).joined(separator: "\n")
    }
}
