import SwiftData
import SwiftUI

@main
struct FinanceAgentApp: App {
  @AppStorage(VoiceCaptureRoute.requestedKey, store: AppGroup.defaults)
  private var voiceCaptureRequested = false

  var body: some Scene {
    WindowGroup {
      AppRootView(voiceCaptureRequested: $voiceCaptureRequested)
    }
    .modelContainer(for: Expense.self)
  }
}

/// Dashboard-first shell: the analytics/history screen is the landing
/// screen, and voice capture opens as a full-screen cover — either from its
/// own mic button, or from the widget/Control Center intent, both of which
/// flip `voiceCaptureRequested` (the same AppStorage flag VoiceCaptureRootView
/// already watches to auto-start listening once presented).
private struct AppRootView: View {
  @Binding var voiceCaptureRequested: Bool
  @State private var isCapturing = false

  var body: some View {
    NavigationStack {
      HistoryView(voiceCaptureRequested: $voiceCaptureRequested)
    }
    .fullScreenCover(isPresented: $isCapturing) {
      VoiceCaptureRootView(voiceCaptureRequested: $voiceCaptureRequested)
    }
    .onChange(of: voiceCaptureRequested) { _, requested in
      if requested { isCapturing = true }
    }
    .onAppear {
      if voiceCaptureRequested { isCapturing = true }
    }
  }
}
