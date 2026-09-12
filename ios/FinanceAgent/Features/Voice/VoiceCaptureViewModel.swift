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

  private let audioEngine = AVAudioEngine()
  private let speechRecognizer = VoiceCaptureViewModel.makeSpeechRecognizer()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?

  func beginCapture() {
    stopListening()
    transcript = ""
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
    state = .idle
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
    recognitionRequest = request

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)

      let inputNode = audioEngine.inputNode
      inputNode.removeTap(onBus: 0)
      let format = inputNode.outputFormat(forBus: 0)

      Self.installTap(
        on: inputNode,
        bufferSize: 1_024,
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
            self.state = VoiceCaptureReducer.reduce(self.state, event: .transcriptFinalized)
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
    SFSpeechRecognizer(locale: Locale(identifier: "es_CO"))
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
