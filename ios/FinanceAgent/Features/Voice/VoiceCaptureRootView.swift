import SwiftUI

struct VoiceCaptureRootView: View {
  @Binding var voiceCaptureRequested: Bool
  @StateObject private var viewModel = VoiceCaptureViewModel()

  var body: some View {
    ZStack {
      backgroundGradient

      VStack(spacing: 0) {
        header
        Spacer(minLength: 24)
        content
        Spacer(minLength: 24)
        footer
      }
      .padding(.horizontal, 28)
      .padding(.vertical, 24)
    }
    .onAppear(perform: startRequestedCaptureIfNeeded)
    .onChange(of: voiceCaptureRequested) { _, _ in
      startRequestedCaptureIfNeeded()
    }
  }

  private var backgroundGradient: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.03, green: 0.09, blue: 0.14), Color(red: 0.02, green: 0.05, blue: 0.08)],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [glowColor.opacity(0.22), .clear],
        center: .bottom,
        startRadius: 10,
        endRadius: 420
      )
      .animation(.easeInOut(duration: 0.6), value: glowColor)
    }
    .ignoresSafeArea()
  }

  private var header: some View {
    HStack {
      Label("Fino", systemImage: "sparkles")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.mint)
      Spacer()
      statusPill
    }
  }

  private var statusPill: some View {
    Text(statusText)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(statusColor.opacity(0.18), in: Capsule())
      .foregroundStyle(statusColor)
      .animation(.easeInOut(duration: 0.25), value: statusText)
  }

  private var content: some View {
    VStack(spacing: 28) {
      VStack(spacing: 12) {
        Text(title)
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .contentTransition(.opacity)

        Text(detail)
          .font(.body)
          .foregroundStyle(.white.opacity(0.65))
          .multilineTextAlignment(.center)
      }

      if !viewModel.transcript.isEmpty {
        transcriptCard
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      if viewModel.state == .listening {
        VoiceWaveformView(level: viewModel.audioLevel)
          .transition(.opacity)
      }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.transcript)
    .animation(.easeInOut(duration: 0.25), value: viewModel.state)
  }

  private var transcriptCard: some View {
    Text(viewModel.transcript)
      .font(.title3.weight(.medium))
      .foregroundStyle(.white)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .strokeBorder(.white.opacity(0.12))
      )
  }

  private var footer: some View {
    VStack(spacing: 16) {
      PulsingMicButton(visualState: micVisualState, action: startCapture)

      Text(buttonHint)
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white.opacity(0.55))
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: buttonHint)

      if showsCancel {
        Button("Cancelar", role: .cancel) {
          viewModel.cancel()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: showsCancel)
  }

  private var micVisualState: MicButtonVisualState {
    switch viewModel.state {
    case .idle, .transcribing:
      return .idle
    case .requestingPermission:
      return .busy
    case .listening:
      return .listening
    case .failure:
      return .failure
    }
  }

  private var title: String {
    switch viewModel.state {
    case .listening: return "Te escucho"
    case .transcribing: return "Perfecto"
    case .failure: return "Intentémoslo de nuevo"
    case .requestingPermission: return "Un momento"
    case .idle: return "Registra un gasto"
    }
  }

  private var detail: String {
    switch viewModel.state {
    case .listening: return "Di qué compraste y cuánto pagaste."
    case .transcribing: return "Ya casi enviamos tu gasto."
    case .requestingPermission: return "Activando el micrófono y el reconocimiento de voz."
    case .idle: return "Por ejemplo: “Gasté cuarenta y cinco mil pesos en Uber”."
    case let .failure(failure): return failure.message
    }
  }

  private var buttonHint: String {
    switch viewModel.state {
    case .listening: return "Escuchando…"
    case .requestingPermission: return "Solicitando permisos…"
    case .transcribing: return "Toca para grabar otro gasto"
    case .failure: return "Toca para intentar de nuevo"
    case .idle: return "Toca para hablar"
    }
  }

  private var statusText: String {
    switch viewModel.state {
    case .idle: return "Lista"
    case .requestingPermission: return "Permisos"
    case .listening: return "Escuchando"
    case .transcribing: return "Procesando"
    case .failure: return "Error"
    }
  }

  private var statusColor: Color {
    switch viewModel.state {
    case .failure: return .red
    case .listening: return .mint
    case .transcribing: return .yellow
    case .requestingPermission, .idle: return .white.opacity(0.6)
    }
  }

  private var glowColor: Color {
    isFailureState ? .red : .mint
  }

  private var isFailureState: Bool {
    if case .failure = viewModel.state { return true }
    return false
  }

  private var showsCancel: Bool {
    viewModel.state == .listening || viewModel.state == .transcribing
  }

  private func startCapture() {
    viewModel.beginCapture()
  }

  private func startRequestedCaptureIfNeeded() {
    guard voiceCaptureRequested else { return }
    voiceCaptureRequested = false
    viewModel.beginCapture()
  }
}
