import AVFoundation
import Foundation

@MainActor
final class AudioEngineService {
    struct BusState {
        var trackID: UUID
        var file: AVAudioFile
        var offset: TimeInterval
        var baseSample: AVAudioFramePosition
    }

    private let engine = AVAudioEngine()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let inputMixer = AVAudioMixerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: EQBand.frequencies.count)
    private let timePitch = AVAudioUnitTimePitch()
    private let reverb = AVAudioUnitReverb()

    private var busStates: [Int: BusState] = [:]
    private var activeBus: Int?
    private var crossfadeTargetBus: Int?
    private var configured = false
    private var isRunning = false
    private var pausedPosition: TimeInterval?

    var onTrackEnded: ((UUID) -> Void)?
    var onError: ((String) -> Void)?

    private var fileCache: [URL: AVAudioFile] = [:]
    private var configChangeObserver: NSObjectProtocol?

    var isPlaying: Bool {
        playerA.isPlaying || playerB.isPlaying
    }

    var currentTime: TimeInterval {
        if let pausedPosition {
            return pausedPosition
        }
        let bus = crossfadeTargetBus ?? activeBus
        guard let bus, let state = busStates[bus] else { return 0 }
        let node = player(for: bus)
        guard node.isPlaying else { return state.offset }
        guard let renderTime = node.lastRenderTime,
              let nodeTime = node.playerTime(forNodeTime: renderTime) else { return state.offset }
        let elapsed = Double(nodeTime.sampleTime - state.baseSample) / nodeTime.sampleRate
        return max(0, state.offset + elapsed)
    }

    init() {
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 0
        timePitch.rate = 1
        timePitch.pitch = 0
        configureEngine()
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleConfigurationChange()
            }
        }
    }

    deinit {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func player(for bus: Int) -> AVAudioPlayerNode {
        bus == 0 ? playerA : playerB
    }

    private var outputFormat: AVAudioFormat {
        let hardware = engine.outputNode.outputFormat(forBus: 0)
        if hardware.sampleRate > 0 && hardware.channelCount > 0 {
            return hardware
        }
        return AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }

    private func configureEngine() {
        guard !configured else { return }
        configured = true

        engine.attach(playerA)
        engine.attach(playerB)
        engine.attach(inputMixer)
        engine.attach(eq)
        engine.attach(timePitch)
        engine.attach(reverb)

        let format = outputFormat
        engine.connect(inputMixer, to: eq, format: format)
        engine.connect(eq, to: timePitch, format: format)
        engine.connect(timePitch, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        engine.mainMixerNode.outputVolume = 0.8
        engine.prepare()
    }

    private func handleConfigurationChange() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        do {
            try startEngine()
        } catch {
            onError?("Falha ao reiniciar o motor de áudio: \(error.localizedDescription)")
        }
    }

    private func startEngine() throws {
        configureEngine()
        if !engine.isRunning {
            try engine.start()
        }
        isRunning = true
    }

    private func prepareBus(_ bus: Int, file: AVAudioFile) {
        let node = player(for: bus)
        node.stop()
        engine.disconnectNodeOutput(node)
        engine.connect(node, to: inputMixer, format: file.processingFormat)
        engine.prepare()
    }

    func makeFile(for url: URL) throws -> AVAudioFile {
        if let cached = fileCache[url] {
            return cached
        }
        do {
            let file = try AVAudioFile(forReading: url)
            fileCache[url] = file
            return file
        } catch {
            throw NSError(
                domain: "VPlayer.Audio",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Formato não suportado: \(url.lastPathComponent)"]
            )
        }
    }

    func play(trackID: UUID, file: AVAudioFile, offset: TimeInterval = 0) {
        do {
            try startEngine()
        } catch {
            onError?("Não foi possível iniciar o áudio: \(error.localizedDescription)")
            return
        }

        if let target = crossfadeTargetBus {
            player(for: target).stop()
            busStates.removeValue(forKey: target)
            crossfadeTargetBus = nil
        }

        playerA.stop()
        playerB.stop()
        busStates.removeAll()
        pausedPosition = nil

        let bus = 0
        prepareBus(bus, file: file)
        let node = playerA
        let rate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, min(offset, duration(of: file) - 0.01)) * rate)
        let remaining = max(0, file.length - startFrame)

        busStates[bus] = BusState(trackID: trackID, file: file, offset: Double(startFrame) / rate, baseSample: 0)
        activeBus = bus
        crossfadeTargetBus = nil
        setBusVolume(0, value: 1)
        setBusVolume(1, value: 0)

        guard remaining > 0 else {
            onTrackEnded?(trackID)
            return
        }

        node.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max))),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.activeBus == bus else { return }
                self.onTrackEnded?(trackID)
            }
        }
        node.play()
    }

    func crossfade(to trackID: UUID, file: AVAudioFile, duration fadeDuration: TimeInterval) {
        do {
            try startEngine()
        } catch {
            onError?("Não foi possível iniciar o áudio: \(error.localizedDescription)")
            return
        }

        let previousBus = activeBus
        let newBus = previousBus == 0 ? 1 : 0
        prepareBus(newBus, file: file)
        let node = player(for: newBus)
        let startFrame = AVAudioFramePosition(0)
        let remaining = file.length

        busStates[newBus] = BusState(trackID: trackID, file: file, offset: 0, baseSample: 0)
        crossfadeTargetBus = newBus
        setBusVolume(newBus, value: fadeDuration > 0 ? 0 : 1)

        node.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max))),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.crossfadeTargetBus == newBus || self.activeBus == newBus else { return }
                self.onTrackEnded?(trackID)
            }
        }
        node.play()

        guard let previousBus, fadeDuration > 0 else {
            activeBus = newBus
            crossfadeTargetBus = nil
            return
        }
        rampVolume(bus: previousBus, from: 1, to: 0, duration: fadeDuration)
        rampVolume(bus: newBus, from: 0, to: 1, duration: fadeDuration)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(fadeDuration * 1_000_000_000))
            guard let self else { return }
            self.player(for: previousBus).stop()
            self.busStates.removeValue(forKey: previousBus)
            self.activeBus = newBus
            self.crossfadeTargetBus = nil
        }
    }

    private func rampVolume(bus: Int, from: Float, to: Float, duration: TimeInterval) {
        let steps = max(1, Int(duration / 0.03))
        Task { @MainActor [weak self] in
            for step in 0...steps {
                let progress = Float(step) / Float(steps)
                let value = from + (to - from) * progress
                self?.setBusVolume(bus, value: value)
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    private func setBusVolume(_ bus: Int, value: Float) {
        guard bus == 0 || bus == 1 else { return }
        player(for: bus).volume = max(0, min(value, 1))
    }

    func pause() {
        if pausedPosition == nil {
            pausedPosition = currentTime
        }
        if let bus = activeBus {
            busStates[bus]?.offset = pausedPosition ?? 0
        }
        playerA.pause()
        playerB.pause()
    }

    func resume() {
        pausedPosition = nil
        do {
            try startEngine()
        } catch {
            onError?("Não foi possível retomar o áudio: \(error.localizedDescription)")
            return
        }
        guard let bus = activeBus else { return }
        let node = player(for: bus)
        if let renderTime = node.lastRenderTime,
           let nodeTime = node.playerTime(forNodeTime: renderTime) {
            busStates[bus]?.baseSample = nodeTime.sampleTime
        }
        node.play()
    }

    func stop() {
        pausedPosition = nil
        crossfadeTargetBus = nil
        playerA.stop()
        playerB.stop()
        busStates.removeAll()
        activeBus = nil
    }

    func seek(to seconds: TimeInterval) {
        guard let bus = activeBus, let state = busStates[bus] else { return }
        let node = player(for: bus)
        let wasPlaying = node.isPlaying
        let rate = state.file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, seconds) * rate)
        let remaining = max(0, state.file.length - startFrame)

        node.stop()
        busStates[bus] = BusState(trackID: state.trackID, file: state.file, offset: seconds, baseSample: 0)

        guard remaining > 0 else {
            onTrackEnded?(state.trackID)
            return
        }

        node.scheduleSegment(
            state.file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max))),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.activeBus == bus else { return }
                self.onTrackEnded?(state.trackID)
            }
        }

        if wasPlaying {
            node.play()
        } else {
            pausedPosition = seconds
        }
    }

    func duration(of file: AVAudioFile) -> TimeInterval {
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return 0 }
        return Double(file.length) / rate
    }

    func setVolume(_ value: Float) {
        engine.mainMixerNode.outputVolume = max(0, min(value, 1))
    }

    func configureEQ(gains: [Float], preamp: Float, enabled: Bool) {
        eq.bypass = !enabled
        eq.globalGain = preamp
        for (index, band) in eq.bands.enumerated() {
            let isFirst = index == 0
            let isLast = index == eq.bands.count - 1
            band.filterType = isFirst ? .lowShelf : (isLast ? .highShelf : .parametric)
            band.frequency = EQBand.frequencies[index]
            band.bandwidth = 1
            band.gain = gains[index]
            band.bypass = false
        }
    }

    func setRate(_ rate: Float) {
        timePitch.rate = max(0.5, min(rate, 2))
    }

    func setPitch(_ cents: Float) {
        timePitch.pitch = max(-1200, min(cents, 1200))
    }

    func setReverb(mix: Float, preset: AVAudioUnitReverbPreset) {
        reverb.loadFactoryPreset(preset)
        reverb.wetDryMix = max(0, min(mix, 100))
    }
}
