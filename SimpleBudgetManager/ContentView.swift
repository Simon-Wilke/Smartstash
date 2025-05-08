//
//  ContentView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 11/30/24.
//

import SwiftUI
import Charts

struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    var amount: Double
    var category: String
    var type: TransactionType
    var date: Date 
    var recurrence: RecurrenceType
    var notes: String?
    var icon: String


    enum TransactionType: String, Codable, CaseIterable {
        case income
        case expense
        case investment
        case savings
    }
    
    enum RecurrenceType: String, Codable, CaseIterable {
        case oneTime
        case daily
        case weekly
        case biWeekly
        case monthly
        case quarterly
        case annually
    }
    
    init(
           amount: Double,
           category: String,
           type: TransactionType,
           recurrence: RecurrenceType = .oneTime,
           notes: String? = nil,
           icon: String,
           date: Date = Date()  // ✅ Now allows setting a custom date (default is `Date()`)
       ) {
           self.id = UUID()
           self.amount = amount
           self.category = category
           self.type = type
           self.recurrence = recurrence
           self.notes = notes
           self.icon = icon
           self.date = date  // ✅ Now uses the provided date instead of always `Date()`
       }
   }

class BudgetViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var pendingTransactions: [Transaction] = []
    @Published var budgetGoals: [BudgetGoal] = []
    
    // MARK: - Recurring Transaction Configuration
    
    struct RecurrenceConfig {
        let visibilityWindow: TimeInterval
        let preNotificationWindow: TimeInterval
        
        static func forType(_ type: Transaction.RecurrenceType) -> RecurrenceConfig {
            switch type {
            case .daily:
                return RecurrenceConfig(
                    visibilityWindow: 7 * 24 * 3600,  // 7 days ahead
                    preNotificationWindow: 24 * 3600   // 1 day before
                )
            case .weekly:
                return RecurrenceConfig(
                    visibilityWindow: 2 * 7 * 24 * 3600,  // 2 weeks ahead
                    preNotificationWindow: 3 * 24 * 3600   // 3 days before
                )
            case .biWeekly:
                return RecurrenceConfig(
                    visibilityWindow: 4 * 7 * 24 * 3600,  // 4 weeks ahead
                    preNotificationWindow: 3 * 24 * 3600   // 3 days before
                )
            case .monthly:
                return RecurrenceConfig(
                    visibilityWindow: 31 * 24 * 3600,     // ~1 month ahead
                    preNotificationWindow: 7 * 24 * 3600   // 1 week before
                )
            case .quarterly:
                return RecurrenceConfig(
                    visibilityWindow: 93 * 24 * 3600,     // ~3 months ahead
                    preNotificationWindow: 7 * 24 * 3600   // 1 week before
                )
            case .annually:
                return RecurrenceConfig(
                    visibilityWindow: 31 * 24 * 3600,     // Show 1 month ahead
                    preNotificationWindow: 7 * 24 * 3600   // 1 week before
                )
            case .oneTime:
                return RecurrenceConfig(
                    visibilityWindow: 365 * 24 * 3600,    // Show up to a year ahead
                    preNotificationWindow: 0               // No pre-notification
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var allTransactions: [Transaction] {
        // Combine actual and upcoming transactions, sorted by date
        (transactions + pendingTransactions).sorted { $0.date < $1.date }
    }
    
    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpenses: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    var totalInvestments: Double {
        transactions.filter { $0.type == .investment }.reduce(0) { $0 + $1.amount }
    }
    
    var totalSavings: Double {
        transactions.filter { $0.type == .savings }.reduce(0) { $0 + $1.amount }
    }
    
    var balance: Double {
        totalIncome - totalExpenses
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(_ transaction: Transaction) {
        if transaction.recurrence == .oneTime {
            if transaction.date <= Date() {
                transactions.append(transaction)
            } else {
                pendingTransactions.append(transaction)
            }
        } else {
            generateRecurringTransactions(from: transaction)
        }
        
        saveTransactions()
        savePendingTransactions()
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions.remove(at: index)
        }
        if let index = pendingTransactions.firstIndex(where: { $0.id == transaction.id }) {
            pendingTransactions.remove(at: index)
        }
        
        saveTransactions()
        savePendingTransactions()
    }
    
    func updateTransaction(_ updatedTransaction: Transaction) {
        // Update in transactions array
        if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
            transactions[index] = updatedTransaction
        }
        
        // Update in pendingTransactions array
        if let index = pendingTransactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
            pendingTransactions[index] = updatedTransaction
        }
        
        saveTransactions()
        savePendingTransactions()
    }
    
    // MARK: - Recurring Transaction Handling
    
    func generateRecurringTransactions(from transaction: Transaction) {
        // First, remove any existing pending transactions with the same pattern
        // (same category, type, amount, recurrence, etc.)
        pendingTransactions.removeAll { pendingTx in
            pendingTx.category == transaction.category &&
            pendingTx.type == transaction.type &&
            pendingTx.amount == transaction.amount &&
            pendingTx.recurrence == transaction.recurrence &&
            pendingTx.date > Date() // Only remove future transactions
        }
        
        let config = RecurrenceConfig.forType(transaction.recurrence)
        let visibilityEndDate = Date().addingTimeInterval(config.visibilityWindow)
        var currentDate = transaction.date
        
        // For existing transactions, find the most recent occurrence to start from
        if transaction.recurrence != .oneTime {
            let existingTransactions = transactions.filter {
                $0.category == transaction.category &&
                $0.type == transaction.type &&
                $0.amount == transaction.amount &&
                $0.recurrence == transaction.recurrence
            }.sorted(by: { $0.date > $1.date })
            
            if let mostRecent = existingTransactions.first {
                // Start from the next occurrence after the most recent one
                currentDate = getNextDate(from: mostRecent.date, recurrence: transaction.recurrence)
            }
        }
        
        // Generate transactions until we reach the visibility window
        while currentDate <= visibilityEndDate {
            let recurringTransaction = Transaction(
                amount: transaction.amount,
                category: transaction.category,
                type: transaction.type,
                recurrence: transaction.recurrence,
                notes: transaction.notes,
                icon: transaction.icon,
                date: currentDate
            )
            
            if currentDate <= Date() {
                transactions.append(recurringTransaction)
            } else {
                pendingTransactions.append(recurringTransaction)
            }
            
            currentDate = getNextDate(from: currentDate, recurrence: transaction.recurrence)
        }
        
        saveTransactions()
        savePendingTransactions()
    }
    
    func getNextDate(from date: Date, recurrence: Transaction.RecurrenceType) -> Date {
        let calendar = Calendar.current
        
        switch recurrence {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biWeekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .annually:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .oneTime:
            return date
        }
    }
    
    func refreshPendingTransactions() {
        let now = Date()
        
        // Remove old pending transactions
        pendingTransactions.removeAll { transaction in
            return transaction.date < now
        }
        
        // Regenerate future transactions for all recurring transactions
        // But first, group recurring transactions to avoid duplicates
        let recurringTransactionGroups = Dictionary(
            grouping: transactions.filter { $0.recurrence != .oneTime },
            by: { "\($0.category)-\($0.type)-\($0.amount)-\($0.recurrence)" }
        )
        
        // For each unique recurring transaction pattern, generate future occurrences
        for (_, transactions) in recurringTransactionGroups {
            if let representative = transactions.sorted(by: { $0.date > $1.date }).first {
                generateRecurringTransactions(from: representative)
            }
        }
        
        savePendingTransactions()
    }
    
    func processTransactions() {
        let now = Date()
        let processedTransactions = pendingTransactions.filter { $0.date <= now }
        
        transactions.append(contentsOf: processedTransactions)
        pendingTransactions.removeAll { $0.date <= now }
        
        saveTransactions()
        savePendingTransactions()
    }
    
    // MARK: - Category Analysis
    
    func totalForCategory(_ category: String, type: Transaction.TransactionType) -> Double {
        transactions
            .filter { $0.category == category && $0.type == type }
            .reduce(0) { $0 + $1.amount }
    }
    
    func transactionsByCategory(type: Transaction.TransactionType) -> [String: Double] {
        Dictionary(
            grouping: transactions.filter { $0.type == type },
            by: { $0.category }
        ).mapValues {
            $0.reduce(0) { $0 + $1.amount }
        }
    }
    
    // MARK: - Persistence
    
    func saveTransactions() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transactions)
            UserDefaults.standard.set(data, forKey: "transactions")
        } catch {
            print("Failed to save transactions: \(error)")
        }
    }
    
    func loadTransactions() {
        if let data = UserDefaults.standard.data(forKey: "transactions") {
            do {
                let decoder = JSONDecoder()
                transactions = try decoder.decode([Transaction].self, from: data)
            } catch {
                print("Failed to load transactions: \(error)")
            }
        }
    }
    
    func savePendingTransactions() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(pendingTransactions)
            UserDefaults.standard.set(data, forKey: "pendingTransactions")
        } catch {
            print("Failed to save pending transactions: \(error)")
        }
    }
    
    func loadPendingTransactions() {
        if let data = UserDefaults.standard.data(forKey: "pendingTransactions") {
            do {
                let decoder = JSONDecoder()
                pendingTransactions = try decoder.decode([Transaction].self, from: data)
            } catch {
                print("Failed to load pending transactions: \(error)")
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadTransactions()
        loadPendingTransactions()
        
        // Process transactions on launch
        processTransactions()
        
        // Set up timers for transaction processing and recurring transaction refresh
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.processTransactions()
        }
        
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.refreshPendingTransactions()
        }
    }
}
// Budget Goal Structure
struct BudgetGoal: Identifiable, Codable {
    let id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var category: Transaction.TransactionType
    
