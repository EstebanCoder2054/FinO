import Foundation

struct CapturedExpense: Equatable {
  let id: UUID
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

final class ExpenseAPIClient {
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
}

private struct CreateExpenseRequest: Encodable {
  let input: String
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
  let amount: String?
  let currency: String
  let category: String
  let description: String
  let source: String
  let createdAt: String

  var capturedExpense: CapturedExpense {
    CapturedExpense(
      id: id,
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
    case "health":
      return "Salud"
    default:
      return "Otros"
    }
  }
}

private struct APIErrorResponse: Decodable {
  let message: String
}
