import AVFoundation
import SoundAnalysis
import Combine

/// Listens to the microphone, classifies ~1 s windows with Apple's built-in
/// sound classifier (which has a "snoring" class), and writes snoring episodes
/// to .m4a files in Documents/Recordings.
///
/// Recording runs in the background thanks to the `audio` UIBackgroundMode
/// (iOS's equivalent of an Android foreground service).
final class SnoreMonitor: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var currentConfidence: Double = 0
    @Published private(set) var isRecordingClip = false
    @Published var errorMessage: String?

    /// Called on the main thread after a clip has been finalized.
    var onClipSaved: (() -> Void)?

    // MARK: Tuning
    let threshold: Double = 0.5
    private let windowSeconds: Double = 1.0
    private let preRollSeconds: Double = 2.0   // audio kept before the first detection
    private let hangoverSeconds: Double = 2.0  // keep recording after the last detection
    private let maxClipSeconds: Double = 120   // split very long episodes

    // MARK: Audio
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private let queue = DispatchQueue(label: "snore.analysis")
    private var sampleRate: Double = 48_000
    private var inputFormat: AVAudioFormat?

    // MARK: State (only touched on `queue`)
    private var framePosition: AVAudioFramePosition = 0
    private var preRoll: [AVAudioPCMBuffer] = []
    private var preRollFrames: AVAudioFramePosition = 0
    private var clipFile: AVAudioFile?
    private var clipURL: URL?
    private var clipStart = Date()
    private var clipFrames: AVAudioFramePosition = 0
    private var lastSnoreFrame: AVAudioFramePosition = 0
    private var clipPeak: Double = 0

    private var wantsToRun = false

    override init() {
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleConfigChange(_:)),
                       name: .AVAudioEngineConfigurationChange, object: engine)
    }

    // MARK: Public API

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.wantsToRun = true
                    self.startEngine()
                } else {
                    self.errorMessage = "Pristup mikrofonu je odbijen. Uključi ga u Postavke → Privatnost → Mikrofon."
                }
            }
        }
    }

    func stop() {
        wantsToRun = false
        stopEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Engine

    private func startEngine() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "SnoreMonitor", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Mikrofon nije dostupan."])
            }
            sampleRate = format.sampleRate
            inputFormat = format

            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = Self.closestWindow(to: windowSeconds, in: request.windowDurationConstraint)
            request.overlapFactor = 0

            let analyzer = SNAudioStreamAnalyzer(format: format)
            try analyzer.add(request, withObserver: self)

            queue.sync {
                self.analyzer = analyzer
                self.framePosition = 0
                self.preRoll.removeAll()
                self.preRollFrames = 0
            }

            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let self, let copy = Self.copy(buffer) else { return }
                self.queue.async { self.process(copy) }
            }
            engine.prepare()
            try engine.start()
            isRunning = true
            errorMessage = nil
        } catch {
            errorMessage = "Ne mogu pokrenuti snimanje: \(error.localizedDescription)"
            stopEngine()
        }
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        queue.async {
            self.analyzer?.completeAnalysis()
            self.analyzer = nil
            self.finishClip()
        }
        isRunning = false
        currentConfidence = 0
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        DispatchQueue.main.async {
            switch type {
            case .began:
                self.stopEngine()
            case .ended:
                if self.wantsToRun { self.startEngine() }
            @unknown default: break
            }
        }
    }

    @objc private func handleConfigChange(_ note: Notification) {
        // Route changed (e.g. headphones plugged in) – restart with the new format.
        DispatchQueue.main.async {
            guard self.wantsToRun else { return }
            self.stopEngine()
            self.startEngine()
        }
    }

    // MARK: Processing (on `queue`)

    private func process(_ buffer: AVAudioPCMBuffer) {
        analyzer?.analyze(buffer, atAudioFramePosition: framePosition)
        framePosition += AVAudioFramePosition(buffer.frameLength)

        if let file = clipFile {
            do { try file.write(from: buffer) } catch { finishClip(); return }
            clipFrames += AVAudioFramePosition(buffer.frameLength)

            let silentFor = Double(framePosition - lastSnoreFrame) / sampleRate
            let length = Double(clipFrames) / sampleRate
            if silentFor > hangoverSeconds || length > maxClipSeconds {
                finishClip()
            }
        } else {
            preRoll.append(buffer)
            preRollFrames += AVAudioFramePosition(buffer.frameLength)
            let maxFrames = AVAudioFramePosition(preRollSeconds * sampleRate)
            while preRollFrames > maxFrames, let first = preRoll.first {
                preRollFrames -= AVAudioFramePosition(first.frameLength)
                preRoll.removeFirst()
            }
        }
    }

    private func handle(confidence: Double) {
        guard confidence >= threshold else { return }
        lastSnoreFrame = framePosition
        clipPeak = max(clipPeak, confidence)
        if clipFile == nil { startClip() }
    }

    private func startClip() {
        guard let format = preRoll.first?.format ?? inputFormat else { return }
        let start = Date().addingTimeInterval(-Double(preRollFrames) / sampleRate)
        let url = RecordingStore.directory.appendingPathComponent(RecordingStore.fileName(for: start))
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings,
                                       commonFormat: format.commonFormat,
                                       interleaved: format.isInterleaved)
            clipFrames = 0
            for b in preRoll {
                try file.write(from: b)
                clipFrames += AVAudioFramePosition(b.frameLength)
            }
            preRoll.removeAll()
            preRollFrames = 0
            clipFile = file
            clipURL = url
            clipStart = start
            DispatchQueue.main.async { self.isRecordingClip = true }
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Greška pri spremanju: \(error.localizedDescription)" }
        }
    }

    private func finishClip() {
        guard clipFile != nil, let url = clipURL else { return }
        clipFile = nil // releasing the AVAudioFile finalizes the m4a
        let meta = RecordingMeta(start: clipStart,
                                 duration: Double(clipFrames) / sampleRate,
                                 peakConfidence: clipPeak)
        RecordingStore.writeMeta(meta, for: url)
        clipURL = nil
        clipPeak = 0
        clipFrames = 0
        DispatchQueue.main.async {
            self.isRecordingClip = false
            self.onClipSaved?()
        }
    }

    // MARK: Helpers

    private static func copy(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let dst = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: src.frameLength) else { return nil }
        dst.frameLength = src.frameLength
        let srcList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: src.audioBufferList))
        let dstList = UnsafeMutableAudioBufferListPointer(dst.mutableAudioBufferList)
        for (s, d) in zip(srcList, dstList) {
            guard let sp = s.mData, let dp = d.mData else { continue }
            memcpy(dp, sp, Int(min(s.mDataByteSize, d.mDataByteSize)))
        }
        return dst
    }

    private static func closestWindow(to seconds: Double, in constraint: SNTimeDurationConstraint) -> CMTime {
        let target = CMTime(seconds: seconds, preferredTimescale: 48_000)
        switch constraint {
        case .enumeratedDurations(let options):
            var best = target
            var bestDiff = Double.greatestFiniteMagnitude
            for option in options {
                let diff = abs(option.seconds - seconds)
                if diff < bestDiff { bestDiff = diff; best = option }
            }
            return best
        case .durationRange(let range):
            return CMTimeClampToRange(target, range: range)
        @unknown default:
            return target
        }
    }
}

extension SnoreMonitor: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let confidence = result.classification(forIdentifier: "snoring")?.confidence ?? 0
        queue.async { self.handle(confidence: confidence) }
        DispatchQueue.main.async { self.currentConfidence = confidence }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { self.errorMessage = "Klasifikacija nije uspjela: \(error.localizedDescription)" }
    }
}