    var progressPercentage: Double {
        (currentAmount / targetAmount) * 100
    }
}
struct TransactionEditSheet: View {
    @State var transaction: Transaction
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    @State private var showingRecurrenceAlert = false
    @State private var recurrenceCancellationType: RecurrenceCancellationType = .thisAndFuture
    
    enum RecurrenceCancellationType {
        case thisOnly
        case thisAndFuture
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "xmark")
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(8)
                }
                
                Spacer()
                
                Text("Edit Transaction")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    updateTransaction()
                    hapticFeedback.impactOccurred()
                    dismiss()
                }) {
                    Text("Save")
                        .fontWeight(.bold)
                        .foregroundColor(transaction.category.isEmpty || transaction.amount <= 0 ? .gray : bluePurpleColor)
                }
                .disabled(transaction.category.isEmpty || transaction.amount <= 0)
                .padding()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Category Input
                    CategoryInputView(category: $transaction.category, selectedIcon: .constant("💵"))
                    
                    // Amount Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter amount", value: $transaction.amount, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Notes Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter notes (e.g., Payment details, Location)", text: Binding(
                            get: { transaction.notes ?? "" },
                            set: { transaction.notes = $0 }
                        ))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Transaction Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                                Button(type.rawValue.capitalized) {
                                    hapticFeedback.impactOccurred()
                                    transaction.type = type
                                }
                            }
                        } label: {
                            HStack {
                                Text(transaction.type.rawValue.capitalized)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Recurrence Information (if applicable)
                    if transaction.recurrence != .oneTime {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recurring Transaction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Repeats \(transaction.recurrence.rawValue.lowercased())")
                                Spacer()
                                Button("Cancel Series") {
                                    showingRecurrenceAlert = true
                                }
                                .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .background(Color("BackgroundColor"))
        .edgesIgnoringSafeArea(.bottom)
        .presentationDetents(transaction.recurrence == .oneTime ? [.medium] : [.fraction(0.7)])
        .presentationDragIndicator(.visible)
        .alert("Cancel Recurring Transaction", isPresented: $showingRecurrenceAlert) {
            Button("This Transaction Only") {
                recurrenceCancellationType = .thisOnly
                cancelRecurringTransaction()
                dismiss()
            }
            
            Button("This & Future") {
                recurrenceCancellationType = .thisAndFuture
                cancelRecurringTransaction()
                dismiss()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Would you like to cancel just this transaction or this and all future occurrences?")
        }
    }
    
    private func updateTransaction() {
        viewModel.updateTransaction(transaction)
    }
    
    private func cancelRecurringTransaction() {
        switch recurrenceCancellationType {
        case .thisOnly:
            // Delete just this instance
            viewModel.deleteTransaction(transaction)
            
        case .thisAndFuture:
            // Delete this and all future occurrences
            let currentDate = transaction.date
            viewModel.transactions.removeAll { transaction in
                // Remove transactions with the same category, amount, and recurrence that occur on or after this one
                transaction.category == self.transaction.category &&
                transaction.amount == self.transaction.amount &&
                transaction.recurrence == self.transaction.recurrence &&
                transaction.date >= currentDate
            }
            viewModel.pendingTransactions.removeAll { transaction in
                // Remove pending transactions with the same characteristics
                transaction.category == self.transaction.category &&
                transaction.amount == self.transaction.amount &&
                transaction.recurrence == self.transaction.recurrence
            }
            viewModel.saveTransactions()
            viewModel.savePendingTransactions()
        }
    }
}
import SwiftUI
import Charts

struct FinancialSummaryView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedTimePeriod: TimePeriod
    @Environment(\.colorScheme) var colorScheme
    
    // State variables to track which card is expanded
    @State private var expandedCard: CardType? = nil
    // Add these animation properties
    @State private var cardOffset: CGFloat = 0
    @State private var cardScale: CGFloat = 1.0
    
    @AppStorage("showChart") private var showChart: Bool = true
    
    enum CardType {
        case income
        case expenses
        case balance
        case trend
    }

    enum TimePeriod: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"

        var id: String { self.rawValue }
    }

    var filteredTransactions: [Transaction] {
        switch selectedTimePeriod {
        case .day:
            return viewModel.transactions.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
        case .week:
            return viewModel.transactions.filter {
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return $0.date >= sevenDaysAgo && $0.date <= Date()
            }
        case .month:
            return viewModel.transactions.filter {
                let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                return $0.date >= oneMonthAgo && $0.date <= Date()
            }
        case .year:
            return viewModel.transactions.filter {
                let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
                return $0.date >= oneYearAgo && $0.date <= Date()
            }
        case .allTime:
            return viewModel.transactions
        }
    }

    var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var balance: Double {
        viewModel.totalIncome - viewModel.totalExpenses
    }
    
    // Additional computed properties for detailed information
    var incomeCategories: [(category: String, amount: Double)] {
        let incomeTransactions = filteredTransactions.filter { $0.type == .income }
        let groupedByCategory = Dictionary(grouping: incomeTransactions) { $0.category }
        return groupedByCategory.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    var expenseCategories: [(category: String, amount: Double)] {
        let expenseTransactions = filteredTransactions.filter { $0.type == .expense }
        let groupedByCategory = Dictionary(grouping: expenseTransactions) { $0.category }
        return groupedByCategory.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }

    var cumulativeBalanceData: [(Date, Double)] {
        let sortedTransactions = filteredTransactions.sorted(by: { $0.date < $1.date })
        var cumulativeBalance: Double = 0.0
        var data: [(Date, Double)] = []
        
        for transaction in sortedTransactions {
            cumulativeBalance += transaction.type == .income ? transaction.amount : -transaction.amount
            data.append((transaction.date, cumulativeBalance))
        }
        
        return data
    }

    var lineColor: Color {
        guard let first = cumulativeBalanceData.first?.1, let last = cumulativeBalanceData.last?.1 else {
            return Color.gray
        }
        return last >= first ? Color.green : Color.red
    }

    var trendPercentage: Double {
        let previousTransactions: [Transaction]
        switch selectedTimePeriod {
        case .day:
            previousTransactions = viewModel.transactions.filter {
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                return Calendar.current.isDate($0.date, inSameDayAs: yesterday)
            }
        case .week:
            previousTransactions = viewModel.transactions.filter {
                let previousWeek = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
                let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return $0.date >= previousWeek && $0.date < lastWeek
            }
        case .month:
            previousTransactions = viewModel.transactions.filter {
                let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
                let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                return $0.date >= twoMonthsAgo && $0.date < lastMonth
            }
        case .year:
            previousTransactions = viewModel.transactions.filter {
                let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
                let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
                return $0.date >= twoYearsAgo && $0.date < lastYear
            }
        case .allTime:
            return 0.0
        }

        let previousIncome = previousTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        return previousIncome == 0 ? 0.0 : ((totalIncome - previousIncome) / previousIncome) * 100
    }
    
    // Add haptic feedback
    let lightImpact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 8) {
            // First row: Income and Expenses
            HStack(spacing: 8) {
                if expandedCard == .income {
                    // Expanded Income Card
                    ExpandedSummaryCard(
                        title: "Income",
                        amount: totalIncome,
                        color: Color(hex: "#4CAF50"),
                        icon: "arrow.up.circle.fill",
                        details: ["Income for \(selectedTimePeriod.rawValue.lowercased())"],
                        fullAmount: "$\(String(format: "%.2f", totalIncome))",
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = nil
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .offset(x: -20)).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .offset(x: -20)).combined(with: .opacity)
                        )
                    )
                } else if expandedCard == .expenses {
                    // Space for expanded Expenses card
                    EmptyView()
                } else {
                    // Regular Income Card
                    SummaryCard(
                        title: "Income",
                        amount: totalIncome,
                        color: Color(hex: "#4CAF50"),
                        icon: "arrow.up.circle.fill",
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = .income
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .offset(x: 20)).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .offset(x: 20)).combined(with: .opacity)
                        )
                    )
                }
                
                if expandedCard == .expenses {
                    // Expanded Expenses Card
                    ExpandedSummaryCard(
                        title: "Expenses",
                        amount: totalExpenses,
                        color: Color(hex: "#F44336"),
                        icon: "arrow.down.circle.fill",
                        details: ["Expenses for \(selectedTimePeriod.rawValue.lowercased())"],
                        fullAmount: "$\(String(format: "%.2f", totalExpenses))",
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = nil
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .offset(x: 20)).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .offset(x: 20)).combined(with: .opacity)
                        )
                    )
                } else if expandedCard == .income {
                    // Space for expanded Income card
                    EmptyView()
                } else {
                    // Regular Expenses Card
                    SummaryCard(
                        title: "Expenses",
                        amount: totalExpenses,
                        color: Color(hex: "#F44336"),
                        icon: "arrow.down.circle.fill",
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = .expenses
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .offset(x: -20)).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .offset(x: -20)).combined(with: .opacity)
                        )
                    )
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3), value: expandedCard)
        
            // Second row: Balance and Trend
            HStack(spacing: 8) {
                if expandedCard == .balance {
                    // Expanded Balance Card
                    ExpandedSummaryCard(
                        title: "Balance",
                        amount: balance,
                        color: Color(hex: "#5771FF"),
                        icon: "dollarsign.circle.fill",
                        details: [
                            "Savings Rate: \(String(format: "%.1f", (totalIncome - totalExpenses) / totalIncome * 100))% of income saved",
                            "\(selectedTimePeriod.rawValue) Average: $\(String(format: "%.2f", balance / max(1, Double(selectedTimePeriod == .month ? 1 : 12)))) per \(selectedTimePeriod == .day ? "day" : selectedTimePeriod == .week ? "week" : selectedTimePeriod == .month ? "month" : selectedTimePeriod == .year ? "month" : "period")"
                        ],
                        fullAmount: "$\(String(format: "%.2f", balance))",
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = nil
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.scale(scale: 0.8)
                                .combined(with: .offset(y: 10))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                            removal: AnyTransition.scale(scale: 0.8)
                                .combined(with: .offset(y: 10))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7))
                        )
                    )
                } else if expandedCard == .trend {
                    // Space for expanded Trend card
                    EmptyView()
                } else {
                    // Regular Balance Card
                    SummaryCard(
                        title: "Balance",
                        amount: balance,
                        color: Color(hex: "#5771FF"),
                        icon: "dollarsign.circle.fill",
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = .balance
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.scale(scale: 1.1)
                                .combined(with: .offset(y: -5))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                            removal: AnyTransition.scale(scale: 1.1)
                                .combined(with: .offset(y: -5))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7))
                        )
                    )
                }

                if expandedCard == .trend {
                    // Expanded Trend Card
                    ExpandedTrendCard(
                        trendPercentage: trendPercentage,
                        color: trendPercentage >= 0 ? Color.green : Color.red,
                        previousPeriodAmount: totalIncome - (totalIncome * (trendPercentage / 100)),
                        currentPeriodAmount: totalIncome,
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = nil
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.scale(scale: 0.8)
                                .combined(with: .offset(y: 10))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                            removal: AnyTransition.scale(scale: 0.8)
                                .combined(with: .offset(y: 10))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7))
                        )
                    )
                } else if expandedCard == .balance {
                    // Space for expanded Balance card
                    EmptyView()
                } else {
                    // Regular Trend Card
                    TrendCard(
                        trendPercentage: trendPercentage,
                        color: trendPercentage >= 0 ? Color.green : Color.red,
                        onTap: {
                            lightImpact.impactOccurred()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                                expandedCard = .trend
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.scale(scale: 1.1)
                                .combined(with: .offset(y: -5))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                            removal: AnyTransition.scale(scale: 1.1)
                                .combined(with: .offset(y: -5))
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7))
                        )
                    )
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3), value: expandedCard)

            if showChart, !filteredTransactions.isEmpty {
                Chart {
                    ForEach(cumulativeBalanceData, id: \.0) { date, balance in
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Balance", balance)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(bluePurpleColor)
                        
                        AreaMark(
                            x: .value("Date", date),
                            yStart: .value("Balance", 0),
                            yEnd: .value("Balance", balance)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(bluePurpleColor.opacity(0.2))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 30)
                .padding(8)
                .padding(.vertical, 10)
                .background(
                        ZStack {
                            if showChart {
                                DotMatrixPattern()
                            }
                        }
                    )
                    .cornerRadius(10)
            }
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(10)
        .onAppear {
            // Initialize haptic feedback generator
            lightImpact.prepare()
        }
    }
}
// Updated TrendCard that's tappable
struct TrendCard: View {
    let trendPercentage: Double
    let color: Color
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: trendPercentage >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.headline)
                        .foregroundColor(color)
                    Text("Trend")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                Text("\(trendPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trendPercentage))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(minHeight: 53, maxHeight: 53)
            .padding(8)
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : color.opacity(0.12))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Expanded version of the trend card
struct ExpandedTrendCard: View {
    let trendPercentage: Double
    let color: Color
    let previousPeriodAmount: Double
    let currentPeriodAmount: Double
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: trendPercentage >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .font(.headline)
                        .foregroundColor(color)
                    Text("Trend Analysis")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        )
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                Text("\(trendPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trendPercentage))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Previous period:")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(String(format: "%.2f", previousPeriodAmount))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Current period:")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(String(format: "%.2f", currentPeriodAmount))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Difference:")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(String(format: "%.2f", currentPeriodAmount - previousPeriodAmount))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(color)
                    }
                }
                .padding(.top, 4)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(12)
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Updated SummaryCard that's tappable
struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    let onTap: () -> Void
    
    @State private var animatedAmount: Double = 0.0
    @State private var dollarOffset: CGFloat = -40.0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("$")
                            .font(.system(size: 24, weight: .heavy, design: .default))
                            .fontWeight(.heavy)
                            .foregroundColor(color)
                            .offset(x: dollarOffset)
                            .animation(amount > 0 ? .easeInOut(duration: 0.4) : .none, value: dollarOffset)
                        
                        Text(formatAmount(animatedAmount))
                            .font(.system(size: 24, weight: .heavy, design: .default))
                            .fontWeight(.heavy)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: animatedAmount))
                            .animation(amount > 0 ? .easeInOut(duration: 1.0) : .none, value: animatedAmount)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    .fixedSize()
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(8)
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : color.opacity(0.12))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if amount > 0 {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animatedAmount = amount
                    dollarOffset = 0.0
                }
            } else {
                animatedAmount = amount
                dollarOffset = 0.0
            }
        }
        .onChange(of: amount) { newValue in
            if newValue > 0 {
                withAnimation(.easeInOut(duration: 1.0)) {
                    dollarOffset = -10
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            animatedAmount = newValue
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        dollarOffset = 0.0
                    }
                }
            } else {
                animatedAmount = newValue
                dollarOffset = 0.0
            }
        }
    }
    
    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        
        // If the amount is over 1 million
        if abs(amount) >= 1_000_000 {
            let formattedAmount = formatter.string(from: NSNumber(value: amount / 1_000_000)) ?? "\(amount)"
            return "\(formattedAmount)M"
        }
        // If the amount is over 1,000
        else if abs(amount) >= 1_000 {
            let formattedAmount = formatter.string(from: NSNumber(value: amount / 1_000)) ?? "\(amount)"
            return "\(formattedAmount)K"
        }
        // For amounts less than 1,000, return the full value
        else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        }
    }
}
import SwiftUI

