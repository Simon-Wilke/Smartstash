//
//  FinancialGoalsView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 3/1/25.
//
import SwiftUI
import Combine

// Enhanced Goal Model with More Robust Features
struct FinancialGoal: Identifiable, Codable {
    let id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date
    var iconName: String
    var category: GoalCategory
    var transactions: [Transaction]
    
    enum GoalCategory: String, Codable, CaseIterable {
        case travel = "Travel"
        case vehicle = "Vehicle"
        case electronics = "Electronics"
        case homeImprovement = "Home"
        case education = "Education"
        case personal = "Personal"
        case retirement = "Retirement"
        case emergency = "Emergency Fund"
        case other = "Other"
    }
    
    struct Transaction: Identifiable, Codable {
        let id: UUID
        let amount: Double
        let date: Date
        let note: String?
        
        init(amount: Double, note: String? = nil) {
            self.id = UUID()
            self.amount = amount
            self.date = Date()
            self.note = note
        }
    }
    
    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        let progress = (currentAmount / targetAmount) * 100
        
        // Ensure we don't return NaN or infinity
        if progress.isNaN || progress.isInfinite {
            return 0
        }
        
        // Cap at 100% but allow going over for display purposes
        return max(progress, 0)
    }
    
    var daysRemaining: Int {
        max(Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0, 0)
    }
    
    var status: GoalStatus {
        switch progressPercentage {
        case 100...: return .completed
        case 75..<100: return .almostThere
        case 25..<75: return .inProgress
        case 0..<25: return .justStarted
        default: return .notStarted
        }
    }
    
    // Add a computed property to show if goal is over target
    var isOverTarget: Bool {
        return currentAmount > targetAmount
    }
    
    // Add a property to get the excess amount
    var excessAmount: Double {
        return max(currentAmount - targetAmount, 0)
    }
    
    enum GoalStatus {
        case completed
        case almostThere
        case inProgress
        case justStarted
        case notStarted
    }
    
    init(name: String, targetAmount: Double, currentAmount: Double = 0, targetDate: Date, iconName: String, category: GoalCategory) {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.iconName = iconName
        self.category = category
        self.transactions = []
    }
}

class FinancialGoalsViewModel: ObservableObject {
    @Published var goals: [FinancialGoal] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Computed Properties for Dashboard Insights
    var totalGoalsValue: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }
    
    var totalCurrentSavings: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }
    
    var completedGoalsCount: Int {
        goals.filter { $0.progressPercentage >= 100 }.count
    }
    
    init() {
        loadGoals()
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        $goals
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveGoals()
            }
            .store(in: &cancellables)
    }
    
    func addGoal(_ goal: FinancialGoal) {
        goals.append(goal)
    }
    
    func updateGoalProgress(id: UUID, amount: Double, note: String? = nil) {
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.goals.firstIndex(where: { $0.id == id }) {
                // Update the goal
                self.goals[index].currentAmount += amount
                self.goals[index].transactions.append(
                    FinancialGoal.Transaction(amount: amount, note: note)
                )
                
                // Force a UI update
                self.objectWillChange.send()
                
                print("Updated goal: \(self.goals[index].name)")
                print("New current amount: \(self.goals[index].currentAmount)")
                print("Progress: \(self.goals[index].progressPercentage)%")
            }
        }
    }
    
    func deleteTransaction(goalId: UUID, transactionId: UUID) {
        if let goalIndex = goals.firstIndex(where: { $0.id == goalId }),
           let transactionIndex = goals[goalIndex].transactions.firstIndex(where: { $0.id == transactionId }) {
            // Get the transaction amount before removing it
            let transactionAmount = goals[goalIndex].transactions[transactionIndex].amount
            
            // Remove the transaction
            goals[goalIndex].transactions.remove(at: transactionIndex)
            
            // Update the current amount by subtracting the transaction amount
            goals[goalIndex].currentAmount -= transactionAmount
        }
    }
    
    func deleteGoal(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
    }
    
    private func saveGoals() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(goals)
            UserDefaults.standard.set(data, forKey: "financialGoals")
        } catch {
            print("Failed to save financial goals: \(error)")
        }
    }
    
    private func loadGoals() {
        guard let data = UserDefaults.standard.data(forKey: "financialGoals") else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            goals = try decoder.decode([FinancialGoal].self, from: data)
        } catch {
            print("Failed to load financial goals: \(error)")
        }
    }
}

