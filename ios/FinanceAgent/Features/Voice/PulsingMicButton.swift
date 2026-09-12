import SwiftUI

enum MicButtonVisualState: Equatable {
  case idle
  case busy
  case listening
  case success
  case failure
}

struct PulsingMicButton: View {
  var visualState: MicButtonVisualState
  var action: () -> Void

  @State private var ringsExpanded = false

  var body: some View {
    Button(action: action) {
      ZStack {
        ForEach(0..<2, id: \.self) { index in
          Circle()
            .stroke(ringColor.opacity(0.4), lineWidth: 2)
            .frame(width: 96, height: 96)
            .scaleEffect(ringsExpanded ? 1.9 : 1)
            .opacity(ringsExpanded ? 0 : (visualState == .listening ? 0.7 : 0))
            .animation(
              .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(index) * 0.6),
              value: ringsExpanded
            )
        }

        Circle()
          .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
          .frame(width: 96, height: 96)
          .shadow(color: (gradientColors.first ?? .mint).opacity(0.35), radius: 18, y: 10)

        if visualState == .busy {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: iconName)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(iconColor)
            .contentTransition(.symbolEffect(.replace))
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(visualState == .busy)
    .animation(.easeInOut(duration: 0.3), value: visualState)
    .onChange(of: visualState == .listening) { _, isListening in
      ringsExpanded = isListening
    }
    .onAppear {
      ringsExpanded = visualState == .listening
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: visualState == .listening)
    .sensoryFeedback(.success, trigger: visualState == .success)
    .sensoryFeedback(.error, trigger: visualState == .failure)
  }

  private var ringColor: Color {
    visualState == .failure ? .red : .mint
  }

  private var gradientColors: [Color] {
    switch visualState {
    case .listening: return [.mint, .teal]
    case .success: return [.green, .mint]
    case .failure: return [.orange, .red]
    case .busy: return [Color.white.opacity(0.25), Color.white.opacity(0.1)]
    case .idle: return [.mint, .mint.opacity(0.75)]
    }
  }

  private var iconName: String {
    switch visualState {
    case .listening: return "waveform"
    case .success: return "checkmark"
    case .failure: return "exclamationmark.triangle.fill"
    case .busy, .idle: return "mic.fill"
    }
  }

  private var iconColor: Color {
    visualState == .busy ? .white.opacity(0.7) : .black
  }
}