struct ExpandedSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    let details: [String]
    let fullAmount: String
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$" // Force $ symbol (default is $ for US locale anyway)
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        )
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                Text(formattedAmount)
                    .font(.system(size: 28, weight: .heavy, design: .default))
                    .fontWeight(.heavy)
                    .foregroundColor(color)
                    .padding(.bottom, 4)
                
                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.8))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DotMatrixPattern: View {
    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 12
            let dotSize: CGFloat = 4
            let columns = Int(geometry.size.width / spacing) + 3
            let rows = Int(geometry.size.height / spacing) + 3
            
            ForEach(0..<columns * rows, id: \.self) { index in
                let column = index % columns
                let row = index / columns
                
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .position(
                        x: CGFloat(column) * spacing,
                        y: CGFloat(row) * spacing
                    )
                    .foregroundColor(.gray.opacity(0.06))
            }
        }
        .clipped()
    }
}
struct UpcomingTransactionRowView: View {
    let transaction: Transaction
    let viewModel: BudgetViewModel
    let colorScheme: ColorScheme
    @State private var showingEditSheet = false
    
    func getIconImage(named iconName: String) -> Image? {
        // Try to load an image from assets based on the icon name
        if let uiImage = UIImage(named: iconName) {
            return Image(uiImage: uiImage)
        } else {
            return nil
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                // Check if the icon is an image or text (emoji)
                let isLogo = getIconImage(named: transaction.icon) != nil
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLogo ? Color.white : randomPaleColor())
                    .frame(width: 36, height: 36)
                    .overlay(
                        Group {
                            if let iconImage = getIconImage(named: transaction.icon) {
                                // Display image
                                iconImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                            } else {
                                // Fallback to emoji text
                                Text(transaction.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                        }
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.category)
                        .font(Font.custom("Roboto-Medium", size: 15))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    HStack(spacing: 4) {
                        Text(formattedDate(transaction.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if transaction.recurrence != .oneTime {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.secondary)
                                .font(.system(size: 8))
                        }
                    }
                }
            }
            
            Spacer()
            
            Text(amountString(for: transaction))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(colorForTransactionType(transaction.type).opacity(0.0))
                )
                .foregroundColor(colorForTransactionType(transaction.type))
                .fontWeight(.bold)
                .font(.system(size: 14))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(hex: "#262626") : Color.white)
                .shadow(color: colorScheme == .dark ? Color.black.opacity(0.15) : Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditSheet(transaction: transaction, viewModel: viewModel)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        if Calendar.current.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func randomPaleColor() -> Color {
        let colors: [Color] = [
            AppTheme.primary,
            AppTheme.accent,
            AppTheme.secondary,
            Color(hex: "8676FF"),
            Color(hex: "63C7FF")
        ]
        
        let randomColor = colors.randomElement() ?? .gray
        let opacity = colorScheme == .dark ? 0.8 : 0.5  // Full opacity in dark mode, pale in light mode
        return randomColor.opacity(opacity)
    }
    
    private func colorForTransactionType(_ type: Transaction.TransactionType) -> Color {
        switch type {
        case .income: return Color(hex: "#4CAF50") // Green
        case .expense: return Color(hex: "#F44336") // Red
        case .investment: return Color(hex: "#2196F3") // Blue
        case .savings: return Color(hex: "#9C27B0") // Purple
        }
    }
    
    private func amountString(for transaction: Transaction) -> String {
        let prefix = transaction.type == .income || transaction.type == .investment ? "+" : "-"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US")
        
        if transaction.amount < 100_000 {
            formatter.minimumFractionDigits = transaction.amount.truncatingRemainder(dividingBy: 1) != 0 ? 2 : 0
            formatter.maximumFractionDigits = 2
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        
        let formattedAmount = formatter.string(from: NSNumber(value: transaction.amount)) ?? "\(transaction.amount)"
        return "\(prefix)$\(formattedAmount)"
    }
}
struct TransactionListView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var selectedTimePeriod: FinancialSummaryView.TimePeriod
    @State private var selectedType: Transaction.TransactionType? = nil
    @State private var showingAddTransaction = false
    @State private var isLoading = false
    
    @Binding var showDeletionNotification: Bool
    @Binding var deletionNotificationMessage: String
    @Binding var deletedTransaction: Transaction?
    
    @State private var showingAllTransactionsView = false
    @State private var showUpcomingTransactions = false
    
    @Environment(\.colorScheme) var colorScheme

    // Regular transactions (non-upcoming)
    var filteredTransactions: [Transaction] {
        let allTransactions = viewModel.allTransactions
            .filter { $0.date <= Date() }  // Only past and current transactions
        
        let transactions: [Transaction]
        if let selectedType = selectedType {
            transactions = allTransactions.filter { $0.type == selectedType }
        } else {
            transactions = allTransactions
        }
        
        let filtered: [Transaction]
        switch selectedTimePeriod {
        case .day:
            filtered = transactions.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
        case .week:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            filtered = transactions.filter { $0.date >= sevenDaysAgo }
        case .month:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            filtered = transactions.filter { $0.date >= oneMonthAgo }
        case .year:
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
            filtered = transactions.filter { $0.date >= oneYearAgo }
        case .allTime:
            filtered = transactions
        }
        
        return filtered.sorted(by: { $0.date > $1.date })
    }
    
    // Get upcoming transactions
    var upcomingTransactions: [Transaction] {
        let upcoming = viewModel.allTransactions
            .filter { $0.date > Date() }  // Only future transactions
        
        if let selectedType = selectedType {
            return upcoming.filter { $0.type == selectedType }
                .sorted(by: { $0.date < $1.date })
        } else {
            return upcoming.sorted(by: { $0.date < $1.date })
        }
    }

    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { Calendar.current.startOfDay(for: $0.date) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    
                    // View All button at the front
                    FilterButton(
                        title: "View All",
                        isSelected: false,
                        color: Color.blue
                    ) {
                        showingAllTransactionsView = true
                    }

                    // Divider for better UI separation
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)

                    // "All" filter
                    FilterButton(
                        title: "All",
                        isSelected: selectedType == nil,
                        color: Color.gray
                    ) {
                        selectedType = nil
                    }

                    // Transaction Type Filters
                    ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                        FilterButton(
                            title: type.rawValue.capitalized,
                            isSelected: selectedType == type,
                            color: colorForTransactionType(type)
                        ) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .zIndex(1)

            ZStack {
                if isLoading {
                    BouncingCirclesLoadingView()
                } else {
                    if filteredTransactions.isEmpty && upcomingTransactions.isEmpty {
                        EmptyTransactionsView(
                            title: "No Transactions Yet",
                            message: "Start tracking your finances by adding a new transaction."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TransactionListViewContent()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddTransaction) {
                AddTransactionView(
                    viewModel: viewModel,
                    isPresented: $showingAddTransaction
                )
            }
            .fullScreenCover(isPresented: $showingAllTransactionsView) {
                AllTransactionsView(
                    viewModel: viewModel,
                    isPresented: $showingAllTransactionsView
                )
            }
            .onAppear(perform: simulateLoading)
        }
    }

    @ViewBuilder
    private func TransactionListViewContent() -> some View {
        let sortedDates = groupedTransactions.keys.sorted(by: >)

        List {
            // Upcoming Transactions Section
            if !upcomingTransactions.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Upcoming")
                                .font(Font.custom("Sora-Bold", size: 15))
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.15)) {
                                    showUpcomingTransactions.toggle()
                                }
                            }) {
                                Image(systemName: showUpcomingTransactions ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                                    )
                            }
                            .padding(.trailing, 4)
                        }
                        .padding(.bottom, 6)
                        
                        if showUpcomingTransactions {
                            VStack(spacing: 12) {
                                ForEach(upcomingTransactions) { transaction in
                                    UpcomingTransactionRowView(transaction: transaction, viewModel: viewModel, colorScheme: colorScheme)
                                        .padding(.horizontal, 2)
                                }
                            }
                            .padding(.bottom, 4)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)),
                                    removal: .opacity.combined(with: .scale(scale: 0.97)).animation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2))
                                )
                            )
                        } else {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.primaryBluePurple.opacity(colorScheme == .dark ? 1.0 : 0.2))
                                    .frame(width: 8, height: 8)
                                
                                Text("\(upcomingTransactions.count) transactions in next \(calculateUpcomingWindow()) days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colorScheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#F6F6F6"))
                            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.1) : Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            
            // Regular Transactions Sections
            ForEach(sortedDates, id: \.self) { date in
                let headerText = formattedDateHeader(for: date)
                
                Section(header: Text(headerText)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray.opacity(0.5))
                ) {
                    if let transactionsForDate = groupedTransactions[date] {
                        ForEach(transactionsForDate) { transaction in
                            EnhancedTransactionRowView(transaction: transaction, viewModel: viewModel)
                                .padding(.vertical, 0)
                                .padding(.bottom, 0)
                        }
                        .onDelete { offsets in
                            deleteTransaction(at: offsets, for: date)
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func LoadingView() -> some View {
        VStack {
            BouncingCirclesLoadingView()
                .frame(width: 100, height: 100)
                .padding()
            Text("Hustle mode: activated…").font(Font.custom("Sora-Bold", size: 20))
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, -50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func simulateLoading() {
        isLoading = true
        let shouldDelay = Double.random(in: 0...1) < 0.1 // 10% chance to delay
        let randomDelay = shouldDelay ? Double.random(in: 4...8) : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
            isLoading = false
        }
    }

    private func colorForTransactionType(_ type: Transaction.TransactionType) -> Color {
        switch type {
        case .income: return Color(hex: "#4CAF50") // Green
        case .expense: return Color(hex: "#F44336") // Red
        case .investment: return Color(hex: "#2196F3") // Blue
        case .savings: return Color(hex: "#9C27B0") // Purple
        }
    }

    private func deleteTransaction(at offsets: IndexSet, for date: Date) {
        guard let transactionsForDate = groupedTransactions[date] else { return }
        
        let transactionsToDelete = offsets.map { transactionsForDate[$0] }
        
        for transaction in transactionsToDelete {
            deletedTransaction = transaction
            viewModel.deleteTransaction(transaction)
            
            deletionNotificationMessage = "Transaction Deleted"
            withAnimation {
                showDeletionNotification = true
            }
        }
    }
    
    private func formattedDateHeader(for date: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        if date == today {
            return "Today (\(formattedDate(date)))"
        } else if date == yesterday {
            return "Yesterday (\(formattedDate(date)))"
        } else {
            return formattedDate(date)
        }
    }
    
    private func calculateUpcomingWindow() -> Int {
        guard let lastDate = upcomingTransactions.last?.date else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: today, to: lastDate).day ?? 0
        return max(days, 1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func amountString(for transaction: Transaction) -> String {
        let prefix = transaction.type == .income || transaction.type == .investment ? "+" : "-"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US")
        
        if transaction.amount < 100_000 {
            formatter.minimumFractionDigits = transaction.amount.truncatingRemainder(dividingBy: 1) != 0 ? 2 : 0
            formatter.maximumFractionDigits = 2
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        
        let formattedAmount = formatter.string(from: NSNumber(value: transaction.amount)) ?? "\(transaction.amount)"
        return "\(prefix)$\(formattedAmount)"
    }
}


import SwiftUI

struct EnhancedTransactionRowView: View {
    let transaction: Transaction
    let viewModel: BudgetViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingEditSheet = false

    var isUpcoming: Bool {
        transaction.date > Date()
    }
    
    func getIconImage(named iconName: String) -> Image? {
        // Try to load an image from assets based on the icon name
        if let uiImage = UIImage(named: iconName) {
            return Image(uiImage: uiImage)
        } else {
            return nil
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                // Check if the icon is an image or text (emoji)
                let isLogo = getIconImage(named: transaction.icon) != nil
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLogo ? Color.white : randomPaleColor())  // Apply white for logos, pale for emojis
                    .frame(width: 40, height: 40)
                    .overlay(
                        Group {
                            if let iconImage = getIconImage(named: transaction.icon) {
                                // Display image
                                iconImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                // Fallback to emoji text
                                Text(transaction.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                        }
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.category)
                            .font(Font.custom("Roboto-Medium", size: 16))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        
                        if transaction.recurrence != .oneTime {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text(transaction.date, style: .time)
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                        
                        if isUpcoming {
                            Text("Upcoming")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(amountString(for: transaction))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
              
                    .background(
                        Capsule()
                            .fill(colorForTransactionType(transaction.type).opacity(0.0))
                    )
                    .foregroundColor(colorForTransactionType(transaction.type)).opacity(0.8)
                    .fontWeight(.bold)
                
                if let notes = transaction.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                        .lineLimit(1)
                        .padding(.trailing, 2)
                }
            }
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : .white)
        .cornerRadius(10)
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditSheet(transaction: transaction, viewModel: viewModel)
        }
    }


    private func randomPaleColor() -> Color {
        let colors: [Color] = [
            AppTheme.primary,
            AppTheme.accent,
            AppTheme.secondary,
            Color(hex: "8676FF"),
            Color(hex: "63C7FF")
        ]
        
        let randomColor = colors.randomElement() ?? .gray
        let opacity = colorScheme == .dark ? 0.8 : 0.5  // Full opacity in dark mode, pale in light mode
        return randomColor.opacity(opacity)
    }
    
    private func colorForTransactionType(_ type: Transaction.TransactionType) -> Color {
        switch type {
        case .income: return Color(hex: "#4CAF50") // Green
        case .expense: return Color(hex: "#F44336") // Red
        case .investment: return Color(hex: "#2196F3") // Blue
        case .savings: return Color(hex: "#9C27B0") // Purple
        }
    }
    
    private func amountString(for transaction: Transaction) -> String {
        let prefix = transaction.type == .income || transaction.type == .investment ? "+" : "-"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US")
        
        if transaction.amount < 100_000 {
            formatter.minimumFractionDigits = transaction.amount.truncatingRemainder(dividingBy: 1) != 0 ? 2 : 0
            formatter.maximumFractionDigits = 2
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        
        let formattedAmount = formatter.string(from: NSNumber(value: transaction.amount)) ?? "\(transaction.amount)"
        return "\(prefix)$\(formattedAmount)"
    }
}
import SwiftUI

extension Color {
    // 🔵 Blues (Kept your original blues)
    static let customBrightBlue = Color(hex: "#397FD4") // Bright Blue
    static let customLightBlue = Color(hex: "#66A7FF") // Light Blue
    static let customRoyalBlue = Color(hex: "#2A5BB5") // Royal Blue
    static let customPeriwinkle = Color(hex: "#B5A9E1") // Periwinkle
    
    // 🟣 Purples
    static let customViolet = Color(hex: "#8A2BE2") // Violet
    static let customLavender = Color(hex: "#C9A0DC") // Lavender
    static let customIndigo = Color(hex: "#4B0082") // Indigo
    static let customDeepPurple = Color(hex: "#673AB7") // Deep Purple

    // 🔴 Reds & Pinks
    static let customPink = Color(hex: "#FF66B2") // Bright Pink
    static let customCrimson = Color(hex: "#DC143C") // Crimson Red
    static let customCherryRed = Color(hex: "#C21807") // Cherry Red
    static let customRose = Color(hex: "#FF007F") // Rose

    // 🟠 Oranges
    static let customSunsetOrange = Color(hex: "#FF5733") // Sunset Orange
    static let customPumpkin = Color(hex: "#FF7518") // Pumpkin Orange
    static let customAmber = Color(hex: "#FFBF00") // Amber

    // 🟡 Yellows
    static let customGolden = Color(hex: "#FFD700") // Gold
    static let customSunflower = Color(hex: "#FFC300") // Sunflower Yellow
    static let customLemon = Color(hex: "#FFF44F") // Lemon Yellow

    // 🟢 Greens
    static let customLime = Color(hex: "#32CD32") // Lime Green
    static let customEmerald = Color(hex: "#50C878") // Emerald Green
    static let customTeal = Color(hex: "#008080") // Teal
    static let customForestGreen = Color(hex: "#228B22") // Forest Green

    // ⚫️ Neutrals & Dark Colors
    static let customCharcoal = Color(hex: "#36454F") // Charcoal Gray
    static let customSlateGray = Color(hex: "#708090") // Slate Gray
    static let customDeepBlack = Color(hex: "#0D0D0D") // Near Black
}

struct EmptyTransactionsView: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) var colorScheme // Detect the system color scheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Placeholder Icon with enhanced design
            Image(systemName: "tray.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100) // Increased size for better visibility
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.6)) // Adjusted opacity for better contrast
            
            // Title and Message
            VStack(spacing: 8) {
                Text(title)
                    .font(.custom("Sora-Bold", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding() // Adjust padding for overall spacing
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color.black : Color.white) // Background color based on mode
             
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, -20) // Adjust the top padding to fine-tune vertical position
    }
}
struct FilterButton: View {
    let title: String
    var isSelected: Bool
    var color: Color = .gray
    var action: () -> Void

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .soft)

    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light) // Haptic feedback
            impact.impactOccurred()
            action() // Perform the original action
        }) {
            Text(title)
                .font(.custom("Roboto-Medium", size: 14))
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isSelected
                    ? color.opacity(colorScheme == .dark ? 0.7 : 0.2)
                    : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1)
                )
                .foregroundColor(
                    isSelected
                    ? (colorScheme == .dark ? .white : color)
                    : (colorScheme == .dark ? .white : .gray)
                )
                .cornerRadius(20)
        }
    }
}

