import Foundation
import SwiftData

enum ExpenseKind: String, Codable, CaseIterable {
  case expense
  case income

  var label: String {
    switch self {
    case .expense: return "Gasto"
    case .income: return "Ingreso"
    }
  }

  var systemImage: String {
    switch self {
    case .expense: return "arrow.up.right.circle.fill"
    case .income: return "arrow.down.left.circle.fill"
    }
  }

  /// +1 for income, -1 for expense, so `amount * signedMultiplier` sums into a balance.
  var signedMultiplier: Double {
    self == .income ? 1 : -1
  }
}

@Model
final class Expense: Identifiable {
  var id: UUID
  var amount: Double?
  var currency: String
  var category: String
  var kind: ExpenseKind = ExpenseKind.expense
  var expenseDescription: String
  var createdAt: Date
  var source: String

  init(
    id: UUID = UUID(),
    amount: Double? = nil,
    currency: String = "COP",
    category: String = Expense.categories[0],
    kind: ExpenseKind = .expense,
    expenseDescription: String,
    createdAt: Date = .now,
    source: String = "manual"
  ) {
    self.id = id
    self.amount = amount
    self.currency = currency
    self.category = category
    self.kind = kind
    self.expenseDescription = expenseDescription
    self.createdAt = createdAt
    self.source = source
  }

  convenience init(_ capturedExpense: CapturedExpense) {
    self.init(
      id: capturedExpense.id,
      amount: capturedExpense.amount,
      currency: capturedExpense.currency,
      category: capturedExpense.category,
      kind: .expense,
      expenseDescription: capturedExpense.description,
      createdAt: capturedExpense.createdAt,
      source: capturedExpense.source
    )
  }
}

extension Expense {
  static let categories = [
    "Comida", "Transporte", "Hogar", "Entretenimiento", "Compras", "Salud",
    "Sueldo", "Préstamo", "Arriendo", "Otros"
  ]
}