struct GoalTransactionsView: View {
    @ObservedObject var viewModel: FinancialGoalsViewModel
    let goal: FinancialGoal
    @Environment(\.colorScheme) var colorScheme
    
    // Number formatter for currency display
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if goal.transactions.isEmpty {
                    VStack(spacing: 30) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 80))
                            .foregroundColor(bluePurpleColor)
                        
                        VStack(spacing: 12) {
                            Text("No transactions yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text("Start contributing to see your transaction history here")
                                .font(.body)
                                .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(goal.transactions.sorted(by: { $0.date > $1.date })) { transaction in
                            TransactionRowView(transaction: transaction, viewModel: viewModel, goalId: goal.id)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Transaction History")
        .navigationBarTitleDisplayMode(.large)
    }
    
}

struct TransactionRowView: View {
    let transaction: FinancialGoal.Transaction
    let viewModel: FinancialGoalsViewModel
    let goalId: UUID
    @Environment(\.colorScheme) var colorScheme
    
    // Number formatter for currency display
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 16) {
            // Amount circle
            ZStack {
                Circle()
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "plus")
                    .foregroundColor(.green)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("+\(currencyFormatter.string(from: NSNumber(value: transaction.amount)) ?? "$0.00")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                }
                
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                }
                
                Text(transaction.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteTransaction(goalId: goalId, transactionId: transaction.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct GoalDetailsView: View {
    @ObservedObject var viewModel: FinancialGoalsViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    @State private var contributionAmount: String = ""
    @State private var transactionNote: String = ""
    @State private var showDeleteConfirmation = false
    
    let goalId: UUID // Change this to just store the ID
    
    // Computed property that gets the current goal from the viewModel
    private var goal: FinancialGoal? {
        viewModel.goals.first { $0.id == goalId }
    }
    
    // Number formatter for currency display
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // Number formatter for parsing user input (handles commas, currency symbols, etc.)
    private let inputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return formatter
    }()
    
    var body: some View {
        Group {
            if let goal = goal {
                ZStack {
                    Color(colorScheme == .dark ? .black : .white)
                        .ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 30) {
                            goalHeroSection(goal: goal)
                            progressCardSection(goal: goal)
                            statsGridSection(goal: goal)
                            contributionCardSection
                            actionsSection(goal: goal)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Goal not found")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Hero Section
    private func goalHeroSection(goal: FinancialGoal) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(bluePurpleColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Text(goal.iconName)
                    .font(.system(size: 45))
            }
            
            VStack(spacing: 12) {
                Text(goal.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
                
                Text(goal.category.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Progress Card
    private func progressCardSection(goal: FinancialGoal) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text("Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                Text("\(String(format: "%.1f", goal.progressPercentage))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor(for: goal))
            }
            
            VStack(spacing: 16) {
                ProgressBarView(
                    progress: goal.progressPercentage / 100,
                    color: progressColor(for: goal)
                )
                .frame(height: 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                        Text(currencyFormatter.string(from: NSNumber(value: goal.currentAmount)) ?? "$0")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                        Text(currencyFormatter.string(from: NSNumber(value: goal.targetAmount)) ?? "$0")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Stats Grid
    private func statsGridSection(goal: FinancialGoal) -> some View {
        HStack(spacing: 16) {
            StatCardView(
                icon: "calendar",
                title: "Target Date",
                value: goal.targetDate,
                style: .date,
                color: bluePurpleColor
            )
            
            StatCardView(
                icon: "clock",
                title: "Days Left",
                value: "\(goal.daysRemaining)",
                color: goal.daysRemaining < 30 ? .red : bluePurpleColor
            )
        }
    }
    
    // MARK: - Contribution Card
    private var contributionCardSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Contribution")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            ModernContributionInputView(
                amount: $contributionAmount,
                note: $transactionNote,
                onAddContribution: addContribution
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func actionsSection(goal: FinancialGoal) -> some View {
        VStack(spacing: 16) {
            // Transaction History Button
            NavigationLink(destination: GoalTransactionsView(viewModel: viewModel, goal: goal)) {
                HStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(bluePurpleColor)

                    Text("Transaction History")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.6))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 3, x: 0, y: 1)
                )
            }

            // Delete Goal Button
            Button(action: { showDeleteConfirmation = true }) {
                HStack(spacing: 16) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .foregroundColor(.red)

                    Text("Delete Goal")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 3, x: 0, y: 1)
                )
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Goal"),
                    message: Text("Are you sure you want to delete this goal? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteGoalConfirmed()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    
    
    private func progressColor(for goal: FinancialGoal) -> Color {
        switch goal.status {
        case .completed: return .green
        case .almostThere: return bluePurpleColor
        case .inProgress: return bluePurpleColor
        case .justStarted: return .orange
        case .notStarted: return .red
        }
    }
    
    private var isValidContribution: Bool {
        let cleanAmount = contributionAmount
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard !cleanAmount.isEmpty, let amount = Double(cleanAmount) else { return false }
        return amount > 0
    }
    
    private func addContribution() {
        // Clean the input: remove $, commas, and whitespace
        let cleanAmount = contributionAmount
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Check if empty
        guard !cleanAmount.isEmpty else {
            print("❌ Empty amount")
            return
        }
        
        // Convert to Double - this handles decimals properly
        guard let amount = Double(cleanAmount), amount > 0 else {
            print("❌ Invalid amount: '\(contributionAmount)' -> '\(cleanAmount)'")
            return
        }
        
        print("✅ Adding $\(amount) to goal")
        
        // Update the goal
        viewModel.updateGoalProgress(
            id: goalId,
            amount: amount,
            note: transactionNote.isEmpty ? nil : transactionNote
        )
        
        // Clear the form
        contributionAmount = ""
        transactionNote = ""
    }
    
    private func deleteGoalConfirmed() {
        guard let index = viewModel.goals.firstIndex(where: { $0.id == goalId }) else { return }
        
        viewModel.deleteGoal(at: IndexSet([index]))
        presentationMode.wrappedValue.dismiss()
    }
}
// MARK: - Supporting Views

struct StatCardView: View {
    let icon: String
    let title: String
    let value: Any
    var style: Text.DateStyle?
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(height: 24)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                
                Group {
                    if let date = value as? Date, let style = style {
                        Text(date, style: style)
                    } else if let stringValue = value as? String {
                        Text(stringValue)
                    } else {
                        Text("--")
                    }
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }
}

struct ProgressBarView: View {
    let progress: CGFloat
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.2))

                Capsule()
                    .fill(color)
                    .frame(width: max(geometry.size.width * min(progress, 1.0), 0))
                    .animation(.easeInOut(duration: 0.8), value: progress)
            }
        }
    }
}


struct ModernContributionInputView: View {
    @Binding var amount: String
    @Binding var note: String
    let onAddContribution: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    // Internal state for formatted display
    @State private var displayAmount: String = ""
    
   
    // Number formatter for currency display
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Text("$")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                
                TextField("0.00", text: $displayAmount)
                    .font(.custom("Sora-Bold", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .textFieldStyle(.plain)
                    .onChange(of: displayAmount) { newValue in
                        updateAmount(from: newValue)
                    }
                    .onAppear {
                        // Initialize display with formatted amount if there's an existing value
                        if !amount.isEmpty {
                            displayAmount = formatDisplayAmount(amount)
                        }
                    }
                    .onChange(of: amount) { newValue in
                        // Sync displayAmount when amount is cleared externally
                        if newValue.isEmpty && !displayAmount.isEmpty {
                            displayAmount = ""
                        } else if !newValue.isEmpty && displayAmount != formatDisplayAmount(newValue) {
                            displayAmount = formatDisplayAmount(newValue)
                        }
                    }
                
                Spacer()
                
                if !displayAmount.isEmpty {
                    Button(action: {
                        amount = ""
                        displayAmount = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isAmountFocused ? Color.green : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            
            TextField("Add a note (optional)", text: $note)
                .font(.body)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .focused($isNoteFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isNoteFocused ? Color.green : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            
            Button(action: onAddContribution) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.headline)
                    Text("Add Contribution")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isValidContribution ? Color.green : Color.gray)
                        .shadow(color: isValidContribution ? Color.green.opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
                )
            }
            .disabled(!isValidContribution)
            .animation(.easeInOut(duration: 0.2), value: isValidContribution)
        }
    }
    
    private var isValidContribution: Bool {
        guard let amount = Double(amount), amount > 0 else { return false }
        return true
    }
    
    // MARK: - Number Formatting Functions
    
    private func updateAmount(from input: String) {
        // Remove all non-digit and non-decimal characters
        let cleanedInput = input.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        
        // Ensure only one decimal point
        let components = cleanedInput.components(separatedBy: ".")
        var processedInput = components.first ?? ""
        
        if components.count > 1 {
            // Take only the first decimal part and limit to 2 digits
            let decimalPart = String(components[1].prefix(2))
            processedInput += "." + decimalPart
        }
        
        // Update the actual amount (stored as plain number string)
        amount = processedInput
        
        // Update display with formatted version
        displayAmount = formatDisplayAmount(processedInput)
    }
    
    private func formatDisplayAmount(_ value: String) -> String {
        guard !value.isEmpty, let number = Double(value) else { return value }
        
        // Format with commas for thousands
        if let formattedString = currencyFormatter.string(from: NSNumber(value: number)) {
            return formattedString
        }
        
        return value
    }
}
import SwiftUI

struct AddGoalView: View {
    @ObservedObject var viewModel: FinancialGoalsViewModel
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var targetDate = Date().addingTimeInterval(60*60*24*365)
    @State private var selectedIcon = "🏆"
    @State private var selectedCategory: FinancialGoal.GoalCategory = .personal
    
    @Environment(\.colorScheme) var colorScheme
    let hapticFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    let iconOptions = [
        "🏆", "✈️", "🚗", "🏠", "🎓", "🎮", "💻", "🌍", "💰", "🚲",
        "💪", "🏋️‍♀️", "🍎", "📚", "👪", "📈", "🛠️", "🖼️", "🏖️", "👨‍🍳",
        "⛰️", "🎸", "📱", "🏨", "🍕", "👗", "💍", "🎭", "🏊‍♂️", "🎯",
        "🚁", "⛵", "🏍️", "🚂", "🎪", "🎨", "📷", "🎬", "🎺", "🎻",
        "🏐", "⚽", "🏈", "🎾", "🏸", "🥊", "🎣", "🏹", "🎳", "🎲",
        "💎", "👑", "🎂", "🍰", "☕", "🍷", "🍺", "🥂", "🍾", "🧳"
    ]
    
    // Icon and category mapping based on goal name keywords
    private let iconMapping: [String: String] = [
        // Travel
        "vacation": "✈️", "flight": "✈️", "travel": "✈️", "trip": "✈️", "plane": "✈️",
        "hotel": "🏨", "beach": "🏖️", "mountain": "⛰️", "cruise": "⛵",
        
        // Vehicles
        "car": "🚗", "bike": "🚲", "motorcycle": "🏍️", "helicopter": "🚁",
        "train": "🚂", "boat": "⛵",
        
        // Home & Living
        "house": "🏠", "home": "🏠", "apartment": "🏠", "rent": "🏠",
        
        // Education
        "education": "🎓", "school": "🎓", "college": "🎓", "university": "🎓",
        "book": "📚", "study": "📚",
        
        // Technology
        "computer": "💻", "laptop": "💻", "phone": "📱", "iphone": "📱",
        "android": "📱", "tablet": "📱",
        
        // Health & Fitness
        "gym": "🏋️‍♀️", "fitness": "💪", "workout": "💪", "health": "🍎",
        "swimming": "🏊‍♂️", "boxing": "🥊",
        
        // Entertainment
        "game": "🎮", "gaming": "🎮", "console": "🎮", "guitar": "🎸",
        "music": "🎺", "piano": "🎻", "camera": "📷", "photo": "📷",
        "movie": "🎬", "cinema": "🎬",
        
        // Sports
        "soccer": "⚽", "football": "🏈", "tennis": "🎾", "basketball": "🏐",
        "volleyball": "🏐", "badminton": "🏸", "fishing": "🎣",
        "archery": "🏹", "bowling": "🎳",
        
        // Food & Dining
        "restaurant": "🍕", "food": "🍕", "pizza": "🍕", "cooking": "👨‍🍳",
        "chef": "👨‍🍳", "cake": "🎂", "coffee": "☕", "wine": "🍷",
        "beer": "🍺", "champagne": "🥂",
        
        // Fashion & Jewelry
        "clothes": "👗", "dress": "👗", "fashion": "👗", "ring": "💍",
        "wedding": "💍", "engagement": "💍", "jewelry": "💎", "diamond": "💎",
        
        // Family & Personal
        "family": "👪", "baby": "👪", "child": "👪",
        
        // Business & Investment
        "business": "📈", "investment": "📈", "stock": "📈", "crypto": "💰",
        "money": "💰", "cash": "💰", "save": "💰", "saving": "💰",
        
        // Events & Celebrations
        "party": "🎪", "birthday": "🎂", "celebration": "🥂", "crown": "👑",
        
        // Tools & Equipment
        "tool": "🛠️", "equipment": "🛠️", "repair": "🛠️",
        
        // Art & Creativity
        "art": "🎨", "paint": "🎨", "draw": "🎨", "theater": "🎭",
        
        // Luggage & Storage
        "luggage": "🧳", "suitcase": "🧳", "bag": "🧳"
    ]
    
    private let categoryMapping: [String: FinancialGoal.GoalCategory] = [
        // Travel
        "vacation": .travel, "flight": .travel, "travel": .travel, "trip": .travel,
        "hotel": .travel, "beach": .travel, "mountain": .travel, "cruise": .travel,
        
        // Vehicle
        "car": .vehicle, "bike": .vehicle, "motorcycle": .vehicle,
        "train": .vehicle, "boat": .vehicle,
        
        // Home
        "house": .homeImprovement, "home": .homeImprovement, "apartment": .homeImprovement, "rent": .homeImprovement,
        
        // Education
        "education": .education, "school": .education, "college": .education,
        "university": .education, "book": .education, "study": .education,
        
        // Electronics
        "computer": .electronics, "laptop": .electronics, "phone": .electronics,
        "iphone": .electronics, "android": .electronics, "tablet": .electronics,
        "game": .electronics, "gaming": .electronics, "console": .electronics,
        
        // Personal (health, fitness, family, celebrations, etc.)
        "gym": .personal, "fitness": .personal, "workout": .personal, "health": .personal,
        "swimming": .personal, "boxing": .personal, "guitar": .personal, "music": .personal,
        "piano": .personal, "camera": .personal, "photo": .personal, "movie": .personal,
        "cinema": .personal, "clothes": .personal, "dress": .personal, "fashion": .personal,
        "ring": .personal, "wedding": .personal, "engagement": .personal, "jewelry": .personal,
        "diamond": .personal, "family": .personal, "baby": .personal, "child": .personal,
        "party": .personal, "birthday": .personal, "celebration": .personal,
        
        // Emergency Fund
        "emergency": .emergency, "fund": .emergency, "safety": .emergency,
        
        // Retirement
        "retirement": .retirement, "401k": .retirement, "pension": .retirement,
        "invest": .retirement, "investment": .retirement, "stock": .retirement,
        "crypto": .retirement, "save": .retirement, "saving": .retirement
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Close and Title Row
                HStack {
                    Button(action: { isPresented = false }) {
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
                    
                    Text("Add Goal")
                        .font(.headline)
                        .padding(.leading, 90)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // ScrollView for main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Goal Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("e.g., Dream Vacation", text: $name)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                .accentColor(bluePurpleColor)
                                .onChange(of: name) { newValue in
                                    updateIconAndCategoryBasedOnName(newValue)
                                }
                        }
                        
                        // Target Amount Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            AnimatedAmountInputView(targetAmount: $targetAmount)
                        }
                        
                        // Category and Date Row
                        HStack(spacing: 15) {
                            // Category Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(FinancialGoal.GoalCategory.allCases, id: \.self) { category in
                                        Button(category.rawValue.capitalized) {
                                            selectedCategory = category
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedCategory.rawValue.capitalized)
                                            .foregroundColor(.primary)
                                            .font(.system(size: 14))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 12))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // Target Date Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $targetDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .accentColor(bluePurpleColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                        
                        // Icon Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Icon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 18) {
                                        ForEach(iconOptions, id: \.self) { icon in
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    selectedIcon = icon
                                                    hapticFeedback.impactOccurred()
                                                    proxy.scrollTo(icon, anchor: .center)
                                                }
                                            }) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 52)
                                                        .fill(selectedIcon == icon ? bluePurpleColor.opacity(0.99) : Color.gray.opacity(0.2))
                                                        .frame(width: 50, height: 50)
                                                    
                                                    Text(icon)
                                                        .font(.system(size: 20))
                                                        .foregroundColor(selectedIcon == icon ? bluePurpleColor : .primary)
                                                }
                                                .scaleEffect(selectedIcon == icon ? 1.2 : 1.0)
                                                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5), value: selectedIcon)
                                            }
                                            .id(icon)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                }
                                .onChange(of: selectedIcon) { newIcon in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(newIcon, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 100) // Add bottom padding to ensure content doesn't get covered by button
                }
                
                // Fixed Save Button at bottom
                VStack {
                    FinancialGoalSaveButtonView(
                        onSave: {
                            guard let amount = Double(targetAmount), !name.isEmpty else { return }
                            
                            let newGoal = FinancialGoal(
                                name: name,
                                targetAmount: amount,
                                targetDate: targetDate,
                                iconName: selectedIcon,
                                category: selectedCategory
                            )
                            
                            viewModel.addGoal(newGoal)
                            isPresented = false
                        },
                        isEnabled: !name.isEmpty && !targetAmount.isEmpty && Double(targetAmount) != nil
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .background(Color(UIColor.systemBackground)) // Ensure button has proper background
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
    }
    
    // Function to update icon and category based on goal name
    private func updateIconAndCategoryBasedOnName(_ name: String) {
        let lowercaseName = name.lowercased()
        
        // Check for matches and update both icon and category
        for (keyword, icon) in iconMapping {
            if lowercaseName.contains(keyword) {
                selectedIcon = icon
                
                // Also update category if mapping exists
                if let category = categoryMapping[keyword] {
                    selectedCategory = category
                }
                return
            }
        }
    }
    
    // Helper function to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Custom Animated Amount Input View
struct AnimatedAmountInputView: View {
    @Binding var targetAmount: String
    @State private var isEditing: Bool = false
    @State private var displayText: String = ""
    
    @Environment(\.colorScheme) var colorScheme
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.body)
                .foregroundColor(isEditing ? bluePurpleColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isEditing)
            
            TextField("0.00", text: $displayText)
                .font(.system(size: 20, weight: .semibold))
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
                .accentColor(bluePurpleColor)
                .onChange(of: displayText) { newValue in
                    let filtered = newValue.filter { "0123456789.".contains($0) }
                    
                    if let amount = Double(filtered), amount > 0 {
                        targetAmount = filtered
                        displayText = String(NumberFormatterHelper.formatCurrency(amount).dropFirst()) // Remove $ from formatter
                    } else {
                        targetAmount = filtered
                        if filtered.isEmpty {
                            displayText = ""
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = true
                    }
                    hapticFeedback.impactOccurred()
                    
                    // Show raw number when editing
                    if !targetAmount.isEmpty {
                        displayText = targetAmount
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                    }
                    
                    // Format when done editing
                    if let amount = Double(targetAmount), amount > 0 {
                        displayText = String(NumberFormatterHelper.formatCurrency(amount).dropFirst());String()
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isEditing ? bluePurpleColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        .animation(.easeInOut(duration: 0.2), value: isEditing)
                )
        )
        .onAppear {
            displayText = targetAmount.isEmpty ? "" : targetAmount
        }
    }
}

