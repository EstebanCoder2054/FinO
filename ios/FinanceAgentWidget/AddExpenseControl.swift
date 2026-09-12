import AppIntents
import SwiftUI
import WidgetKit

struct AddExpenseControl: ControlWidget {
  static let kind = "com.finoai.financeagent.add-expense"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind) {
      ControlWidgetButton(action: StartExpenseCaptureIntent()) {
        Label("Registrar gasto", systemImage: "mic.fill")
      }
    }
    .displayName("Registrar gasto")
    .description("Abre Fino para registrar un gasto por voz.")
  }
}
