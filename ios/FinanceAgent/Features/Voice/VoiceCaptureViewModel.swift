import AVFAudio
import Speech
import SwiftUI
import os

private let voiceCaptureLog = Logger(subsystem: "com.finoai.FinanceAgent", category: "VoiceCapture")

@MainActor
final class VoiceCaptureViewModel: NSObject, ObservableObject {
  @Published private(set) var state: VoiceCaptureState = .idle
  @Published private(set) var transcript = ""
  @Published private(set) var audioLevel: CGFloat = 0
  @Published private(set) var lastSavedExpense: CapturedExpense?

  /// Invoked with the finalized transcript once a submission succeeds, so the
  /// view layer can persist it (e.g. to SwiftData) without this view model
  /// knowing about storage.
  var onExpenseCaptured: ((CapturedExpense) -> Void)?

  private var audioEngine = AVAudioEngine()
  private let speechRecognizer = VoiceCaptureViewModel.makeSpeechRecognizer()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let apiClient = ExpenseAPIClient.shared

  func beginCapture() {
    stopListening()
    transcript = ""
    lastSavedExpense = nil
    state = VoiceCaptureReducer.reduce(state, event: .begin)

    Task {
      guard await Self.requestMicrophonePermission() else {
        state = VoiceCaptureReducer.reduce(state, event: .microphonePermissionDenied)
        return
      }
      let authStatus = await Self.requestSpeechAuthorization()
      voiceCaptureLog.notice("speech authorizationStatus=\(String(describing: authStatus), privacy: .public)")
      guard authStatus == .authorized else {
        state = VoiceCaptureReducer.reduce(state, event: .speechPermissionDenied)
        return
      }
      startListening()
    }
  }

  func stopListening() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    audioLevel = 0
  }

  func cancel() {
    stopListening()
    transcript = ""
    lastSavedExpense = nil
    state = .idle
  }

  func finishCapture() {
    guard state == .listening else { return }
    stopListening()
    if transcript.isEmpty {
      state = VoiceCaptureReducer.reduce(state, event: .noSpeechDetected)
    } else {
      state = VoiceCaptureReducer.reduce(state, event: .transcriptFinalized)
      submit()
    }
  }

  func retrySubmit() {
    guard case .failure(.submissionFailed) = state else { return }
    submit()
  }

  private func submit() {
    state = VoiceCaptureReducer.reduce(state, event: .submissionStarted)
    let text = transcript
    Task {
      do {
        let expense = try await apiClient.createExpense(from: text)
        guard transcript == text else { return }
        onExpenseCaptured?(expense)
        lastSavedExpense = expense
        transcript = ""
        state = VoiceCaptureReducer.reduce(state, event: .submissionSucceeded)

        // Hold the success screen briefly so the ✅ confirmation is actually
        // seen, then return to idle on its own (the view dismisses on that
        // success -> idle transition).
        try? await Task.sleep(for: .seconds(1.4))
        guard state == .success else { return }
        lastSavedExpense = nil
        state = .idle
      } catch {
        voiceCaptureLog.error("expense submission failed: \(String(describing: error), privacy: .public)")
        guard transcript == text else { return }
        state = VoiceCaptureReducer.reduce(state, event: .submissionFailed(detail: Self.errorDetail(for: error)))
      }
    }
  }

  private static func errorDetail(for error: Error) -> String {
    switch error {
    case ExpenseAPIError.serverMessage(let message):
      return message
    case ExpenseAPIError.invalidResponse:
      return "El servidor devolvió una respuesta inválida."
    default:
      return (error as NSError).localizedDescription
    }
  }

  private func startListening() {
    let supportedCount = SFSpeechRecognizer.supportedLocales().count
    let recognizer = speechRecognizer
    voiceCaptureLog.notice(
      "startListening: recognizerIsNil=\(recognizer == nil, privacy: .public) isAvailable=\(recognizer?.isAvailable ?? false, privacy: .public) locale=\(recognizer?.locale.identifier ?? "nil", privacy: .public) supportedLocales=\(supportedCount, privacy: .public)"
    )
    guard let speechRecognizer, speechRecognizer.isAvailable else {
      state = .failure(.recognizerUnavailable)
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    // .dictation avoids the short-phrase/search bias that clips trailing
    // syllables (e.g. "gasto" -> "gas") on longer freeform sentences.
    request.taskHint = .dictation
    recognitionRequest = request

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)

      // Fresh engine per capture: reusing one instance across sessions can leave
      // the input node reporting a stale (0 Hz / 0 channel) format after a route
      // change (e.g. Bluetooth), which crashes `installTap` with an uncatchable
      // Obj-C exception rather than a Swift error.
      audioEngine = AVAudioEngine()
      let inputNode = audioEngine.inputNode
      let format = inputNode.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        voiceCaptureLog.error(
          "invalid input format sampleRate=\(format.sampleRate, privacy: .public) channels=\(format.channelCount, privacy: .public)"
        )
        state = VoiceCaptureReducer.reduce(state, event: .recordingFailed)
        return
      }

      Self.installTap(
        on: inputNode,
        bufferSize: 4_096,
        format: format,
        request: request
      ) { [weak self] level in
        Task { @MainActor in
          self?.audioLevel = level
        }
      }

      audioEngine.prepare()
      try audioEngine.start()
      state = VoiceCaptureReducer.reduce(state, event: .listeningStarted)

      recognitionTask = Self.startRecognitionTask(
        recognizer: speechRecognizer,
        request: request
      ) { [weak self] update in
        Task { @MainActor in
          guard let self else { return }
          switch update {
          case .partial(let text):
            self.transcript = text
          case .final(let text):
            self.transcript = text
            self.stopListening()
            if text.isEmpty {
              self.state = VoiceCaptureReducer.reduce(self.state, event: .noSpeechDetected)
            } else {
              self.state = VoiceCaptureReducer.reduce(self.state, event: .transcriptFinalized)
              self.submit()
            }
          case .failed:
            if self.transcript.isEmpty {
              self.stopListening()
              self.state = VoiceCaptureReducer.reduce(self.state, event: .noSpeechDetected)
            }
          }
        }
      }
    } catch {
      state = VoiceCaptureReducer.reduce(state, event: .recordingFailed)
    }
  }
}

