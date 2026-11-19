import Foundation

private var passedTests = 0
private var failedTests = 0

private func check(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
    if condition {
        passedTests += 1
    } else {
        failedTests += 1
        print("❌ FAIL [\(file):\(line)]: \(message)")
    }
}

private func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #fileID, line: Int = #line) {
    if actual == expected {
        passedTests += 1
    } else {
        failedTests += 1
        print("❌ FAIL [\(file):\(line)]: \(message) — esperado: \(expected), obtido: \(actual)")
    }
}

// MARK: - LyricsService Tests

func testLyricsParsing() {
    let lrc = """
    [ar:TesseracT]
    [ti:Tourniquet]
    [00:12.50]First line
    [00:05.00]Intro line
    [01:02.5]Second line
    [01:10.00][02:20.00]Repeated chorus
    Invalid line without timestamp
    """

    let parsed = LyricsService.parse(lrc)
    checkEqual(parsed.count, 5, "Deve extrair 5 linhas de letra com timestamps válidos")

    if parsed.count == 5 {
        checkEqual(parsed[0].text, "Intro line", "Primeira linha deve ser ordenada cronologicamente")
        check(abs(parsed[0].time - 5.0) < 0.001, "Timestamp 00:05.00 deve ser 5.0s")

        checkEqual(parsed[1].text, "First line", "Segunda linha deve ser 00:12.50")
        check(abs(parsed[1].time - 12.5) < 0.001, "Timestamp 00:12.50 deve ser 12.5s")

        checkEqual(parsed[2].text, "Second line", "Terceira linha deve ser 01:02.5")
        check(abs(parsed[2].time - 62.5) < 0.001, "Timestamp 01:02.5 deve ser 62.5s")

        checkEqual(parsed[3].text, "Repeated chorus", "Quarta linha deve suportar múltiplos timestamps")
        checkEqual(parsed[4].text, "Repeated chorus", "Quinta linha deve suportar múltiplos timestamps")
    }

    // ID stability check
    let parsedAgain = LyricsService.parse(lrc)
    checkEqual(parsed.map(\.id), parsedAgain.map(\.id), "IDs das linhas devem ser estáveis entre execuções")
}

// MARK: - EQ Models Tests

func testEqualizerModels() {
    checkEqual(EQBand.frequencies.count, 10, "Equalizador deve ter 10 bandas")
    checkEqual(EQBand.label(32), "32", "Label 32 Hz")
    checkEqual(EQBand.label(1000), "1k", "Label 1000 Hz")
    checkEqual(EQBand.label(16000), "16k", "Label 16000 Hz")

    for preset in EQPreset.allCases {
        checkEqual(preset.gains.count, 10, "Preset \(preset.title) deve ter 10 ganhos")
        let inRange = preset.gains.allSatisfy { $0 >= -12 && $0 <= 12 }
        check(inRange, "Ganhos do preset \(preset.title) devem estar entre -12 e +12 dB")
    }
}

// MARK: - LibraryScanner Tests

func testLibraryScannerRecursiveExpansion() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent("VPlayerScannerTest-\(UUID().uuidString)", isDirectory: true)
    let subDir = tempRoot.appendingPathComponent("Album", isDirectory: true)
    let nestedDir = subDir.appendingPathComponent("Disc2", isDirectory: true)

    try fm.createDirectory(at: nestedDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempRoot) }

    let track1 = tempRoot.appendingPathComponent("01 Intro.mp3")
    let track2 = subDir.appendingPathComponent("02 Main.flac")
    let track3 = nestedDir.appendingPathComponent("03 Bonus.m4a")
    let ignored = subDir.appendingPathComponent("cover.jpg")
    let hidden = subDir.appendingPathComponent(".hidden.mp3")

    try Data().write(to: track1)
    try Data().write(to: track2)
    try Data().write(to: track3)
    try Data().write(to: ignored)
    try Data().write(to: hidden)

    // Pass directory + duplicate single file
    let expanded = LibraryScanner.expand(urls: [tempRoot, track1])

    checkEqual(expanded.count, 3, "Deve expandir recursivamente 3 faixas válidas sem duplicatas")
    check(expanded.contains(track1.standardizedFileURL), "Deve conter 01 Intro.mp3")
    check(expanded.contains(track2.standardizedFileURL), "Deve conter 02 Main.flac")
    check(expanded.contains(track3.standardizedFileURL), "Deve conter 03 Bonus.m4a")
    check(!expanded.contains(ignored.standardizedFileURL), "Não deve incluir cover.jpg")
    check(!expanded.contains(hidden.standardizedFileURL), "Não deve incluir arquivos ocultos")
}

