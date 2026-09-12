import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
  @Binding var voiceCaptureRequested: Bool
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Expense.createdAt, order: .reverse) private var expenses: [Expense]

  @State private var expenseToEdit: Expense?
  @State private var isSyncing = false

  var body: some View {
    ZStack {
      backgroundGradient

      ScrollView {
        VStack(spacing: 20) {
          if let insight = weeklyInsight {
            insightCard(insight)
          }

          balanceCard
          kpiRow

          if !dailyTotals.isEmpty {
            trendCard
          }

          if !expensesByCategory.isEmpty {
            categoryCard
          }

          recentActivity
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
      }
      .safeAreaInset(edge: .bottom) {
        captureButton
      }
    }
    .navigationTitle("Fino")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbarBackground(.hidden, for: .navigationBar)
    .sheet(item: $expenseToEdit) { expense in
      ExpenseFormView(expenseToEdit: expense)
    }
    .task {
      await syncExpenses()
    }
  }

  // MARK: - Background

  private var backgroundGradient: some View {
    LinearGradient(
      colors: [Color(red: 0.03, green: 0.09, blue: 0.14), Color(red: 0.02, green: 0.05, blue: 0.08)],
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }

  // MARK: - Capture button

  /// Big, single entry point into voice capture — the dashboard is the
  /// landing screen, so this is the only way in instead of a small toolbar
  /// icon, per the "vistoso" demo ask.
  private var captureButton: some View {
    Button(action: requestVoiceCapture) {
      HStack(spacing: 10) {
        Image(systemName: "mic.fill")
          .font(.title3.weight(.semibold))
        Text("Registrar gasto")
          .font(.headline)
      }
      .foregroundStyle(.black)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .background(
        LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
        in: Capsule()
      )
      .shadow(color: .mint.opacity(0.35), radius: 20, y: 10)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .background(
      LinearGradient(
        colors: [.clear, Color(red: 0.02, green: 0.05, blue: 0.08).opacity(0.9)],
        startPoint: .top,
        endPoint: .center
      )
      .ignoresSafeArea()
    )
  }

  // MARK: - Agent insight

  private enum InsightTone {
    case positive, caution, neutral
  }

  private struct Insight {
    let message: String
    let tone: InsightTone
  }

  /// Week-over-week spend comparison, computed locally from what's already
  /// logged. Stands in for a real agent-generated insight until the
  /// categorization backend (Shared/Networking) exists — same UI slot either way.
  private var weeklyInsight: Insight? {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: .now)
    guard
      let thisWeekStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
      let lastWeekStart = calendar.date(byAdding: .day, value: -13, to: todayStart)
    else { return nil }

    let thisWeekTotal = expenses
      .filter { $0.kind == .expense && $0.createdAt >= thisWeekStart }
      .reduce(0.0) { $0 + ($1.amount ?? 0) }
    let lastWeekTotal = expenses
      .filter { $0.kind == .expense && $0.createdAt >= lastWeekStart && $0.createdAt < thisWeekStart }
      .reduce(0.0) { $0 + ($1.amount ?? 0) }

    guard lastWeekTotal > 0 else { return nil }

    let change = (thisWeekTotal - lastWeekTotal) / lastWeekTotal
    let percent = Int((abs(change) * 100).rounded())

    if percent < 5 {
      return Insight(message: "Vas parecido a la semana pasada.", tone: .neutral)
    } else if change < 0 {
      return Insight(message: "Vas bien: gastaste \(percent)% menos que la semana pasada.", tone: .positive)
    } else {
      return Insight(message: "Ojo: gastaste \(percent)% más que la semana pasada.", tone: .caution)
    }
  }

  private func insightColor(for tone: InsightTone) -> Color {
    switch tone {
    case .positive: ExpenseStyle.incomeColor
    case .caution: ExpenseStyle.expenseColor
    case .neutral: .white.opacity(0.7)
    }
  }

  private func insightCard(_ insight: Insight) -> some View {
    let color = insightColor(for: insight.tone)
    return HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .foregroundStyle(color)
      Text(insight.message)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white.opacity(0.9))
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(color.opacity(0.3))
    )
  }

  // MARK: - Balance

  private var totalIncome: Double {
    expenses.filter { $0.kind == .income }.reduce(0) { $0 + ($1.amount ?? 0) }
  }

  private var totalExpense: Double {
    expenses.filter { $0.kind == .expense }.reduce(0) { $0 + ($1.amount ?? 0) }
  }

  private var balance: Double { totalIncome - totalExpense }

  /// Aggregates (balance, KPIs, category totals) sum amounts across
  /// currencies, so they need one currency to format in. Uses whichever
  /// currency actually shows up most in the stored expenses instead of
  /// assuming COP, so the dashboard stays correct if the backend/user ever
  /// records in USD or EUR (see `ExpenseFormView.supportedCurrencies`).
  private var primaryCurrency: String {
    let counts = Dictionary(grouping: expenses, by: \.currency).mapValues(\.count)
    return counts.max { $0.value < $1.value }?.key ?? "COP"
  }

  private var balanceCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Balance")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.6))
      Text(balance, format: .currency(code: primaryCurrency).precision(.fractionLength(0)))
        .font(.system(.largeTitle, design: .rounded, weight: .bold))
        .foregroundStyle(balance >= 0 ? ExpenseStyle.incomeColor : ExpenseStyle.expenseColor)
      Text("\(expenses.count) movimiento\(expenses.count == 1 ? "" : "s") registrado\(expenses.count == 1 ? "" : "s")")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.5))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.white.opacity(0.1))
    )
  }

  // MARK: - KPI row

  private var kpiRow: some View {
    HStack(spacing: 12) {
      statTile(title: "Ingresos", amount: totalIncome, kind: .income)
      statTile(title: "Gastos", amount: totalExpense, kind: .expense)
    }
  }

  private func statTile(title: String, amount: Double, kind: ExpenseKind) -> some View {
    let color = kind == .income ? ExpenseStyle.incomeColor : ExpenseStyle.expenseColor
    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: kind.systemImage)
          .foregroundStyle(color)
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.6))
      }
      Text(amount, format: .currency(code: primaryCurrency).precision(.fractionLength(0)))
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(.white.opacity(0.1))
    )
  }

  // MARK: - 7-day trend

  private struct DayTotal: Identifiable {
    let id = UUID()
    let day: Date
    let kind: ExpenseKind
    let amount: Double
  }

  private var dailyTotals: [DayTotal] {
    let calendar = Calendar.current
    guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) else {
      return []
    }
    let recent = expenses.filter { $0.createdAt >= start }
    guard !recent.isEmpty else { return [] }

    var totals: [DateComponents: (income: Double, expense: Double)] = [:]
    for expense in recent {
      let day = calendar.startOfDay(for: expense.createdAt)
      let key = calendar.dateComponents([.year, .month, .day], from: day)
      var bucket = totals[key] ?? (0, 0)
      if expense.kind == .income {
        bucket.income += expense.amount ?? 0
      } else {
        bucket.expense += expense.amount ?? 0
      }
      totals[key] = bucket
    }

    return totals.flatMap { key, bucket -> [DayTotal] in
      guard let day = calendar.date(from: key) else { return [] }
      return [
        DayTotal(day: day, kind: .income, amount: bucket.income),
        DayTotal(day: day, kind: .expense, amount: bucket.expense)
      ]
    }
    .sorted { $0.day < $1.day }
  }

  private var trendCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Últimos 7 días")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)

      Chart(dailyTotals) { entry in
        BarMark(
          x: .value("Día", entry.day, unit: .day),
          y: .value("Monto", entry.amount)
        )
        .position(by: .value("Tipo", entry.kind.label))
        .foregroundStyle(by: .value("Tipo", entry.kind.label))
        .cornerRadius(4)
      }
      .chartForegroundStyleScale([
        ExpenseKind.income.label: ExpenseStyle.incomeColor,
        ExpenseKind.expense.label: ExpenseStyle.expenseColor
      ])
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) { _ in
          AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      .chartYAxis {
        AxisMarks { _ in
          AxisGridLine().foregroundStyle(.white.opacity(0.1))
          AxisValueLabel().foregroundStyle(.white.opacity(0.6))
        }
      }
      .frame(height: 160)
    }
    .padding(20)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.white.opacity(0.1))
    )
  }

  // MARK: - Category breakdown

  private var expensesByCategory: [(category: String, amount: Double)] {
    let grouped = Dictionary(grouping: expenses.filter { $0.kind == .expense }) { $0.category }
    let totals = grouped.map { category, items in
      (category: category, amount: items.reduce(0.0) { $0 + ($1.amount ?? 0) })
    }

    // Known categories keep a stable order (stable donut colors); anything
    // the backend agent tags that isn't in our fixed list still shows up
    // (via ExpenseStyle's fallback palette) instead of silently vanishing.
    let known = ExpenseStyle.categoryOrder.compactMap { category in
      totals.first { $0.category == category }
    }
    let unknown = totals
      .filter { total in !ExpenseStyle.categoryOrder.contains(total.category) }
      .sorted { $0.amount > $1.amount }
    return known + unknown
  }

  private var categoryTotal: Double {
    expensesByCategory.reduce(0) { $0 + $1.amount }
  }

  private var topCategory: (category: String, amount: Double)? {
    expensesByCategory.max { $0.amount < $1.amount }
  }

  private var categoryCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Gastos por categoría")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)

      categoryDonut

      VStack(spacing: 4) {
        ForEach(expensesByCategory, id: \.category) { entry in
          categoryRow(entry)
        }
      }
    }
    .padding(20)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.white.opacity(0.1))
    )
  }

  private var categoryDonut: some View {
    Chart(expensesByCategory, id: \.category) { entry in
      SectorMark(
        angle: .value("Monto", entry.amount),
        innerRadius: .ratio(0.68),
        angularInset: 2.5
      )
      .cornerRadius(6)
      .foregroundStyle(ExpenseStyle.color(for: entry.category))
    }
    .chartLegend(.hidden)
    .frame(height: 200)
    .overlay {
      if let topCategory {
        VStack(spacing: 3) {
          Image(systemName: ExpenseStyle.icon(for: topCategory.category))
            .font(.caption)
            .foregroundStyle(ExpenseStyle.color(for: topCategory.category))
          Text(topCategory.category)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          Text(categoryTotal, format: .currency(code: primaryCurrency).precision(.fractionLength(0)))
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: 120)
      }
    }
  }

  private func categoryRow(_ entry: (category: String, amount: Double)) -> some View {
    let color = ExpenseStyle.color(for: entry.category)
    let percent = categoryTotal > 0 ? entry.amount / categoryTotal : 0

    return HStack(spacing: 12) {
      Image(systemName: ExpenseStyle.icon(for: entry.category))
        .font(.caption)
        .foregroundStyle(color)
        .frame(width: 30, height: 30)
        .background(color.opacity(0.15), in: Circle())

      Text(entry.category)
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.85))

      Spacer(minLength: 8)

      Text("\(Int((percent * 100).rounded()))%")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())

      Text(entry.amount, format: .currency(code: primaryCurrency).precision(.fractionLength(0)))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.8))
        .frame(width: 84, alignment: .trailing)
    }
    .padding(.vertical, 6)
  }

  // MARK: - Recent activity

  private var recentActivity: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Actividad reciente")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
        Spacer()
        if !expenses.isEmpty {
          Text("Mantén presionado para eliminar")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
        }
      }

      if expenses.isEmpty {
        Text("Aún no registras nada. Habla con Fino para agregar tu primer movimiento.")
          .font(.callout)
          .foregroundStyle(.white.opacity(0.5))
          .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      } else {
        VStack(spacing: 0) {
          ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
            Button {
              expenseToEdit = expense
            } label: {
              ExpenseRow(expense: expense)
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button(role: .destructive) {
                delete(expense)
              } label: {
                Label("Eliminar", systemImage: "trash")
              }
            }

            if index < expenses.count - 1 {
              Divider().overlay(.white.opacity(0.08))
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      }
    }
  }

  private func requestVoiceCapture() {
    voiceCaptureRequested = true
  }

  private func syncExpenses() async {
    guard !isSyncing else { return }
    isSyncing = true
    defer { isSyncing = false }

    do {
      let remoteExpenses = try await ExpenseAPIClient.shared.listExpenses()
      for remoteExpense in remoteExpenses {
        if let existingExpense = expenses.first(where: { $0.id == remoteExpense.id }) {
          apply(remoteExpense, to: existingExpense)
        } else {
          modelContext.insert(Expense(remoteExpense))
        }
      }
    } catch {
      // The local history remains usable if the network is unavailable.
    }
  }

  /// Deletes locally right away and fires the backend delete in the
  /// background; the row is gone from the UI either way, and there's no
  /// remote data left to reconcile back in on the next sync.
  private func delete(_ expense: Expense) {
    let id = expense.id
    modelContext.delete(expense)
    Task {
      try? await ExpenseAPIClient.shared.deleteExpense(id: id)
    }
  }

  private func apply(_ remoteExpense: CapturedExpense, to expense: Expense) {
    expense.amount = remoteExpense.amount
    expense.currency = remoteExpense.currency
    expense.category = remoteExpense.category
    expense.kind = remoteExpense.kind
    expense.expenseDescription = remoteExpense.description
    expense.createdAt = remoteExpense.createdAt
    expense.source = remoteExpense.source
  }
}

private struct ExpenseRow: View {
  let expense: Expense

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: ExpenseStyle.icon(for: expense.category))
        .font(.subheadline)
        .foregroundStyle(ExpenseStyle.color(for: expense.category))
        .frame(width: 32, height: 32)
        .background(ExpenseStyle.color(for: expense.category).opacity(0.15), in: Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(expense.expenseDescription)
          .font(.subheadline)
          .foregroundStyle(.white)
          .lineLimit(1)
        Text("\(expense.category) · \(expense.createdAt.formatted(date: .abbreviated, time: .shortened))")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.5))
      }

      Spacer()

      HStack(spacing: 4) {
        Image(systemName: expense.kind.systemImage)
          .font(.caption2)
        if let amount = expense.amount {
          Text(amount, format: .currency(code: expense.currency).precision(.fractionLength(0)))
            .font(.subheadline.weight(.semibold))
        } else {
          Text("Sin monto")
            .font(.caption)
        }
      }
      .foregroundStyle(expense.kind == .income ? ExpenseStyle.incomeColor : ExpenseStyle.expenseColor)
    }
    .padding(.vertical, 10)
  }
}
