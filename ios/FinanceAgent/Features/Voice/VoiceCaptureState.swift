import Foundation

enum VoiceCaptureState: Equatable {
  case idle
  case requestingPermission
  case listening
  case transcribing
  case submitting
  case success
  case failure(VoiceCaptureFailure)
}

enum VoiceCaptureFailure: Equatable {
  case microphonePermissionDenied
  case speechPermissionDenied
  case recognizerUnavailable
  case recordingFailed
  case noSpeechDetected
  case submissionFailed(detail: String)
}

enum VoiceCaptureEvent {
  case begin
  case microphonePermissionGranted
  case microphonePermissionDenied
  case speechPermissionGranted
  case speechPermissionDenied
  case listeningStarted
  case transcriptFinalized
  case recordingFailed
  case noSpeechDetected
  case submissionStarted
  case submissionSucceeded
  case submissionFailed(detail: String)
}

enum VoiceCaptureReducer {
  static func reduce(_ state: VoiceCaptureState, event: VoiceCaptureEvent) -> VoiceCaptureState {
    switch event {
    case .begin:
      return .requestingPermission
    case .microphonePermissionGranted, .speechPermissionGranted:
      return state
    case .microphonePermissionDenied:
      return .failure(.microphonePermissionDenied)
    case .speechPermissionDenied:
      return .failure(.speechPermissionDenied)
    case .listeningStarted:
      return .listening
    case .transcriptFinalized:
      return .transcribing
    case .recordingFailed:
      return .failure(.recordingFailed)
    case .noSpeechDetected:
      return .failure(.noSpeechDetected)
    case .submissionStarted:
      return .submitting
    case .submissionSucceeded:
      return .success
    case .submissionFailed(let detail):
      return .failure(.submissionFailed(detail: detail))
    }
  }
}

extension VoiceCaptureFailure {
  var message: String {
    switch self {
    case .microphonePermissionDenied:
      return "Activa el acceso al micrófono para registrar un gasto por voz."
    case .speechPermissionDenied:
      return "Activa el reconocimiento de voz para transcribir el gasto."
    case .recognizerUnavailable:
      return "El reconocimiento de voz no está disponible en este momento."
    case .recordingFailed:
      return "No se pudo iniciar la grabación. Inténtalo otra vez."
    case .noSpeechDetected:
      return "No detecté un gasto. Inténtalo diciendo el monto y la compra."
    case .submissionFailed:
      return "No se pudo enviar el gasto. Inténtalo otra vez."
    }
  }

  /// The underlying API/network error behind a submission failure — kept out
  /// of `message` (which stays friendly for the main screen) and shown only
  /// when the user taps the status pill to see what actually went wrong.
  var detail: String? {
    if case .submissionFailed(let detail) = self { return detail }
    return nil
  }
}
