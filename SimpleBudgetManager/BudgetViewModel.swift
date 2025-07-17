//
//  BudgetViewModel.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 5/24/25.
//


import SwiftUI

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
           date: Date = Date()
       ) {
           self.id = UUID()
           self.amount = amount
           self.category = category
           self.type = type
           self.recurrence = recurrence
           self.notes = notes
           self.icon = icon
           self.date = date
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