// Extension to make keyboard dismissal easier to use throughout the app
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct FinancialGoalSaveButtonView: View {
    let onSave: () -> Void
    let isEnabled: Bool
    let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            hapticFeedback.impactOccurred()
            onSave()
        }) {
            Text("Save Goal")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundView)
                .cornerRadius(16)
        }
        .disabled(!isEnabled)
    }
    
    private var backgroundView: some View {
        Group {
            if isEnabled {
                Color.primaryBluePurple
            } else {
                Color.secondary.opacity(0.3)
            }
        }
    }
}

// Utility struct for number formatting functions
struct NumberFormatterHelper {
    static func formatCurrency(_ value: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 0
        
        return numberFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    static func formatAbbreviatedAmount(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.0f", value / 1_000_000))M"  // Remove decimal for millions
        } else if value >= 1_000 {
            if value.truncatingRemainder(dividingBy: 1_000) == 0 {
                return "$\(String(format: "%.0f", value / 1_000))K"  // No decimal for round thousands
            } else {
                return "$\(String(format: "%.1f", value / 1_000))K"  // One decimal for non-round thousands
            }
        } else {
            return formatCurrency(value)  // Use full currency formatting for smaller amounts
        }
    }
}
import SwiftUI

struct FinancialGoalsView: View {
    @StateObject private var goalsViewModel = FinancialGoalsViewModel()
    @State private var showingAddGoal = false
    @State private var selectedCategory: FinancialGoal.GoalCategory? = nil
    @State private var showCompletedGoals = false
    @Environment(\.colorScheme) var colorScheme

    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var filteredGoals: [FinancialGoal] {
        let categoryFiltered = selectedCategory == nil
            ? goalsViewModel.goals
            : goalsViewModel.goals.filter { $0.category == selectedCategory }
        return categoryFiltered
    }

