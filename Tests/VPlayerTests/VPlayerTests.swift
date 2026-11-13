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

// MARK: - Main Entry

@main
struct VPlayerTestsRunner {
    static func main() throws {
        print("🧪 Executando testes unitários do VPlayer...")
        testLyricsParsing()
        testEqualizerModels()
        try testLibraryScannerRecursiveExpansion()
        try testPlaylistPersistence()

        print("✅ Passaram: \(passedTests) | ❌ Falharam: \(failedTests)")
        if failedTests > 0 {
            exit(1)
        }
    }
}
