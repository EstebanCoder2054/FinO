import Foundation

struct CapturedExpense: Equatable {
  let id: UUID
  let kind: ExpenseKind
  let amount: Double?
  let currency: String
  let category: String
  let description: String
  let createdAt: Date
  let source: String
}

enum ExpenseAPIError: Error {
  case invalidResponse
  case serverMessage(String)
}

final class ExpenseAPIClient: @unchecked Sendable {
  static let shared = ExpenseAPIClient()

  private let baseURL: URL
  private let session: URLSession
  private let decoder: JSONDecoder

  init(
    baseURL: URL = URL(string: "https://fin-o-ecru.vercel.app")!,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.session = session
    self.decoder = JSONDecoder()
  }

  func createExpense(from input: String) async throws -> CapturedExpense {
    var request = URLRequest(url: baseURL.appending(path: "api/expenses"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
    request.httpBody = try JSONEncoder().encode(CreateExpenseRequest(input: input))

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ExpenseAPIError.invalidResponse
    }

    if (200..<300).contains(httpResponse.statusCode) {
      let decoded = try decoder.decode(CreateExpenseResponse.self, from: data)
      return decoded.expense.capturedExpense
    }

    if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
      throw ExpenseAPIError.serverMessage(apiError.message)
    }

    throw ExpenseAPIError.invalidResponse
  }

  func listExpenses() async throws -> [CapturedExpense] {
    var request = URLRequest(url: baseURL.appending(path: "api/expenses"))
    request.httpMethod = "GET"

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ExpenseAPIError.invalidResponse
    }

    if (200..<300).contains(httpResponse.statusCode) {
      let decoded = try decoder.decode(ListExpensesResponse.self, from: data)
      return decoded.expenses.map(\.capturedExpense)
    }

    if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
      throw ExpenseAPIError.serverMessage(apiError.message)
    }

    throw ExpenseAPIError.invalidResponse
  }

  /// `category` is the app's local display category (e.g. "Comida"); it is
  /// mapped to the backend's category enum before sending, since the two
  /// don't share a vocabulary (the backend has no income-side categories).
  func updateExpense(
    id: UUID,
    amount: Double?,
    currency: String,
    category: String,
    description: String
  ) async throws -> CapturedExpense {
    var request = URLRequest(url: baseURL.appending(path: "api/expenses/\(id.uuidString)"))
    request.httpMethod = "PATCH"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      UpdateExpenseRequest(
        amount: amount,
        currency: currency,
        category: Self.backendCategory(for: category),
        description: description
      )
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ExpenseAPIError.invalidResponse
    }

    if (200..<300).contains(httpResponse.statusCode) {
      let decoded = try decoder.decode(CreateExpenseResponse.self, from: data)
      return decoded.expense.capturedExpense
    }

    if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
      throw ExpenseAPIError.serverMessage(apiError.message)
    }

    throw ExpenseAPIError.invalidResponse
  }

  func deleteExpense(id: UUID) async throws {
    var request = URLRequest(url: baseURL.appending(path: "api/expenses/\(id.uuidString)"))
    request.httpMethod = "DELETE"

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ExpenseAPIError.invalidResponse
    }

    if (200..<300).contains(httpResponse.statusCode) {
      return
    }

    if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
      throw ExpenseAPIError.serverMessage(apiError.message)
    }

    throw ExpenseAPIError.invalidResponse
  }

  /// Reverse of `RemoteExpense.displayCategory`. Lossy on purpose (several
  /// backend categories collapse into one local label); picks one
  /// representative backend value per label. "Arriendo" has no backend
  /// counterpart (rent tracking stays local-only) and falls back to "other".
  private static func backendCategory(for displayCategory: String) -> String {
    switch displayCategory {
    case "Comida": return "restaurants"
    case "Transporte": return "transportation"
    case "Hogar": return "utilities"
    case "Entretenimiento": return "entertainment"
    case "Compras": return "shopping"
    case "Salud": return "health"
    case "Sueldo": return "salary"
    case "Préstamo": return "loan"
    case "Regalo": return "gift"
    case "Reembolso": return "refund"
    case "Otro ingreso": return "other_income"
    default: return "other"
    }
  }
}

private struct CreateExpenseRequest: Encodable {
  let input: String
}

private struct UpdateExpenseRequest: Encodable {
  let amount: Double?
  let currency: String
  let category: String
  let description: String

  private enum CodingKeys: String, CodingKey {
    case amount, currency, category, description
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(amount, forKey: .amount)
    try container.encode(currency, forKey: .currency)
    try container.encode(category, forKey: .category)
    try container.encode(description, forKey: .description)
  }
}

private struct CreateExpenseResponse: Decodable {
  let success: Bool
  let expense: RemoteExpense
}

private struct ListExpensesResponse: Decodable {
  let success: Bool
  let expenses: [RemoteExpense]
}

private struct RemoteExpense: Decodable {
  let id: UUID
  let kind: ExpenseKind
  let amount: String?
  let currency: String
  let category: String
  let description: String
  let source: String
  let createdAt: String

  private enum CodingKeys: String, CodingKey {
    case id, kind, amount, currency, category, description, source, createdAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    // The deployed API doesn't send `kind` yet (income support is still
    // rolling out) — default to `.expense` instead of hard-failing decode
    // on every row the current backend returns.
    kind = try container.decodeIfPresent(ExpenseKind.self, forKey: .kind) ?? .expense
    amount = try container.decodeIfPresent(String.self, forKey: .amount)
    currency = try container.decode(String.self, forKey: .currency)
    category = try container.decode(String.self, forKey: .category)
    description = try container.decode(String.self, forKey: .description)
    source = try container.decode(String.self, forKey: .source)
    createdAt = try container.decode(String.self, forKey: .createdAt)
  }

  var capturedExpense: CapturedExpense {
    CapturedExpense(
      id: id,
      kind: kind,
      amount: amount.flatMap(Self.parseAmount),
      currency: currency,
      category: Self.displayCategory(for: category),
      description: description,
      createdAt: Self.parseDate(createdAt),
      source: source
    )
  }

  private static func parseAmount(_ value: String) -> Double? {
    Double(value.replacingOccurrences(of: ",", with: "."))
  }

  private static func parseDate(_ value: String) -> Date {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
      return date
    }

    let formatter = ISO8601DateFormatter()
    return formatter.date(from: value) ?? .now
  }

  private static func displayCategory(for category: String) -> String {
    switch category {
    case "groceries", "restaurants":
      return "Comida"
    case "transportation", "travel":
      return "Transporte"
    case "utilities":
      return "Hogar"
    case "entertainment", "subscriptions":
      return "Entretenimiento"
    case "shopping":
      return "Compras"
    case "health":
      return "Salud"
    case "salary":
      return "Sueldo"
    case "loan":
      return "Préstamo"
    case "gift":
      return "Regalo"
    case "refund":
      return "Reembolso"
    case "other_income":
      return "Otro ingreso"
    default:
      return "Otros"
    }
  }
}

private struct APIErrorResponse: Decodable {
  let message: String
}