// MARK: - PlaylistPersistenceService Tests

func testPlaylistPersistence() throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("VPlayerPersistenceTest-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }

    let fileA = tempDir.appendingPathComponent("a.mp3")
    let fileB = tempDir.appendingPathComponent("b.mp3")
    let fileMissing = tempDir.appendingPathComponent("missing.mp3")
    try Data().write(to: fileA)
    try Data().write(to: fileB)

    let storageURL = tempDir.appendingPathComponent("session.json")
    let service = PlaylistPersistenceService(storageURL: storageURL)

    let tracks = [
        Track(url: fileA, title: "Track A", artist: "Artist A", album: "Album", duration: 120),
        Track(url: fileMissing, title: "Missing", artist: "Nobody", album: "None", duration: 60),
        Track(url: fileB, title: "Track B", artist: "Artist B", album: "Album", duration: 240)
    ]

    service.save(tracks: tracks, currentIndex: 2)
    let loaded = service.load()

    checkEqual(loaded.tracks.count, 2, "Deve restaurar apenas as 2 faixas existentes no disco")
    checkEqual(loaded.tracks.first?.title, "Track A", "Deve preservar metadados da primeira faixa")
    checkEqual(loaded.tracks.last?.title, "Track B", "Deve preservar metadados da última faixa")
    checkEqual(loaded.currentIndex, 1, "Deve recalcular currentIndex após filtrar faixa ausente")
}

// MARK: - MusicLibraryService Tests

func testMusicLibraryAlbumGroupingAndFolderArt() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("VPlayerLibraryTest-\(UUID().uuidString)", isDirectory: true)
    let albumADir = root.appendingPathComponent("Portals", isDirectory: true)
    let albumBDir = root.appendingPathComponent("UntaggedLive", isDirectory: true)
    try fm.createDirectory(at: albumADir, withIntermediateDirectories: true)
    try fm.createDirectory(at: albumBDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let coverData = Data([0xFF, 0xD8, 0xFF, 0xE0])
    try coverData.write(to: albumBDir.appendingPathComponent("cover.jpg"))

    let t1 = Track(url: albumADir.appendingPathComponent("02 Tourniquet.mp3"), title: "Tourniquet", artist: "TesseracT", album: "Portals", duration: 278)
    let t2 = Track(url: albumADir.appendingPathComponent("01 Of Matter.mp3"), title: "Of Matter", artist: "TesseracT", album: "Portals", duration: 310)
    let t3 = Track(url: albumBDir.appendingPathComponent("01 Jam.flac"), title: "Jam", artist: "Artista desconhecido", album: "Álbum desconhecido", duration: 180)

    let albums = MusicLibraryService.groupIntoAlbums(tracks: [t1, t2, t3], rootDirectory: root)
    checkEqual(albums.count, 2, "Deve agrupar em 2 álbuns distintos")

    if let portals = albums.first(where: { $0.title == "Portals" }) {
        checkEqual(portals.artist, "TesseracT", "Artista do álbum Portals deve ser TesseracT")
        checkEqual(portals.tracks.count, 2, "Álbum Portals deve conter 2 faixas")
        checkEqual(portals.tracks.first?.title, "Of Matter", "Faixas devem ser ordenadas naturalmente (01 antes de 02)")
    } else {
        check(false, "Álbum Portals deve existir")
    }

    if let untagged = albums.first(where: { $0.title == "UntaggedLive" }) {
        checkEqual(untagged.artworkData, coverData, "Deve detectar cover.jpg da pasta quando não houver arte embutida")
        checkEqual(untagged.tracks.first?.artworkData, coverData, "Deve propagar arte da pasta para as faixas")
    } else {
        check(false, "Álbum sem tag deve usar o nome da pasta UntaggedLive")
    }
}

