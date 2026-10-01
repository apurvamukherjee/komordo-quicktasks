import AVFoundation
import OSLog
import Speech

/// Voice input and voice notes (FEATURES §4.5 and §4.19, ARCHITECTURE §9): the microphone through
/// `SFSpeechRecognizer` with on-device recognition required, so audio never leaves the Mac.
@MainActor @Observable final class SpeechTranscriber {
    enum State: Equatable {
        case idle
        case listening
        case failed(String)
    }

    private(set) var state = State.idle
    /// What's been heard so far.
    private(set) var transcript = ""
    private(set) var startedAt: Date?
    /// Recent input levels from 0 to 1, newest last, for the waveform.
    private(set) var levels: [Double] = Array(repeating: 0, count: 24)

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var simulation: Task<Void, Never>?
    private static let log = Logger(subsystem: "app.komodo.Komodo", category: "voice")

    var isListening: Bool { state == .listening }

    /// Asks for the microphone and speech recognition the first time, then listens until `stop()`.
    func start() async {
        guard state != .listening else { return }
        transcript = ""
        levels = Array(repeating: 0, count: levels.count)
        #if DEBUG
            if let sample = UserDefaults.standard.string(forKey: "voiceSample") {
                simulate(sample)
                return
            }
        #endif
        guard await Self.hasMicrophone(), await Self.hasSpeech() else {
            state = .failed("Allow the microphone and speech recognition for Komodo in System Settings.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(), recognizer.supportsOnDeviceRecognition else {
            state = .failed("On-device dictation isn't available for this Mac's language.")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(
            onBus: 0, bufferSize: 1_024, format: format,
            block: Self.tap(feeding: request) { [weak self] level in Task { @MainActor in self?.push(level) } })
        do {
            engine.prepare()
            try engine.start()
        } catch {
            Self.log.error("Microphone failed to start: \(error)")
            input.removeTap(onBus: 0)
            state = .failed("Komodo couldn't use the microphone.")
            return
        }
        task = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.results { [weak self] text, failed in
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if failed, self.state == .listening { self.finishAudio() }
                }
            })
        startedAt = Date()
        state = .listening
    }

    /// Stops listening and returns everything heard, trimmed.
    @discardableResult
    func stop() -> String {
        simulation?.cancel()
        simulation = nil
        finishAudio()
        state = .idle
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func finishAudio() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
    }

    private func push(_ level: Double) {
        levels.removeFirst()
        levels.append(level)
    }

    /// Built outside the main actor: the tap runs on the audio thread, where a main-actor closure would trap.
    nonisolated private static func tap(
        feeding request: SFSpeechAudioBufferRecognitionRequest, level: @escaping @Sendable (Double) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            level(Self.level(of: buffer))
        }
    }

    /// Built outside the main actor for the same reason: Speech calls back on its own queue.
    nonisolated private static func results(
        _ handle: @escaping @Sendable (String?, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in handle(result?.bestTranscription.formattedString, error != nil && result == nil) }
    }

    nonisolated private static func level(of buffer: AVAudioPCMBuffer) -> Double {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        // Speech sits around 0.01–0.2 RMS; scale it so ordinary talking fills most of the bar.
        return Double(min(1, rms * 8))
    }

    private static func hasMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    private static func hasSpeech() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        default: return false
        }
    }

    #if DEBUG
        /// `-voiceSample "<text>"` speaks the text a word at a time with made-up levels, so the Listening state
        /// can be captured without the microphone or its permission prompt.
        private func simulate(_ sample: String) {
            startedAt = Date()
            state = .listening
            simulation = Task {
                for (index, word) in sample.split(separator: " ").enumerated() {
                    for step in 0..<3 {
                        push(0.25 + 0.6 * abs(sin(Double(index * 3 + step) * 0.9)))
                        try? await Task.sleep(for: .milliseconds(110))
                    }
                    guard !Task.isCancelled else { return }
                    transcript += (transcript.isEmpty ? "" : " ") + word
                }
            }
        }
    #endif
}
