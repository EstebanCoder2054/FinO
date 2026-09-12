import SwiftData
import SwiftUI

struct VoiceCaptureRootView: View {
  @Binding var voiceCaptureRequested: Bool
  @StateObject private var viewModel = VoiceCaptureViewModel()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var showErrorDetail = false

  var body: some View {
    NavigationStack {
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
      .navigationBarHidden(true)
    }
    .onAppear {
      viewModel.onExpenseCaptured = { capturedExpense in
        modelContext.insert(
          Expense(
            id: capturedExpense.id,
            amount: capturedExpense.amount,
            currency: capturedExpense.currency,
            category: capturedExpense.category,
            kind: capturedExpense.kind,
            expenseDescription: capturedExpense.description,
            createdAt: capturedExpense.createdAt,
            source: capturedExpense.source
          )
        )
      }
      startRequestedCaptureIfNeeded()
    }
    .onChange(of: voiceCaptureRequested) { _, _ in
      startRequestedCaptureIfNeeded()
    }
    .onChange(of: viewModel.state) { oldValue, newValue in
      if case .success = oldValue, newValue == .idle {
        dismiss()
      }
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
    HStack(spacing: 12) {
      Label("Fino", systemImage: "sparkles")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.mint)
      Spacer()
      statusPill
      Button {
        viewModel.cancel()
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.85))
          .padding(8)
          .background(.white.opacity(0.1), in: Circle())
      }
    }
  }

  private var statusPill: some View {
    let pill = Text(statusText)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(statusColor.opacity(0.18), in: Capsule())
      .foregroundStyle(statusColor)
      .animation(.easeInOut(duration: 0.25), value: statusText)

    return Group {
      if let failureDetail {
        Button {
          showErrorDetail = true
        } label: {
          pill
        }
        .alert("Detalle del error", isPresented: $showErrorDetail) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(failureDetail)
        }
      } else {
        pill
      }
    }
  }

  /// The technical error behind a failed submission — the "Error" pill is
  /// only tappable when this is non-nil, since other failures (permissions,
  /// no speech) already say everything relevant in the main copy.
  private var failureDetail: String? {
    if case .failure(let failure) = viewModel.state { return failure.detail }
    return nil
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

      if case .success = viewModel.state, let saved = viewModel.lastSavedExpense {
        successCard(saved)
          .transition(.scale.combined(with: .opacity))
      } else if !viewModel.transcript.isEmpty {
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

  private func successCard(_ expense: CapturedExpense) -> some View {
    VStack(spacing: 10) {
      Text("✅")
        .font(.system(size: 44))
      Text(expense.description)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white.opacity(0.85))
        .multilineTextAlignment(.center)
        .lineLimit(1)
      if let amount = expense.amount {
        Text(amount, format: .currency(code: expense.currency).precision(.fractionLength(0)))
          .font(.title3.weight(.bold))
          .foregroundStyle(.mint)
      }
    }
    .padding(20)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.white.opacity(0.12))
    )
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

      if isSubmissionFailure {
        Button("Volver a intentar") {
          viewModel.retrySubmit()
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.mint)
        .transition(.opacity)
      }

      if showsCancel {
        Button("Cancelar", role: .cancel) {
          viewModel.cancel()
          dismiss()
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
    case .requestingPermission, .submitting:
      return .busy
    case .listening:
      return .listening
    case .success:
      return .success
    case .failure:
      return .failure
    }
  }

  private var isSavedIncome: Bool {
    viewModel.lastSavedExpense?.kind == .income
  }

  private var title: String {
    switch viewModel.state {
    case .listening: return "Te escucho"
    case .transcribing: return "Perfecto"
    case .submitting: return "Enviando…"
    case .success: return isSavedIncome ? "¡Ingreso registrado!" : "¡Gasto registrado!"
    case .failure: return "Intentémoslo de nuevo"
    case .requestingPermission: return "Un momento"
    case .idle: return "Registra un gasto o ingreso"
    }
  }

  private var detail: String {
    switch viewModel.state {
    case .listening: return "Di qué compraste y cuánto pagaste, o cuánto te pagaron."
    case .transcribing: return "Ya casi enviamos tu movimiento."
    case .submitting: return "Estamos guardando tu movimiento, espera un momento."
    case .success:
      return isSavedIncome
        ? "Tu ingreso quedó registrado correctamente ✅."
        : "Tu gasto quedó registrado correctamente ✅."
    case .requestingPermission: return "Activando el micrófono y el reconocimiento de voz."
    case .idle: return "Por ejemplo: “Gasté cuarenta y cinco mil pesos en Uber” o “Me pagaron 200 mil pesos”."
    case let .failure(failure): return failure.message
    }
  }

  private var buttonHint: String {
    switch viewModel.state {
    case .listening: return "Toca para enviar"
    case .requestingPermission: return "Solicitando permisos…"
    case .transcribing: return "Toca para grabar otro gasto"
    case .submitting: return "Enviando…"
    case .success: return "¡Listo!"
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
    case .submitting: return "Enviando"
    case .success: return "Guardado"
    case .failure: return "Error"
    }
  }

  private var statusColor: Color {
    switch viewModel.state {
    case .failure: return .red
    case .listening: return .mint
    case .success: return .green
    case .transcribing, .submitting: return .yellow
    case .requestingPermission, .idle: return .white.opacity(0.6)
    }
  }

  private var isSubmissionFailure: Bool {
    if case .failure(.submissionFailed) = viewModel.state { return true }
    return false
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
    if viewModel.state == .listening {
      viewModel.finishCapture()
    } else {
      viewModel.beginCapture()
    }
  }

  private func startRequestedCaptureIfNeeded() {
    guard voiceCaptureRequested else { return }
    voiceCaptureRequested = false
    viewModel.beginCapture()
  }
}