    var activeGoals: [FinancialGoal] {
        filteredGoals.filter { $0.status != .completed }
    }

    var completedGoals: [FinancialGoal] {
        filteredGoals.filter { $0.status == .completed }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                VStack(spacing: 0) {
                    dashboardCard

                    if filteredGoals.isEmpty {
                        emptyStateView
                    } else {
                        goalsScrollView
                    }
                }

                floatingPlusButton
            }
            .navigationTitle("Goals")
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView(viewModel: goalsViewModel, isPresented: $showingAddGoal)
        }
    }

    // MARK: - View Components

    private var backgroundView: some View {
        Color(.systemBackground).ignoresSafeArea()
    }

    private var dashboardCard: some View {
        VStack(spacing: 14) {
            dashboardStats
            categoryFilterScrollView
        }
        .padding()
        .background(dashboardBackground)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var dashboardStats: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Total Savings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(NumberFormatterHelper.formatCurrency(goalsViewModel.totalCurrentSavings))")
                    .font(.custom("Sora-Bold", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Goals Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(goalsViewModel.completedGoalsCount)/\(goalsViewModel.goals.count)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
    }

    private var categoryFilterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                allGoalsFilterButton
                categoryFilterButtons
            }
            .padding(.horizontal, 4)
        }
    }

    private var allGoalsFilterButton: some View {
        CategoryFilterButton(
            title: "All Goals",
            isSelected: selectedCategory == nil
        ) {
            selectedCategory = nil
        }
    }

    private var categoryFilterButtons: some View {
        ForEach(FinancialGoal.GoalCategory.allCases, id: \.self) { category in
            CategoryFilterButton(
                title: category.rawValue,
                isSelected: selectedCategory == category
            ) {
                selectedCategory = category
            }
        }
    }

    private var dashboardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.gray.opacity(0.06))
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            emptyStateIcon
            emptyStateText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(emptyStateBackground)
        .padding(.horizontal, 24)
        .padding(.top, 0)
    }

    private var emptyStateIcon: some View {
        Image(systemName: "trophy.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.6))
    }

    private var emptyStateText: some View {
        VStack(spacing: 8) {
            Text("No Goals Yet")
                .font(.custom("Sora-Bold", size: 24))
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .primary)

            Text("Tap + to add your first goal")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var emptyStateBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color.black : Color.white)
    }

    private var goalsScrollView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                activeGoalsSection
            }
            .padding(.horizontal, 12)
            .padding(.top, 18)

            if !completedGoals.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    DisclosureGroup(isExpanded: $showCompletedGoals) {
                        VStack {
                            LazyVGrid(columns: columns, spacing: 18) {
                                completedGoalsSection
                            }
                            .padding(.horizontal, 6) // Reduced padding for cards to be closer to edges
                            .padding(.top, 8)
                        }
                    } label: {
                        Text("Completed Goals")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: 180, alignment: .leading)
                    }
                    .padding(.horizontal, 18) // Add padding to entire DisclosureGroup for arrow spacing
                    .animation(nil, value: showCompletedGoals)
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 100)
        }
    }

    private var activeGoalsSection: some View {
        ForEach(activeGoals) { goal in
            NavigationLink(destination: GoalDetailsView(viewModel: goalsViewModel, goalId: goal.id)) {
                GoalCardView(goal: goal)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var completedGoalsSection: some View {
        ForEach(completedGoals) { goal in
            NavigationLink(destination: GoalDetailsView(viewModel: goalsViewModel, goalId: goal.id)) {
                CompletedGoalCardView(goal: goal)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 8)
        }
    }

    private var floatingPlusButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: handlePlusButtonTap) {
                    plusButtonContent
                }
                .padding(.trailing, 12)
                .padding(.bottom, 17)
            }
        }
    }

    private var plusButtonContent: some View {
        Image(systemName: "plus")
            .foregroundStyle(.white)
            .font(.title)
            .padding()
            .background(plusButtonGradient)
            .clipShape(Circle())
            .shadow(radius: 10)
    }

    private var plusButtonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 140/255, green: 160/255, blue: 255/255),
                Color(red: 70/255, green: 50/255, blue: 255/255)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Actions

    private func handlePlusButtonTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        showingAddGoal = true
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .gray : .gray))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? (colorScheme == .dark ? .gray : .gray)
                            : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                )
        }
    }
}
import SwiftUI

