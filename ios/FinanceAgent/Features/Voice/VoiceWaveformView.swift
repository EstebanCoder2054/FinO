import Foundation
import SwiftUI

struct VoiceWaveformView: View {
  var level: CGFloat

  private let barCount = 5

  var body: some View {
    TimelineView(.animation) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      HStack(spacing: 6) {
        ForEach(0..<barCount, id: \.self) { index in
          Capsule()
            .fill(Color.mint)
            .frame(width: 6, height: barHeight(for: index, time: time))
        }
      }
      .frame(height: 48)
    }
  }

  private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
    let phase = Double(index) * 0.6
    let wobble = (sin(time * 6 + phase) + 1) / 2
    let base: CGFloat = 8
    let amplitude: CGFloat = 40 * min(max(level, 0), 1)
    return base + amplitude * CGFloat(wobble)
  }
}
