import AppIntents

enum ExpenseCaptureTarget: String, AppEnum {
  case voice

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Captura de gasto")
  static let caseDisplayRepresentations: [ExpenseCaptureTarget: DisplayRepresentation] = [
    .voice: "Registrar gasto"
  ]
}

struct StartExpenseCaptureIntent: OpenIntent {
  static let title: LocalizedStringResource = "Registrar gasto"
  static let description = IntentDescription("Abre Fino para registrar un gasto por voz.")
  static let openAppWhenRun = true

  @Parameter(title: "Destino")
  var target: ExpenseCaptureTarget

  init() {
    target = .voice
  }

  func perform() async throws -> some IntentResult {
    VoiceCaptureRoute.requestCapture()
    return .result()
  }
}