import SwiftUI

struct TransactionHeaderView: View {
    let title: String
    let onClose: () -> Void
    let onDateTap: () -> Void 

    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            // Close Button
            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "xmark")
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(8)
            }
            
            Spacer()
            
            // Clock Button (Opens Date Picker)
            Button(action: onDateTap) { // 🔹 Calls function to open date picker
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "clock")
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .font(.system(size: 18, weight: .bold))
                    
                }
                .padding(8)
            }
        }
        .padding()
        .padding(.top, 60)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
    }
}
import SwiftUI
import CoreHaptics

struct TransactionTypeSelector: View {
    @Binding var selectedType: Transaction.TransactionType
    @State private var hapticEngine: CHHapticEngine?

    // Simplified for only Expense and Income
    private let transactionTypes: [Transaction.TransactionType] = [.expense, .income]
    private let customDisplayNames: [Transaction.TransactionType: String] = [
        .expense: "Expense",
        .income: "Income"
    ]
    private let transactionIcons: [Transaction.TransactionType: String] = [
        .expense: "arrow.down.circle.fill",
        .income: "arrow.up.circle.fill"
    ]

    private func initializeHapticEngine() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed to start: \(error)")
        }
    }

    private func playCustomHaptic(for type: Transaction.TransactionType) {
        let intensity: Float = type == .expense ? 1.0 : 0.7
        let sharpness: Float = type == .expense ? 0.7 : 0.5
        let events = [
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [
                            .init(parameterID: .hapticIntensity, value: intensity),
                            .init(parameterID: .hapticSharpness, value: sharpness)
                          ],
                          relativeTime: 0)
        ]

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(transactionTypes, id: \.self) { type in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedType = type
                    }
                    playCustomHaptic(for: type)
                }) {
                    HStack {
                        Image(systemName: transactionIcons[type] ?? "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(selectedType == type ? .white : .primary)
                            .opacity(selectedType == type ? 1 : 0.7) // Slight opacity fade for unselected
                            .animation(.easeInOut(duration: 0.3), value: selectedType)

                        if selectedType == type {
                            Text(customDisplayNames[type] ?? type.rawValue.capitalized)
                                .font(.system(size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .transition(.opacity.combined(with: .move(edge: .bottom))) // Text appears from below
                                .animation(.easeInOut(duration: 0.3), value: selectedType)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(selectedType == type ? bluePurpleColor : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .scaleEffect(selectedType == type ? 1.05 : 1) // Bounce effect (slight scale increase)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedType) // Bounce on selection
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            initializeHapticEngine()
        }
    }
}

import SwiftUI

struct CategoryInputView: View {
    @Binding var category: String
    @Binding var selectedIcon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("e.g., Groceries, Rent", text: $category)
                .font(.body)
                .foregroundColor(.primary)
                .foregroundColor(.primary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .accentColor(bluePurpleColor)
                .onChange(of: category) { newValue in
                    // Check if the category matches a keyword in the mapping
                    if let matchingIcon = CategoryIconMapping.mapping[newValue.lowercased()] {
                        selectedIcon = matchingIcon
                    }
                }
        }
    }
}

// RecurrencePickerView.swift
struct RecurrencePickerView: View {
    @Binding var recurrence: Transaction.RecurrenceType
    let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Menu {
                ForEach(Transaction.RecurrenceType.allCases, id: \.self) { recurType in
                    Button(recurType.rawValue.capitalized) {
                        hapticFeedback.impactOccurred()
                        recurrence = recurType
                    }
                }
            } label: {
                HStack {
                    Text(recurrence.rawValue.capitalized)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}

// NotesInputView.swift
struct NotesInputView: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("e.g., Payment details, Location", text: $notes)                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .accentColor(bluePurpleColor)
        }
    }
}

import SwiftUI

struct IconSelectorView: View {
    @Binding var selectedIcon: String
    let hapticFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    // Unified icons array (including emojis and custom logos)
    let icons = [
        "💵", "🍎", "☕", "🎉", "🏠", "🎁", "💳", "🛒", "👟", "🚗",
        "🏦", "💡", "📱", "🧳", "🍽️", "🚕", "🏋️‍♀️", "🛏️", "📚",
        "🖥️", "🎮", "💍", "🐶", "🐱", "🐰",
        "spotify_logo", "amazon_logo", "apple_music_logo", "peletonlogo_logo", "netflix_logo", "adobecloud_logo", "newdisney_logo"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text("Select Icon")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Scrollable icon row with ScrollViewReader
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: {
                                hapticFeedback.impactOccurred()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedIcon = icon
                                    proxy.scrollTo(icon, anchor: .center) // Scroll to selected icon
                                }
                            }) {
                                // Icon background
                                ZStack {
                                    RoundedRectangle(cornerRadius: 52)
                                        .fill(selectedIcon == icon ? bluePurpleColor : Color.gray.opacity(0.2))  // Adjust selected icon color
                                        .frame(width: 50, height: 50)
                                    
                                    // Conditionally display either an emoji or image
                                    if icon.contains("_logo") {
                                        Image(icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24) // Adjust size as needed
                                            .foregroundColor(selectedIcon == icon ? .white : .primary)
                                    } else {
                                        Text(icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIcon == icon ? .white : .primary)  // Adjust text color
                                    }
                                }
                                .scaleEffect(selectedIcon == icon ? 1.2 : 1.0) // Slight scale effect on selection
                                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5), value: selectedIcon) // Smooth bounce effect
                            }
                            .id(icon) // Assign unique ID for scrolling
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .onChange(of: selectedIcon) { newIcon in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIcon, anchor: .center) // Scroll when icon is changed externally
                    }
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 5)
        .cornerRadius(16)  // Rounded container
    }
}