struct GoalCardView: View {
    let goal: FinancialGoal
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Spacer().frame(height: 10) // Reserve space under chevron

                // Icon + Name
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(statusBackgroundColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(statusBackgroundColor.opacity(0.25), lineWidth: 1))

                        Text(goal.iconName)
                            .font(.system(size: 28))
                    }

                    Text(goal.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                }

                // Progress bar + texts
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.15))

                            Capsule()
                                .fill(statusBackgroundColor)
                                .frame(width: min(geometry.size.width * CGFloat(goal.progressPercentage / 100), geometry.size.width))
                        }
                        .frame(height: 5)
                    }
                    .frame(height: 5)

                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                            .foregroundColor(statusBackgroundColor)

                        Text("\(String(format: "%.1f", goal.progressPercentage))%")
                            .font(.caption2)
                            .foregroundColor(statusBackgroundColor)
                            .fontWeight(.medium)
                    }

                    Text("\(NumberFormatterHelper.formatAbbreviatedAmount(goal.currentAmount)) / \(NumberFormatterHelper.formatAbbreviatedAmount(goal.targetAmount))")
                        .font(.caption2)
                        .foregroundColor(colorScheme == .dark ? Color(.systemGray) : .black.opacity(0.7))

                    if goal.isOverTarget {
                        Text("+\(NumberFormatterHelper.formatAbbreviatedAmount(goal.excessAmount)) excess")
                            .font(.caption2)
                            .foregroundColor(.primaryBluePurple)
                            .fontWeight(.medium)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(width: 170, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(strokeColor, lineWidth: 1)
        )
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    private var strokeColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color.white.opacity(0.1)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.4) : .gray.opacity(0.15)
    }

    private var statusBackgroundColor: Color {
        switch goal.status {
        case .completed: return goal.isOverTarget ? .primaryBluePurple : .green
        case .almostThere: return .primaryBluePurple
        case .inProgress: return .primaryBluePurple.opacity(0.8)
        case .justStarted: return .orange
        case .notStarted: return .red
        }
    }

    private var statusIcon: String {
        switch goal.status {
        case .completed: return goal.isOverTarget ? "star.circle.fill" : "checkmark.circle.fill"
        case .almostThere: return "clock.fill"
        case .inProgress: return "arrow.up.circle.fill"
        case .justStarted: return "play.circle.fill"
        case .notStarted: return "pause.circle.fill"
        }
    }
}

