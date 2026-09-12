import SwiftData
import SwiftUI

@main
struct FinanceAgentApp: App {
  @AppStorage(VoiceCaptureRoute.requestedKey, store: AppGroup.defaults)
  private var voiceCaptureRequested = false

  var body: some Scene {
    WindowGroup {
      VoiceCaptureRootView(voiceCaptureRequested: $voiceCaptureRequested)
    }
    .modelContainer(for: Expense.self)
  }
}