import SwiftUI

struct SaveButtonView: View {
    let onSave: () -> Void
    let isEnabled: Bool
    let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            hapticFeedback.impactOccurred()
            onSave()
        }) {
            Text("Save Transaction")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundView) // Using the custom background view
                .cornerRadius(16)
        }
        .disabled(!isEnabled)
        .padding()
    }
    
    // Custom background view for the button
    private var backgroundView: some View {
        Group {
            if isEnabled {
                Color.primaryBluePurple // Flat yellow color when enabled
            } else {
                Color.secondary.opacity(0.3) // Greyed-out color when disabled
            }
        }
    }
}
import SwiftUI
import UIKit

// Haptic Feedback Wrapper
struct HapticFeedback {
    static func generateImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
import SwiftUI
import UIKit

struct AddTransactionView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool

    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var type: Transaction.TransactionType = .expense
    @State private var recurrence: Transaction.RecurrenceType = .oneTime
    @State private var notes: String = ""
    @State private var selectedIcon: String = "💵"
    @State private var showDecimalPad: Bool = false
    @State private var keyframeBounce: Bool = false
    @State private var selectedDate: Date = Date() // ✅ Stores selected date
    @State private var isDatePickerPresented = false // ✅ Controls date picker visibility
    @Environment(\.colorScheme) var colorScheme

