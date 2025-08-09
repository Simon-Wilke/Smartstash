//
//  TransactionEditSheet.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 5/25/25.
//

import SwiftUI
import Charts


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
    
    // Currency formatter
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // Change to your preferred currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .foregroundColor(colorScheme == .dark ? .white : .gray)
                        .fontWeight(.semibold)
                }
                .padding(8)
                
                
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
                        
                        TextField("Enter amount", value: $transaction.amount, formatter: currencyFormatter)
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
