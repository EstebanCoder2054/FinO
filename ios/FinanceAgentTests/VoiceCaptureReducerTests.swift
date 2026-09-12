import XCTest
@testable import FinanceAgent

final class VoiceCaptureReducerTests: XCTestCase {
  func testBeginRequestsPermission() {
    XCTAssertEqual(
      VoiceCaptureReducer.reduce(.idle, event: .begin),
      .requestingPermission
    )
  }

  func testDeniedMicrophoneFailsWithGuidance() {
    XCTAssertEqual(
      VoiceCaptureReducer.reduce(.requestingPermission, event: .microphonePermissionDenied),
      .failure(.microphonePermissionDenied)
    )
  }

  func testListeningTransitionsToTranscribingAfterFinalTranscript() {
    XCTAssertEqual(
      VoiceCaptureReducer.reduce(.listening, event: .transcriptFinalized),
      .transcribing
    )
  }
}