    private let decimalButtons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]
    private func formatAmountWithCommas(_ value: String) -> String {
        let filteredValue = value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        let components = filteredValue.components(separatedBy: ".")
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        numberFormatter.maximumFractionDigits = 2
        
        var integerPart = components[0]
        if integerPart.count > 6 {
            integerPart = String(integerPart.prefix(6))
        }
        
        var formattedInteger = numberFormatter.string(from: NSNumber(value: Int(integerPart) ?? 0)) ?? ""
        
        if components.count > 1 {
            let decimalPart = String(components[1].prefix(2)) // Always allow up to 2 decimal places
            formattedInteger += "." + decimalPart
        }
        
        return formattedInteger.isEmpty ? "" : "$" + formattedInteger
    }

    private func fontSizeForAmount() -> CGFloat {
        let length = amount.count
        switch length {
        case 0...5:
            return 58
        case 6...8:
            return 48
        default:
            return 38
        }
    }
    
    private func isZeroAmount() -> Bool {
        return amount.isEmpty || amount == "0" || amount == "$0.00"
    }
    

    var body: some View {
        VStack(spacing: 0) {
            TransactionHeaderView(
                title: "Add Transaction",
                onClose: { isPresented = false },
                onDateTap: { isDatePickerPresented.toggle() } // ✅ Opens date picker
            )
            
            TransactionTypeSelector(selectedType: $type)
                .padding(.top, -70)
            
            // Amount Input Section
            HStack {
                Spacer()
                ZStack {
                    HStack {
                        Text(type == .expense ? "-" : "+")
                            .font(.custom("Sora-Bold", size: 58))
                            .foregroundColor(.gray.opacity(0.3))
                            .offset(x: 16)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: type)
                        
                        Spacer()
                    }
                    
                    Text(isZeroAmount() ? "$0.00" : formatAmountWithCommas(amount))
                        .font(.custom("Sora-Bold", size: fontSizeForAmount()))
                        .foregroundColor(isZeroAmount() ? .gray.opacity(0.3) : .primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .scaleEffect(keyframeBounce ? 1.05 : 1)
                        .animation(.interpolatingSpring(stiffness: 120, damping: 5), value: keyframeBounce)
                }
            }
            .padding(.top, 50)
            .padding(.bottom, 70)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.trailing, 10)
            
            // Decimal Pad Toggle Button
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showDecimalPad.toggle()
                    }
                    HapticFeedback.generateImpact(style: showDecimalPad ? .medium : .rigid)
                }) {
                    HStack {
                        Image(systemName: showDecimalPad ? "checkmark.circle.fill" : "viewfinder.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(showDecimalPad ? .white : .primary)
                            .scaleEffect(showDecimalPad ? 1.1 : 1.0)
                            .opacity(showDecimalPad ? 1.0 : 0.8)
                            .animation(.easeInOut(duration: 0.3), value: showDecimalPad)
                        
                        Text(showDecimalPad ? "Done" : "Decimal Pad")
                            .font(.system(size: 16))
                            .foregroundColor(showDecimalPad ? .white : .primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(showDecimalPad ? 1 : 0.9)
                            .scaleEffect(showDecimalPad ? 1.05 : 1.0)
                            .padding(.trailing, 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(showDecimalPad ? Color(hex: "#4CAF50") : Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .frame(width: showDecimalPad ? 270 : 310)
                    .animation(.easeInOut(duration: 0.3), value: showDecimalPad)
                }
                .padding(.bottom, 16)
            }
            
            ZStack {
                if !showDecimalPad {
                    VStack(spacing: 15) {
                        CategoryInputView(category: $category, selectedIcon: $selectedIcon)
                            .padding(.horizontal, 40)
                            .frame(height: 70)
                        
                        RecurrencePickerView(recurrence: $recurrence)
                            .padding(.horizontal, 40)
                            .frame(height: 70)
                        
                        NotesInputView(notes: $notes)
                            .padding(.horizontal, 40)
                            .frame(height: 70)
                        
                        IconSelectorView(selectedIcon: $selectedIcon)
                            .padding(.horizontal, 40)
                            .frame(height: 70)
                    }
                    .padding(.bottom, 25)
                    .transition(.opacity.combined(with: .scale(scale: 0.9))) // Smooth fade and scale effect
                }
                
                if showDecimalPad {
                    decimalPadView()
                        .padding(.bottom, 20)
                        .frame(height: 350)
                        .transition(.opacity.combined(with: .scale(scale: 1.1))) // Smooth fade and scale effect
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showDecimalPad) // Smooth animation for transition
            
            // Save Button
            SaveButtonView(
                onSave: {
                    let cleanedAmount = amount.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
                    
                    if let amountValue = Double(cleanedAmount), !category.isEmpty, amountValue > 0 {
                        let transaction = Transaction(
                            amount: amountValue,
                            category: category,
                            type: type,
                            recurrence: recurrence,  // ✅ Correct: recurrence is of type `RecurrenceType`
                            notes: notes.isEmpty ? nil : notes,  // ✅ Correct: notes is `String?`
                            icon: selectedIcon,  // ✅ Correct: selectedIcon is `String`
                            date: selectedDate  // ✅ Correct: selectedDate is `Date`
                        )
                        
                        viewModel.addTransaction(transaction)
                        isPresented = false
                    } else {
                        print("Invalid transaction. Amount must be greater than $0.")
                    }
                },
                isEnabled: !amount.isEmpty && !category.isEmpty && !isZeroAmount()
            )
            .padding(.bottom, 30)
            .padding(.horizontal, 20)
        }
        .background(Color("BackgroundColor"))
        .edgesIgnoringSafeArea(.all)
        .foregroundColor(.primary)
        
        .overlay(
            ZStack {
                if isDatePickerPresented {
                    // Background Overlay with Dynamic Opacity for Dark Mode
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture { isDatePickerPresented = false }
                    
                    VStack(spacing: 16) {
                        // Header with Close Button (X)
                        HStack {
                            // Close Button
                            Button(action: { isDatePickerPresented = false }) {
                                ZStack {
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                                        .frame(width: 30, height: 30)
                                    
                                    Image(systemName: "xmark")
                                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(8)
                            }
                            
                            Spacer()
                        }
                        .padding(.leading, 1) // Align to left
                        // Title
                                        Text("Select Date & Time")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color(UIColor.label)) // Adapts to Light/Dark Mode
                                            .padding(.vertical, -50)
                        
                        // Graphical Date & Time Picker
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground)) // Adaptive BG
                        .cornerRadius(20)
                        .accentColor(bluePurpleColor)
                        
                        // Confirm Button
                        Button(action: {
                            isDatePickerPresented = false
                        }) {
                            Text("Confirm")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bluePurpleColor)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .frame(width: 340)
                        }
                        .padding(.horizontal)
                    }
                    .frame(width: 340)
                    .padding()
                    .background(Color(UIColor.systemBackground)) // Adaptive Background
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 8)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDatePickerPresented)
                }
            }
        )
    }
        private func decimalPadView() -> some View {
        VStack(spacing: 15) {
            ForEach(decimalButtons, id: \.self) { row in
                HStack(spacing: 15) {
                    ForEach(row, id: \.self) { button in
                        Button(action: {
                            handleDecimalButton(button)
                            HapticFeedback.generateImpact(style: .light)
                        }) {
                            Text(button)
                                .font(.system(size: 24, weight: .semibold))
                                .frame(width: 80, height: 70)
                                .background(Color.gray.opacity(0.1))  // Adjust background for dark mode
                                .cornerRadius(12)
                                .foregroundColor(.primary)  // Primary text color for light and dark modes
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func handleDecimalButton(_ button: String) {
        switch button {
        case "⌫":
            if !amount.isEmpty {
                if amount.last == "." {
                    amount.removeLast()
                } else {
                    amount.removeLast()
                }
            }
        case ".":
            if !amount.contains(".") {
                amount += button
            }
        default:
            if amount == "0" {
                amount = button
            } else if amount.count < 15 {
                amount += button
            }
        }
        
        withAnimation {
            keyframeBounce.toggle()
        }
        
        amount = formatAmountWithCommas(amount)
    }
}

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation

    let tabs = [
        (icon: "dollarsign.circle", title: "Dashboard"),
        (icon: "chart.bar", title: "Charts"),
        (icon: "target", title: "Goals")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(tabs.indices, id: \.self) { index in
                TabBarButton(
                    isSelected: selectedTab == index,
                    icon: tabs[index].icon,
                    title: tabs[index].title,
                    namespace: animation,
                    onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 60) // Adjusted height
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8) // Reduced bottom padding
    }
}
struct TabBarButton: View {
    let isSelected: Bool
    let icon: String
    let title: String
    let namespace: Namespace.ID
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12) // Smaller corner radius
                        .fill(bluePurpleColor.opacity(0.2)) // More subtle background
                        .matchedGeometryEffect(id: "background", in: namespace)
                        .transition(.scale) // Smoother animation
                }

                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22) // Adjusted size
                    .foregroundColor(isSelected ? bluePurpleColor : .gray.opacity(0.6))
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
            .frame(width: 50, height: 40) // Adjusted size
        }
        .buttonStyle(TactileButtonStyle(isPressed: $isPressed))
    }
}
struct TactileButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var budgetViewModel = BudgetViewModel()
    @State private var selectedTab = 0
    @State private var showingAddTransaction = false
    @State private var showingWeeklyStory = false
    @State private var selectedTimePeriod: FinancialSummaryView.TimePeriod = .month
    @State private var showDeletionNotification = false
    @State private var deletionNotificationMessage = ""
    @State private var deletedTransaction: Transaction?
    @State private var showingAllTransactionsView = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") // Checks if onboarding is needed
    
    
    
    
    //Floating Action Button Additions
    private let childButtonColor = Color(red: 0.6, green: 0.5, blue: 0.9)
    @State private var isLongPressing = false
    @State private var showingChildButton = false
    @State private var autoHideTimer: Timer?
    @State private var showingReceiptScanner = false
    @State private var offset = CGSize.zero
    @State private var childButtonHighlighted = false
    

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding") // Mark onboarding as seen
                    showOnboarding = false
                }
            } else {
                TabView(selection: $selectedTab) {
                    // Overview Tab
                    NavigationView {
                        VStack {
                            Image("SmartStash Logo (2)")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 170, height: 30)
                                .padding(.top, -28)
                                .padding(.leading, 32)
                                .padding(.trailing, 230)
                                .padding(.bottom, -200)
                            
                            FinancialSummaryView(
                                viewModel: budgetViewModel,
                                selectedTimePeriod: $selectedTimePeriod
                            )
                            .padding(.vertical, -8)
                            
                            TransactionListView(
                                viewModel: budgetViewModel,
                                selectedTimePeriod: $selectedTimePeriod,
                                showDeletionNotification: $showDeletionNotification,
                                deletionNotificationMessage: $deletionNotificationMessage,
                                deletedTransaction: $deletedTransaction
                            )
                            .padding(.vertical, -4)
                        }
                        .navigationBarItems(
                            trailing: HStack(spacing: 0) {
                                timePeriodMenu
                            }
                        )
                    }
                    .tabItem {
                        Label("Overview", systemImage: "dollarsign.bank.building.fill")
                    }
                    .tag(0)
                    
                    // Goals Tab
                    NavigationView {
                        FinancialGoalsView()
                    }
                    .tabItem {
                        Label("Goals", systemImage: "trophy.fill")
                    }
                    .tag(1)
                    
              
                    NavigationView {
                        InsightsView(viewModel: budgetViewModel)
                    }
                    .tabItem {
                        Label("Insights", systemImage: "chart.pie.fill")
                    }
                    .tag(2)
                    
                    // Settings Tab
                    NavigationView {
                        SettingsView()
                            .environmentObject(BudgetViewModel())
                    }
                    .tabItem {
                        Label("More", systemImage: "line.horizontal.3")
                    }
                    .tag(3)
                }
                
                .accentColor(bluePurpleColor)
                .fullScreenCover(isPresented: $showingAddTransaction) {
                    AddTransactionView(
                        viewModel: budgetViewModel,
                        isPresented: $showingAddTransaction
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                .fullScreenCover(isPresented: $showingAllTransactionsView) {
                    AllTransactionsView(viewModel: budgetViewModel, isPresented: $showingAllTransactionsView)
                }
                .fullScreenCover(isPresented: $showingWeeklyStory) {
                    WeeklyStoryView(stories: generateWeeklyStories(), showStories: $showingWeeklyStory)
                }
                
                //Floating Action Button is only appearing on the overview page now
                if selectedTab == 0 {
                    floatingActionButton
                }
                deletionNotificationView
            }
        }
        
        .sheet(isPresented: $showingReceiptScanner) {
            ReceiptScannerView(viewModel: budgetViewModel, isPresented: $showingReceiptScanner)
        }
    }


    private var weeklyStoryButton: some View {
        Button(action: { showingWeeklyStory = true }) {
            Image(systemName: "book")
                .fontWeight(.medium)
                .font(.system(size: 12)) // ✅ Make the icon larger
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .opacity(0.8)
                .padding(8)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32) // ✅ Keep the circle the same size
                )
        }
        .padding(.top, 10)
    }
    
    func generateWeeklyStories() -> [FinancialStory] {
        let transactions = budgetViewModel.transactions

        // Find the biggest expense
        let biggestExpense = transactions
            .filter { $0.type == .expense }
            .max(by: { $0.amount < $1.amount })

        // Find the biggest income
        let biggestIncome = transactions
            .filter { $0.type == .income }
            .max(by: { $0.amount < $1.amount })

        // Calculate total spent (sum of all expense transactions)
        let totalSpent = transactions
            .filter { $0.type == .expense }
            .map { $0.amount }
            .reduce(0, +)

        // 📅 Estimate total spending for the month
        let daysElapsed = Calendar.current.component(.day, from: Date())
        let totalDaysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        let projectedSpending = (Double(totalSpent) / Double(daysElapsed)) * Double(totalDaysInMonth)

        // 📈 Compare spending with last week's spending
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let lastWeekSpent = transactions
            .filter { $0.type == .expense && $0.date >= oneWeekAgo }
            .map { $0.amount }
            .reduce(0, +)

        let spendingChange = totalSpent - lastWeekSpent
        let spendingTrend = spendingChange > 0 ? "You're spending more than last week." : "You're spending less than last week."
        
        return [
            FinancialStory(
                title: "Biggest Expense",
                value: biggestExpense != nil ? "$\(biggestExpense!.amount)" : "No Data",
                change: biggestExpense?.category ?? "No Category",
                isPositive: false,
                emoji: "💸",
                backgroundColor: .red.opacity(0.2)
            ),
            FinancialStory(
                title: "Biggest Income",
                value: biggestIncome != nil ? "$\(biggestIncome!.amount)" : "No Data",
                change: biggestIncome?.category ?? "No Category",
                isPositive: true,
                emoji: "💰",
                backgroundColor: .green.opacity(0.2)
            ),
            FinancialStory(
                title: "Total Spent",
                value: totalSpent > 0 ? "$\(totalSpent)" : "No Data",
                change: "This Week",
                isPositive: false,
                emoji: "📉",
                backgroundColor: .blue.opacity(0.2)
            ),
            FinancialStory(
                title: "Projected Monthly Spending",
                value: "$\(String(format: "%.2f", projectedSpending))",
                change: "At this rate, you'll spend this much this month.",
                isPositive: false,
                emoji: "📅",
                backgroundColor: .orange.opacity(0.2)
            ),
            FinancialStory(
                title: "Spending Trend",
                value: spendingChange != 0 ? "$\(String(format: "%.2f", abs(spendingChange)))" : "No Change",
                change: spendingTrend,
                isPositive: spendingChange < 0,
                emoji: spendingChange < 0 ? "📉" : "📈",
                backgroundColor: spendingChange < 0 ? .green.opacity(0.2) : .red.opacity(0.2)
            )
        ]
    }
    
    private var floatingActionButton: some View {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        // Child camera button - only shown after long press
                        if showingChildButton {
                            Button(action: {}) { // Empty action - handled by gestures
                                Image(systemName: "text.viewfinder")
                                    .foregroundStyle(.white)
                                    .font(.headline)
                                    .padding(12)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.purple,
                                                Color(red: 0.5, green: 0.2, blue: 0.8) // A fun purple shade
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .scaleEffect(childButtonHighlighted ? 1.1 : 1.0)
                                    .shadow(radius: 5)
                            }
                            .offset(x: 0, y: -70) // Position above main button
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Main button with separate gesture handlers
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .font(.title)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [bluePurpleColor, bluePurpleColor.opacity(0.6)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(Circle())
                            .scaleEffect(isLongPressing ? 1.1 : 1.0)
                            .shadow(radius: 10)
                            // Tap gesture - immediately open add transaction view
                            .onTapGesture {
                                // Provide light tap haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                
                                // Only show transaction view, don't show child button
                                showingAddTransaction = true
                            }
                            // Long press gesture - show child button
                            .onLongPressGesture(minimumDuration: 2.0, pressing: { isPressing in
                                if isPressing {
                                    // Provide medium haptic feedback when starting long press
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isLongPressing = true
                                        showChildButton()
                                    }
                                } else if isLongPressing {
                                    // Released without sliding to child button
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isLongPressing = false
                                        // Don't hide child button yet, use timer
                                        startAutoHideTimer()
                                    }
                                }
                            }, perform: {
                                // Nothing needed here - we handle everything in pressing parameter
                            })
                            // Drag gesture - only active when long pressing
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 10)
                                    .onChanged { value in
                                        // Only process drag if we're long pressing
                                        if isLongPressing && showingChildButton {
                                            // Check if dragged up to child button (negative y is upward)
                                            let isOverChildButton = value.translation.height < -50
                                            
                                            // Provide subtle haptic feedback when crossing threshold
                                            if isOverChildButton != childButtonHighlighted {
                                                let generator = UIImpactFeedbackGenerator(style: .soft)
                                                generator.impactOccurred()
                                            }
                                            
                                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                                childButtonHighlighted = isOverChildButton
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        if isLongPressing && showingChildButton {
                                            let isOverChildButton = value.translation.height < -50
                                            
                                            if isOverChildButton {
                                                // If finger released over child button, trigger receipt scanner
                                                // Provide success haptic feedback
                                                let generator = UINotificationFeedbackGenerator()
                                                generator.notificationOccurred(.success)
                                                
                                                showingReceiptScanner = true
                                                
                                                // Reset all states
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                                    childButtonHighlighted = false
                                                    isLongPressing = false
                                                    hideChildButton()
                                                }
                                            } else {
                                                // Reset highlight state but keep child button visible temporarily
                                                childButtonHighlighted = false
                                                startAutoHideTimer()
                                            }
                                        }
                                    }
                            )
                    }
                    .padding()
                    .padding(.trailing, -4)
                    .padding(.bottom, 50)
                }
            }
        }
    // Function to show child button
    private func showChildButton() {
        // Cancel any existing timer
        autoHideTimer?.invalidate()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.1)) {
            showingChildButton = true
        }
    }

    // Function to start the auto-hide timer
    private func startAutoHideTimer() {
        // Create new timer to auto-hide after 3 seconds
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            hideChildButton()
        }
    }

    // Function to hide child button with animation
    private func hideChildButton() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.1)) {
            showingChildButton = false
            childButtonHighlighted = false
            isLongPressing = false
        }
    }
    private var deletionNotificationView: some View {
        VStack {
            if showDeletionNotification {
                NotificationBanner(
                    icon: "arrow.uturn.left.circle.fill",
                    title: deletionNotificationMessage,
                    subtitle: "Tap to undo",
                    onClose: {
                        withAnimation(.easeOut(duration: 0.35)) {
                            showDeletionNotification = false
                        }
                    },
                    onTap: undoDeleteTransaction
                )
                .transition(
                    .asymmetric(
                        insertion: AnyTransition.scale(scale: 0.95)
                            .combined(with: .move(edge: .top))
                            .combined(with: .opacity),
                        removal: AnyTransition.opacity
                            .animation(.easeOut(duration: 0.25))
                    )
                )
                .zIndex(1)
                .task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation(.easeOut(duration: 0.35)) {
                        showDeletionNotification = false
                    }
                }
                
                Spacer() // This pushes the notification to the top
            }
        }
        .animation(
            .interpolatingSpring(
                mass: 0.8,
                stiffness: 100,
                damping: 15,
                initialVelocity: 0.5
            ),
            value: showDeletionNotification
        )
    }

    /// Reusable notification banner component with consistent styling
    struct NotificationBanner: View {
        let icon: String
        let title: String
        let subtitle: String
        let onClose: () -> Void
        let onTap: () -> Void
        
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.red)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.red.opacity(0.15)))
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ?
                          Color.black.opacity(0.85) :
                          Color.white)
                    .shadow(color: colorScheme == .dark ?
                            .black.opacity(0.25) :
                            .black.opacity(0.1),
                            radius: 10, y: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .padding(.horizontal)
        }
    }

    private var timePeriodMenu: some View {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

        return Menu {
            ForEach(FinancialSummaryView.TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    feedbackGenerator.impactOccurred(intensity: 0.7)
                    selectedTimePeriod = period
                }) {
                    Text(period.rawValue.capitalized)
                        .font(.system(size: 14))
                        .foregroundColor(selectedTimePeriod == period ? .primary : .gray)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedTimePeriod.rawValue.capitalized)
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.top, 16) // Moves it further down
            .padding(.trailing, 2) // Moves it slightly away from the trailing edge
            .padding(.vertical, 2)
            .onTapGesture {
                feedbackGenerator.prepare()
                feedbackGenerator.impactOccurred(intensity: 0.5)
            }
            .overlay(
                Rectangle()
                    .frame(height: 0)
                    .foregroundColor(.gray.opacity(0.5))
                    .offset(y: 18) // Moves underline lower for balance
            )
        }
    }

    private func undoDeleteTransaction() {
        guard let transaction = deletedTransaction else { return }
        budgetViewModel.transactions.append(transaction)
        budgetViewModel.transactions.sort { $0.date > $1.date }
        budgetViewModel.saveTransactions()
        withAnimation { showDeletionNotification = false }
        deletedTransaction = nil
    }
}

let bluePurpleColor = Color(red: 87/255, green: 113/255, blue: 255/255)
#Preview {
    ContentView()
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
