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

  func testSubmissionStartedTransitionsToSubmitting() {
    XCTAssertEqual(
      VoiceCaptureReducer.reduce(.transcribing, event: .submissionStarted),
      .submitting
    )
  }

  func testSubmissionFailedFailsWithRetryGuidance() {
    XCTAssertEqual(
      VoiceCaptureReducer.reduce(.submitting, event: .submissionFailed),
      .failure(.submissionFailed)
    )
  }
}