func testMusicLibraryDeduplicationAndMultiDiscMerge() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("VPlayerDedupeTest-\(UUID().uuidString)", isDirectory: true)
    let cd1 = root.appendingPathComponent("Altered State/CD1", isDirectory: true)
    let cd2 = root.appendingPathComponent("Altered State/CD2", isDirectory: true)
    let backup = root.appendingPathComponent("Backup/Altered State", isDirectory: true)
    let queenDir = root.appendingPathComponent("Queen", isDirectory: true)
    let fooDir = root.appendingPathComponent("Foo Fighters", isDirectory: true)
    try fm.createDirectory(at: cd1, withIntermediateDirectories: true)
    try fm.createDirectory(at: cd2, withIntermediateDirectories: true)
    try fm.createDirectory(at: backup, withIntermediateDirectories: true)
    try fm.createDirectory(at: queenDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: fooDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let art = Data([0x89, 0x50, 0x4E, 0x47])
    let tracks = [
        // Same track in CD1 (no art, mp3) and Backup (with art, flac) -> should merge and keep flac+art
        Track(url: cd1.appendingPathComponent("01 Proxy.mp3"), title: "Proxy", artist: "TesseracT", album: "Altered State", duration: 240, artworkData: nil),
        Track(url: backup.appendingPathComponent("01 Proxy.flac"), title: "Proxy", artist: "TesseracT", album: "Altered State", duration: 240, artworkData: art),
        // Different track in CD2 -> should merge into same Altered State album
        Track(url: cd2.appendingPathComponent("02 Retrospect.mp3"), title: "Retrospect", artist: "TesseracT", album: "Altered State", duration: 310),
        // Different artists with same album name -> must stay separate
        Track(url: queenDir.appendingPathComponent("01 Bohemian.mp3"), title: "Bohemian", artist: "Queen", album: "Greatest Hits", duration: 355),
        Track(url: fooDir.appendingPathComponent("01 Everlong.mp3"), title: "Everlong", artist: "Foo Fighters", album: "Greatest Hits", duration: 250)
    ]

    let albums = MusicLibraryService.groupIntoAlbums(tracks: tracks, rootDirectory: root)
    checkEqual(albums.count, 3, "Deve resultar em 3 álbuns (1 Altered State unificado + 2 Greatest Hits distintos)")

    if let altered = albums.first(where: { $0.title == "Altered State" }) {
        checkEqual(altered.tracks.count, 2, "Altered State deve conter 2 faixas únicas após deduplicação")
        checkEqual(altered.artworkData, art, "Deve preservar a arte do álbum mesclado")
    } else {
        check(false, "Álbum Altered State deve existir")
    }
}

// MARK: - Main Entry

@main
struct VPlayerTestsRunner {
    static func main() throws {
        print("🧪 Executando testes unitários do VPlayer...")
        testLyricsParsing()
        testEqualizerModels()
        try testLibraryScannerRecursiveExpansion()
        try testPlaylistPersistence()
        try testMusicLibraryAlbumGroupingAndFolderArt()
        try testMusicLibraryDeduplicationAndMultiDiscMerge()

        print("✅ Passaram: \(passedTests) | ❌ Falharam: \(failedTests)")
        if failedTests > 0 {
            exit(1)
        }
    }
}
