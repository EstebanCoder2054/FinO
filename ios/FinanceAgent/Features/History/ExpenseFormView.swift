import SwiftData
import SwiftUI

/// Correction sheet for an entry the agent already captured by voice.
/// There is no blank/create path here on purpose — every new entry is
/// meant to come from speaking to Fino, not a manual form.
struct ExpenseFormView: View {
  @Environment(\.dismiss) private var dismiss

  private let expenseToEdit: Expense
  private let apiClient = ExpenseAPIClient.shared

  @State private var amountText: String
  @State private var currency: String
  @State private var category: String
  @State private var kind: ExpenseKind
  @State private var expenseDescription: String
  @State private var date: Date
  @State private var isSaving = false
  @State private var syncErrorMessage: String?

  /// Matches the backend's `supportedCurrencies` enum exactly — sending
  /// anything else fails PATCH validation, so the picker can't offer it.
  static let supportedCurrencies = ["COP", "USD", "EUR"]

  init(expenseToEdit: Expense) {
    self.expenseToEdit = expenseToEdit
    _amountText = State(initialValue: expenseToEdit.amount.map { String($0) } ?? "")
    _currency = State(
      initialValue: Self.supportedCurrencies.contains(expenseToEdit.currency)
        ? expenseToEdit.currency
        : Self.supportedCurrencies[0]
    )
    _category = State(initialValue: expenseToEdit.category)
    _kind = State(initialValue: expenseToEdit.kind)
    _expenseDescription = State(initialValue: expenseToEdit.expenseDescription)
    _date = State(initialValue: expenseToEdit.createdAt)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Tipo") {
          Picker("Tipo", selection: $kind) {
            ForEach(ExpenseKind.allCases, id: \.self) { kind in
              Text(kind.label).tag(kind)
            }
          }
          .pickerStyle(.segmented)
        }

        Section("Monto") {
          TextField("Monto", text: $amountText)
            .keyboardType(.decimalPad)
          Picker("Moneda", selection: $currency) {
            ForEach(ExpenseFormView.supportedCurrencies, id: \.self) { Text($0) }
          }
        }

        Section("Detalle") {
          TextField("Descripción", text: $expenseDescription)

          Picker("Categoría", selection: $category) {
            ForEach(Expense.categories, id: \.self) { Text($0) }
          }

          DatePicker("Fecha", selection: $date, displayedComponents: [.date, .hourAndMinute])
        }
      }
      .navigationTitle("Editar \(kind == .income ? "ingreso" : "gasto")")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          if isSaving {
            ProgressView()
          } else {
            Button("Guardar", action: save)
              .disabled(expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
    .alert(
      "No se pudo sincronizar",
      isPresented: Binding(
        get: { syncErrorMessage != nil },
        set: { isPresented in if !isPresented { syncErrorMessage = nil } }
      ),
      presenting: syncErrorMessage
    ) { _ in
      Button("Entendido", role: .cancel) { dismiss() }
    } message: { message in
      Text("El cambio quedó guardado en el teléfono, pero no se pudo enviar al servidor: \(message)")
    }
  }

  private func save() {
    let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
    isSaving = true

    Task {
      defer { isSaving = false }

      // The backend has no concept of "kind" (income vs. expense) — it's a
      // client-only distinction layered on top of the same expense rows —
      // so kind/date changes stay local while amount/category/description
      // sync back to the row that was captured by voice.
      var failureMessage: String?
      do {
        _ = try await apiClient.updateExpense(
          id: expenseToEdit.id,
          amount: amount,
          currency: currency,
          category: category,
          description: expenseDescription
        )
      } catch ExpenseAPIError.serverMessage(let message) {
        failureMessage = message
      } catch {
        failureMessage = "Sin conexión con el servidor."
      }

      // Applied locally either way: the app stays offline-first, and a
      // failed sync just means the next list refresh may overwrite this
      // edit with the still-stale server value (see catch above).
      expenseToEdit.amount = amount
      expenseToEdit.currency = currency
      expenseToEdit.category = category
      expenseToEdit.kind = kind
      expenseToEdit.expenseDescription = expenseDescription
      expenseToEdit.createdAt = date

      if let failureMessage {
        syncErrorMessage = failureMessage
      } else {
        dismiss()
      }
    }
  }
}
