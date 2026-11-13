import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isSeeking = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var statusMessage = ""
    @Published var isLoading = false

    @Published var volume: Double {
        didSet {
            audio.setVolume(Float(isMuted ? 0 : volume))
            UserDefaults.standard.set(volume, forKey: Keys.volume)
        }
    }
    @Published var isMuted = false
    @Published var shuffle: Bool {
        didSet { UserDefaults.standard.set(shuffle, forKey: Keys.shuffle) }
    }
    @Published var repeatMode: RepeatMode {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: Keys.repeatMode) }
    }

    @Published var eqEnabled: Bool {
        didSet { applyEQ(); UserDefaults.standard.set(eqEnabled, forKey: Keys.eqEnabled) }
    }
    @Published var eqGains: [Float] {
        didSet { applyEQ(); saveEQ() }
    }
    @Published var eqPreamp: Float {
        didSet { applyEQ(); UserDefaults.standard.set(eqPreamp, forKey: Keys.eqPreamp) }
    }
    @Published var selectedPreset: EQPreset = .flat

    @Published var playbackRate: Float {
        didSet { audio.setRate(playbackRate); UserDefaults.standard.set(playbackRate, forKey: Keys.rate) }
    }
    @Published var pitchShift: Float {
        didSet { audio.setPitch(pitchShift); UserDefaults.standard.set(pitchShift, forKey: Keys.pitch) }
    }
    @Published var reverbMix: Float {
        didSet { applyReverb(); UserDefaults.standard.set(reverbMix, forKey: Keys.reverbMix) }
    }
    @Published var reverbPreset: AVAudioUnitReverbPreset {
        didSet { applyReverb(); UserDefaults.standard.set(reverbPreset.rawValue, forKey: Keys.reverbPreset) }
    }
    @Published var crossfade: Double {
        didSet { UserDefaults.standard.set(crossfade, forKey: Keys.crossfade) }
    }
    @Published var showPlaylist: Bool {
        didSet { UserDefaults.standard.set(showPlaylist, forKey: Keys.showPlaylist) }
    }
    @Published var showConsole: Bool {
        didSet { UserDefaults.standard.set(showConsole, forKey: Keys.showConsole) }
    }

    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int?

    let audio = AudioEngineService()
    private let nowPlaying = NowPlayingService()
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var crossfadedInto: UUID?
    private var metadataTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingMetadataCount = 0

    var currentTrack: Track? {
        guard let currentIndex, tracks.indices.contains(currentIndex) else { return nil }
        return tracks[currentIndex]
    }

    var filteredTracks: [Track] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(query)
                || $0.artist.lowercased().contains(query)
                || $0.album.lowercased().contains(query)
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    init() {
        let defaults = UserDefaults.standard
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.8
        shuffle = defaults.bool(forKey: Keys.shuffle)
        repeatMode = RepeatMode(rawValue: defaults.string(forKey: Keys.repeatMode) ?? "off") ?? .off
        eqEnabled = defaults.object(forKey: Keys.eqEnabled) as? Bool ?? true
        eqGains = defaults.array(forKey: Keys.eqGains) as? [Float] ?? EQPreset.flat.gains
        eqPreamp = defaults.object(forKey: Keys.eqPreamp) as? Float ?? 0
        playbackRate = defaults.object(forKey: Keys.rate) as? Float ?? 1
        pitchShift = defaults.object(forKey: Keys.pitch) as? Float ?? 0
        reverbMix = defaults.object(forKey: Keys.reverbMix) as? Float ?? 0
        reverbPreset = AVAudioUnitReverbPreset(rawValue: defaults.integer(forKey: Keys.reverbPreset))
            ?? .mediumRoom
        crossfade = defaults.object(forKey: Keys.crossfade) as? Double ?? 3
        showPlaylist = defaults.object(forKey: Keys.showPlaylist) as? Bool ?? true
        showConsole = defaults.object(forKey: Keys.showConsole) as? Bool ?? true

        audio.setVolume(Float(volume))
        applyEQ()
        audio.setRate(playbackRate)
        audio.setPitch(pitchShift)
        applyReverb()

        audio.onTrackEnded = { [weak self] id in
            self?.handleTrackEnded(id)
        }
        audio.onError = { [weak self] message in
            self?.errorMessage = message
        }

        nowPlaying.onPlay = { [weak self] in self?.play() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onNext = { [weak self] in self?.playNext() }
        nowPlaying.onPrevious = { [weak self] in self?.playPrevious() }

        registerShortcuts()
        startTimer()
    }

    deinit {
        timer?.cancel()
        cancellables.removeAll()
    }

    private enum Keys {
        static let volume = "vplayer.volume"
        static let shuffle = "vplayer.shuffle"
        static let repeatMode = "vplayer.repeatMode"
        static let eqEnabled = "vplayer.eqEnabled"
        static let eqGains = "vplayer.eqGains"
        static let eqPreamp = "vplayer.eqPreamp"
        static let rate = "vplayer.rate"
        static let pitch = "vplayer.pitch"
        static let reverbMix = "vplayer.reverbMix"
        static let reverbPreset = "vplayer.reverbPreset"
        static let crossfade = "vplayer.crossfade"
        static let showPlaylist = "vplayer.showPlaylist"
        static let showConsole = "vplayer.showConsole"
    }

    private func saveEQ() {
        UserDefaults.standard.set(eqGains, forKey: Keys.eqGains)
    }

    private func applyEQ() {
        var gains = eqGains
        if gains.count != EQBand.frequencies.count {
            gains = EQPreset.flat.gains
        }
        audio.configureEQ(gains: gains, preamp: eqPreamp, enabled: eqEnabled)
    }

    private func applyReverb() {
        audio.setReverb(mix: reverbMix, preset: reverbPreset)
    }

    private func startTimer() {
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard isPlaying else { return }
        if !isSeeking {
            currentTime = audio.currentTime
        }
        updateLyricHighlight()
        updateNowPlaying()

        if crossfade > 0, duration > 0 {
            let remaining = duration - currentTime
            if remaining <= crossfade, remaining > 0, crossfadedInto != currentTrack?.id {
                startCrossfade()
            }
        }
    }

    private func updateLyricHighlight() {
        guard !lyrics.isEmpty else {
            if currentLyricIndex != nil { currentLyricIndex = nil }
            return
        }
        var index: Int?
        var low = 0
        var high = lyrics.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= currentTime + 0.15 {
                index = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        if index != currentLyricIndex {
            currentLyricIndex = index
        }
    }

    private func updateNowPlaying() {
        nowPlaying.update(
            track: currentTrack,
            elapsed: currentTime,
            duration: duration,
            isPlaying: isPlaying,
            rate: playbackRate
        )
    }

    func addFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        isLoading = true
        pendingMetadataCount = urls.count
        for url in urls {
            let track = Track(url: url)
            tracks.append(track)
            metadataTasks[track.id] = Task { [weak self] in
                guard let self else { return }
                do {
                    let loaded = try await MetadataService.load(for: url)
                    guard let index = self.tracks.firstIndex(where: { $0.id == track.id }) else { return }
                    self.tracks[index] = loaded
                    if self.currentIndex == index {
                        self.duration = loaded.duration
                        self.lyrics = LyricsService.load(for: loaded)
                    }
                } catch {
                    self.errorMessage = "Erro ao carregar metadados de \(url.lastPathComponent): \(error.localizedDescription)"
                }
                self.pendingMetadataCount -= 1
                if self.pendingMetadataCount <= 0 {
                    self.isLoading = false
                }
            }
        }
        statusMessage = "\(urls.count) arquivo(s) adicionado(s)"
    }

    func removeTracks(at offsets: IndexSet) {
        let removedIDs = offsets.compactMap { tracks.indices.contains($0) ? tracks[$0].id : nil }
        let currentID = currentTrack?.id
        tracks.remove(atOffsets: offsets)
        if let currentID, removedIDs.contains(currentID) {
            stop()
            currentIndex = nil
        } else if let currentID, let newIndex = tracks.firstIndex(where: { $0.id == currentID }) {
            currentIndex = newIndex
        }
    }

    func removeTrack(_ track: Track) {
        guard let index = tracks.firstIndex(of: track) else { return }
        removeTracks(at: IndexSet(integer: index))
    }

    func clearPlaylist() {
        stop()
        tracks.removeAll()
        currentIndex = nil
        lyrics = []
    }

    func moveTracks(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        refreshCurrentIndex()
    }

    private func refreshCurrentIndex() {
        guard let current = currentTrack?.id, let index = tracks.firstIndex(where: { $0.id == current }) else { return }
        currentIndex = index
    }

    func play(track: Track) {
        guard let index = tracks.firstIndex(of: track) else { return }
        play(index: index)
    }

    func play(index: Int) {
        guard tracks.indices.contains(index) else { return }
        currentIndex = index
        crossfadedInto = nil
        let track = tracks[index]
        duration = track.duration
        currentTime = 0
        lyrics = LyricsService.load(for: track)

        do {
            let file = try audio.makeFile(for: track.url)
            if duration <= 0 {
                duration = audio.duration(of: file)
            }
            audio.play(trackID: track.id, file: file)
            isPlaying = true
            updateNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }
    }

    func play() {
        guard currentIndex != nil else {
            if !tracks.isEmpty {
                play(index: 0)
            }
            return
        }
        if isPlaying {
            audio.pause()
            isPlaying = false
        } else {
            audio.resume()
            isPlaying = true
        }
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        audio.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func stop() {
        audio.stop()
        isPlaying = false
        currentTime = 0
        crossfadedInto = nil
        nowPlaying.clear()
    }

    func togglePlay() {
        play()
    }

    func playNext() {
        guard !tracks.isEmpty else { return }
        guard let next = nextIndex() else {
            stop()
            return
        }
        play(index: next)
    }

    func playPrevious() {
        guard !tracks.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let previous = previousIndex()
        if let previous {
            play(index: previous)
        } else {
            seek(to: 0)
        }
    }

    private func nextIndex() -> Int? {
        guard let currentIndex, !tracks.isEmpty else { return tracks.isEmpty ? nil : 0 }
        if shuffle {
            let candidates = tracks.indices.filter { $0 != currentIndex }
            guard !candidates.isEmpty else { return currentIndex }
            return candidates.randomElement()
        }
        let next = currentIndex + 1
        if next < tracks.count { return next }
        return repeatMode == .all ? 0 : nil
    }

    private func previousIndex() -> Int? {
        guard let currentIndex, !tracks.isEmpty else { return nil }
        if shuffle {
            let candidates = tracks.indices.filter { $0 != currentIndex }
            guard !candidates.isEmpty else { return currentIndex }
            return candidates.randomElement()
        }
        let previous = currentIndex - 1
        if previous >= 0 { return previous }
        return repeatMode == .all ? tracks.count - 1 : nil
    }

    private func startCrossfade() {
        guard let next = nextIndex(), next != currentIndex else { return }
        let nextTrack = tracks[next]
        guard let file = try? audio.makeFile(for: nextTrack.url) else { return }

        crossfadedInto = nextTrack.id
        currentIndex = next
        duration = nextTrack.duration > 0 ? nextTrack.duration : audio.duration(of: file)
        currentTime = 0
        lyrics = LyricsService.load(for: nextTrack)
        audio.crossfade(to: nextTrack.id, file: file, duration: crossfade)
        isPlaying = true
        updateNowPlaying()
    }

    private func handleTrackEnded(_ id: UUID) {
        guard id == currentTrack?.id else { return }
        if repeatMode == .one {
            if let currentIndex {
                play(index: currentIndex)
            }
            return
        }
        guard let next = nextIndex() else {
            isPlaying = false
            currentTime = duration
            nowPlaying.update(track: currentTrack, elapsed: currentTime, duration: duration, isPlaying: false, rate: playbackRate)
            return
        }
        play(index: next)
    }

    func seek(to seconds: TimeInterval) {
        guard let currentIndex else { return }
        let track = tracks[currentIndex]
        guard (try? audio.makeFile(for: track.url)) != nil else { return }
        audio.seek(to: seconds)
        currentTime = seconds
        updateNowPlaying()
    }

    func beginSeeking() {
        isSeeking = true
    }

    func endSeeking() {
        isSeeking = false
    }

    func setVolume(_ value: Double) {
        volume = max(0, min(value, 1))
        if volume > 0 { isMuted = false }
    }

    func toggleMute() {
        isMuted.toggle()
    }

    func applyPreset(_ preset: EQPreset) {
        selectedPreset = preset
        eqGains = preset.gains
    }

    func resetEQ() {
        applyPreset(.flat)
        eqPreamp = 0
    }

    func cycleRepeatMode() {
        let modes = RepeatMode.allCases
        let index = modes.firstIndex(of: repeatMode) ?? 0
        repeatMode = modes[(index + 1) % modes.count]
    }

    func resetEffects() {
        playbackRate = 1
        pitchShift = 0
        reverbMix = 0
    }

    func exportPlaylist(to url: URL) {
        let lines = ["#EXTM3U"] + tracks.map { $0.url.path }
        let text = lines.joined(separator: "\n")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Playlist salva em \(url.lastPathComponent)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importPlaylist(from url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            errorMessage = "Não foi possível ler a playlist."
            return
        }
        let baseURL = url.deletingLastPathComponent()
        let urls = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { URL(fileURLWithPath: $0, relativeTo: baseURL).standardized.absoluteURL }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        addFiles(urls: urls)
    }

    private func registerShortcuts() {
        let center = NotificationCenter.default
        center.publisher(for: .vplayerTogglePlay)
            .sink { [weak self] _ in Task { @MainActor in self?.togglePlay() } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerNext)
            .sink { [weak self] _ in Task { @MainActor in self?.playNext() } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerPrevious)
            .sink { [weak self] _ in Task { @MainActor in self?.playPrevious() } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerVolumeUp)
            .sink { [weak self] _ in Task { @MainActor in self?.setVolume((self?.volume ?? 0) + 0.05) } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerVolumeDown)
            .sink { [weak self] _ in Task { @MainActor in self?.setVolume((self?.volume ?? 0) - 0.05) } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerToggleShuffle)
            .sink { [weak self] _ in Task { @MainActor in self?.shuffle.toggle() } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerCycleRepeat)
            .sink { [weak self] _ in Task { @MainActor in
                guard let self else { return }
                let modes = RepeatMode.allCases
                let index = modes.firstIndex(of: self.repeatMode) ?? 0
                self.repeatMode = modes[(index + 1) % modes.count]
            } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerSeek)
            .sink { [weak self] note in
                let position = note.userInfo?["position"] as? Double ?? 0
                Task { @MainActor in self?.seek(to: position) }
            }
            .store(in: &cancellables)
        center.publisher(for: .vplayerTogglePlaylist)
            .sink { [weak self] _ in Task { @MainActor in self?.showPlaylist.toggle() } }
            .store(in: &cancellables)
        center.publisher(for: .vplayerToggleConsole)
            .sink { [weak self] _ in Task { @MainActor in self?.showConsole.toggle() } }
            .store(in: &cancellables)
    }
}