struct CompletedGoalCardView: View {
    let goal: FinancialGoal
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Spacer().frame(height: 10) // reserve same space

                // Icon + Name (exact same spacing and frame)
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(circleColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(circleColor.opacity(0.25), lineWidth: 1))

                        Text(goal.iconName)
                            .font(.system(size: 28))
                            .opacity(goal.isOverTarget ? 1.0 : 0.85)
                    }

                    Text(goal.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(goal.isOverTarget ? (colorScheme == .dark ? .white : .black) : (colorScheme == .dark ? Color(.systemGray) : .black.opacity(0.7)))
                        .lineLimit(1)
                }

                // Progress bar + texts (aligned with GoalCardView)
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(progressBarColor)
                            .frame(width: geometry.size.width, height: 5)
                    }
                    .frame(height: 5)

                    HStack(spacing: 4) {
                        Image(systemName: goal.isOverTarget ? "star.circle.fill" : "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(circleColor)

                        Text(goal.isOverTarget ? "\(String(format: "%.1f", goal.progressPercentage))%" : "100%")
                            .font(.caption2)
                            .foregroundColor(circleColor)
                            .fontWeight(.medium)
                    }

                    if goal.isOverTarget {
                        Text("\(NumberFormatterHelper.formatAbbreviatedAmount(goal.currentAmount)) / \(NumberFormatterHelper.formatAbbreviatedAmount(goal.targetAmount))")
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                    } else {
                        Text(NumberFormatterHelper.formatAbbreviatedAmount(goal.targetAmount))
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? Color(.systemGray) : .black.opacity(0.7))

                        Text(" ") // Keeps spacing consistent
                            .font(.caption2)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(width: 170, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(strokeColor, lineWidth: 1)
        )
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    private var strokeColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color.white.opacity(0.1)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.4) : .gray.opacity(0.15)
    }

    private var circleColor: Color {
        goal.isOverTarget ? .primaryBluePurple : .green
    }

    private var progressBarColor: Color {
        goal.isOverTarget ? .primaryBluePurple.opacity(0.8) : Color.green.opacity(0.6)
    }
}
struct AddGoalCardView: View {
    @Environment(\.colorScheme) var colorScheme  // Detect dark mode
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(Color.white)  // Change icon color to primary yellow
            
            Text("Add New Goal")
                .font(.headline)
                .foregroundColor(Color.white)  // Change text color to primary yellow
            
            Spacer()
        }
        .frame(height: 155)
        .frame(width: 155)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.primaryBluePurple.opacity(0.9))
             
        )
    }
}

