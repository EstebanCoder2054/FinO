import SwiftData
import SwiftUI

/// Correction sheet for an entry the agent already captured by voice.
/// There is no blank/create path here on purpose — every new entry is
/// meant to come from speaking to Fino, not a manual form.
struct ExpenseFormView: View {
  @Environment(\.dismiss) private var dismiss

  private let expenseToEdit: Expense

  @State private var amountText: String
  @State private var category: String
  @State private var kind: ExpenseKind
  @State private var expenseDescription: String
  @State private var date: Date

  init(expenseToEdit: Expense) {
    self.expenseToEdit = expenseToEdit
    _amountText = State(initialValue: expenseToEdit.amount.map { String($0) } ?? "")
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
          Button("Guardar", action: save)
            .disabled(expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private func save() {
    expenseToEdit.amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
    expenseToEdit.category = category
    expenseToEdit.kind = kind
    expenseToEdit.expenseDescription = expenseDescription
    expenseToEdit.createdAt = date
    dismiss()
  }
}