// MARK: - Nonisolated bridging

// These callbacks are invoked by AVFoundation/Speech/TCC on arbitrary background
// (audio, XPC) threads, never guaranteed to be main. Forming the closures here,
// in a `nonisolated static` context, keeps them from inheriting @MainActor
// isolation from the surrounding type — that inference is what previously made
// the runtime assert the calling thread was main and trap when it wasn't.
extension VoiceCaptureViewModel {
  private static func makeSpeechRecognizer() -> SFSpeechRecognizer? {
    SFSpeechRecognizer(locale: Locale(identifier: "es-419"))
      ?? SFSpeechRecognizer(locale: Locale(identifier: "es_CO"))
      ?? SFSpeechRecognizer(locale: Locale(identifier: "es_MX"))
      ?? SFSpeechRecognizer()
  }

  fileprivate nonisolated static func requestMicrophonePermission() async -> Bool {
    await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  fileprivate nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
  }

  fileprivate nonisolated static func installTap(
    on node: AVAudioInputNode,
    bufferSize: AVAudioFrameCount,
    format: AVAudioFormat?,
    request: SFSpeechAudioBufferRecognitionRequest,
    onLevel: @escaping @Sendable (CGFloat) -> Void
  ) {
    node.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
      request.append(buffer)
      onLevel(Self.audioLevel(from: buffer))
    }
  }

  private nonisolated static func audioLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
    guard let channelData = buffer.floatChannelData?[0] else { return 0 }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return 0 }

    var sum: Float = 0
    for index in 0..<frameLength {
      sum += channelData[index] * channelData[index]
    }
    let rms = sqrt(sum / Float(frameLength))
    return min(max(CGFloat(rms) * 20, 0), 1)
  }

  fileprivate enum RecognitionUpdate {
    case partial(String)
    case final(String)
    case failed
  }

  fileprivate nonisolated static func startRecognitionTask(
    recognizer: SFSpeechRecognizer,
    request: SFSpeechAudioBufferRecognitionRequest,
    onUpdate: @escaping @Sendable (RecognitionUpdate) -> Void
  ) -> SFSpeechRecognitionTask {
    recognizer.recognitionTask(with: request) { result, error in
      if let result {
        let text = result.bestTranscription.formattedString
        onUpdate(result.isFinal ? .final(text) : .partial(text))
      } else if error != nil {
        onUpdate(.failed)
      }
    }
  }
}
