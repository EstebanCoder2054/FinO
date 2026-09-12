import SwiftUI

/// Fixed categorical + status colors (validated for CVD-safety as adjacent
/// marks — see dataviz palette). Order must stay fixed, never cycled.
enum ExpenseStyle {
  static let categoryOrder = Expense.categories

  private static let categoryColors: [String: Color] = [
    "Comida": Color(hex: "3987e5"),
    "Transporte": Color(hex: "d95926"),
    "Hogar": Color(hex: "199e70"),
    "Entretenimiento": Color(hex: "c98500"),
    "Compras": Color(hex: "c026d3"),
    "Salud": Color(hex: "d55181"),
    "Sueldo": Color(hex: "0ea5a5"),
    "Préstamo": Color(hex: "7c5cbf"),
    "Arriendo": Color(hex: "a1662f"),
    "Otros": Color(hex: "008300")
  ]

  private static let categoryIcons: [String: String] = [
    "Comida": "fork.knife",
    "Transporte": "car.fill",
    "Hogar": "house.fill",
    "Entretenimiento": "gamecontroller.fill",
    "Compras": "bag.fill",
    "Salud": "cross.case.fill",
    "Sueldo": "banknote.fill",
    "Préstamo": "hand.coin.fill",
    "Arriendo": "key.fill",
    "Otros": "ellipsis.circle.fill"
  ]

  /// Distinct hues so categories the backend agent invents on the fly (it owns
  /// classification, not this list) still render as differentiated donut
  /// slices instead of collapsing into one grey "unknown" blob.
  private static let fallbackPalette: [Color] = [
    Color(hex: "6366f1"),
    Color(hex: "0891b2"),
    Color(hex: "eab308"),
    Color(hex: "ec4899"),
    Color(hex: "65a30d")
  ]

  static func color(for category: String) -> Color {
    if let known = categoryColors[category] { return known }
    let index = abs(category.hashValue) % fallbackPalette.count
    return fallbackPalette[index]
  }

  static func icon(for category: String) -> String {
    categoryIcons[category] ?? "sparkles"
  }

  static let incomeColor = Color(hex: "0ca30c")
  static let expenseColor = Color(hex: "e66767")
}
