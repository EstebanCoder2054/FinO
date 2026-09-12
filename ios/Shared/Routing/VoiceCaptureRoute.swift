import Foundation

enum AppGroup {
  static let identifier = "group.com.finoai.financeagent"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: identifier) ?? .standard
  }
}

enum VoiceCaptureRoute {
  static let requestedKey = "voiceCaptureRequested"

  static func requestCapture() {
    AppGroup.defaults.set(true, forKey: requestedKey)
  }
}
