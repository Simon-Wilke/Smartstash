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
        return min((currentAmount / targetAmount) * 100, 100)
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
        if let index = goals.firstIndex(where: { $0.id == id }) {
            goals[index].currentAmount += amount
            goals[index].transactions.append(
                FinancialGoal.Transaction(amount: amount, note: note)
            )
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
    
    var body: some View {
        List {
            Section(header: Text("Transaction History")) {
                if goal.transactions.isEmpty {
                    Text("No transactions yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(goal.transactions.sorted(by: { $0.date > $1.date })) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("$\(String(format: "%.2f", transaction.amount))")
                                    .fontWeight(.bold)
                                if let note = transaction.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(transaction.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteTransaction(goalId: goal.id, transactionId: transaction.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Transactions")
    }
}
struct GoalDetailsView: View {
    @ObservedObject var viewModel: FinancialGoalsViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    @State private var contributionAmount: String = ""
    @State private var transactionNote: String = ""
    @State private var showDeleteConfirmation = false
    
    let goal: FinancialGoal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                goalHeaderSection
                progressSection
                goalMetadataSection
                contributionSection
                transactionHistoryLink
                deleteGoalButton
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - View Components
    
    private var goalHeaderSection: some View {
        HStack {
            Text(goal.iconName)
                .font(.system(size: 40))
                .frame(width: 70, height: 70)
                .background(colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(goal.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(goal.category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Progress")
                .font(.headline)
            
            ProgressBarView(
                progress: goal.progressPercentage / 100,
                color: progressColor
            )
            
            HStack {
                Text("$\(String(format: "%.2f", goal.currentAmount)) / $\(String(format: "%.2f", goal.targetAmount))")
                Spacer()
                Text("\(String(format: "%.1f", goal.progressPercentage))%")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var goalMetadataSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                goalMetadataRow(
                    icon: "calendar",
                    title: "Target Date",
                    value: goal.targetDate,
                    style: .date
                )
                goalMetadataRow(
                    icon: "clock",
                    title: "Days Remaining",
                    value: "\(goal.daysRemaining) days",
                    color: goal.daysRemaining < 30 ? .red : .secondary
                )
            }
        }
        .padding(.vertical)
        .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var contributionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Add Contribution")
                .font(.headline)
            
            ContributionInputView(
                amount: $contributionAmount,
                note: $transactionNote,
                onAddContribution: addContribution
            )
        }
    }
    
    private var transactionHistoryLink: some View {
        NavigationLink(destination: GoalTransactionsView(viewModel: viewModel, goal: goal)) {
            HStack {
                Text("View Transaction History")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var deleteGoalButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                Text("Delete Goal")
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
            .cornerRadius(10)
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
    private var progressColor: Color {
        switch goal.status {
        case .completed: return .green
        case .almostThere: return .blue
        case .inProgress: return colorScheme == .dark ? .cyan : .blue.opacity(0.7)
        case .justStarted: return .orange
        case .notStarted: return .red
        }
    }

    private var isValidContribution: Bool {
           guard let amount = Double(contributionAmount), amount > 0 else { return false }
           return true
       }
       
       private func addContribution() {
           guard let amount = Double(contributionAmount), amount > 0 else { return }
           
           viewModel.updateGoalProgress(
               id: goal.id,
               amount: amount,
               note: transactionNote.isEmpty ? nil : transactionNote
           )
           
           contributionAmount = ""
           transactionNote = ""
       }
       
       private func goalMetadataRow(
           icon: String,
           title: String,
           value: Any,
           style: Text.DateStyle? = nil,
           color: Color = .secondary
       ) -> some View {
           HStack {
               Image(systemName: icon)
                   .foregroundColor(color)
               Text(title)
                   .foregroundColor(.primary)
               Spacer()
               
               if let date = value as? Date, let style = style {
                   Text(date, style: style)
                       .foregroundColor(color)
               } else if let stringValue = value as? String {
                   Text(stringValue)
                       .foregroundColor(color)
               }
           }
           .padding(.horizontal)
       }
       
       private func deleteGoalConfirmed() {
           guard let index = viewModel.goals.firstIndex(where: { $0.id == goal.id }) else { return }
           
           viewModel.deleteGoal(at: IndexSet([index]))
           presentationMode.wrappedValue.dismiss()
       }
   }


struct ProgressBarView: View {
    let progress: CGFloat
    let color: Color
    @Environment(\.colorScheme) var colorScheme  // Detect dark mode

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.2))  // Darker background for dark mode
                    .frame(height: 15)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 15)
            }
        }
        .frame(height: 15)
    }
}

struct ContributionInputView: View {
    @Binding var amount: String
    @Binding var note: String
    let onAddContribution: () -> Void
    @Environment(\.colorScheme) var colorScheme  // Detect dark mode
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("$")
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)  // Adjust text color
                
                TextField("Enter amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .foregroundColor(colorScheme == .dark ? .white : .black)  // Adjust text color
                
                TextField("Optional note", text: $note)
                    .foregroundColor(colorScheme == .dark ? .gray.opacity(0.8) : .gray)
            }
            .padding()
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1))  // Darker background
            .cornerRadius(10)
            
            Button(action: onAddContribution) {
                Text("Add Contribution")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidContribution ? Color.green : (colorScheme == .dark ? Color.gray.opacity(0.6) : Color.gray))  // Adjust button color
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isValidContribution)
        }
    }
    
    private var isValidContribution: Bool {
        guard let amount = Double(amount), amount > 0 else { return false }
        return true
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
        "💪", "🏋️‍♀️", "🍎", "📚", "👪", "📈", "🛠️", "🖼️", "🏖️", "👨‍🍳"
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
                .padding()
                
                // Scrollable Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                        }
                        
                        // Target Amount Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                
                                TextField("0.00", text: $targetAmount)
                                    .font(.body)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
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
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Target Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("Select Target Date", selection: $targetDate, displayedComponents: .date)
                                .accentColor(bluePurpleColor)
                            
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
                        
                        // Financial Goal Save Button - Moved inside ScrollView
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
                        .padding(.top, 120) // Add some top padding
                    }
                    .padding()
                }
                .navigationBarHidden(true)
            }
        }
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


struct FinancialGoalsView: View {
    @StateObject private var goalsViewModel = FinancialGoalsViewModel()
    @State private var showingAddGoal = false
    @State private var selectedCategory: FinancialGoal.GoalCategory? = nil
    @Environment(\.colorScheme) var colorScheme  // Detect dark mode
    
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var filteredGoals: [FinancialGoal] {
        selectedCategory == nil
            ? goalsViewModel.goals
            : goalsViewModel.goals.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Dashboard Header
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Savings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(NumberFormatterHelper.formatCurrency(goalsViewModel.totalCurrentSavings))")
                                .font(.title)
                                .fontWeight(.bold)
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
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.gray.opacity(0.1)) // Regular gray for light mode
                    )
                }
                .padding()
                .padding(.vertical, -100)
                
                // Category Filter Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryFilterButton(
                            title: "All Goals",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(FinancialGoal.GoalCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                
                // Goals Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(filteredGoals) { goal in
                            NavigationLink(destination: GoalDetailsView(viewModel: goalsViewModel, goal: goal)) {
                                GoalCardView(goal: goal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Add Goal Card
                        Button(action: { showingAddGoal = true }) {
                            AddGoalCardView()
                        }
                    }
                    .padding(15)
                }
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView(viewModel: goalsViewModel, isPresented: $showingAddGoal)
        }
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme  // Detect dark mode
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .gray : .gray))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? (colorScheme == .dark ? .gray : .gray) : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                )
        }
    }
}

struct GoalCardView: View {
    let goal: FinancialGoal
    @Environment(\.colorScheme) var colorScheme  // Detect dark mode
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusBackgroundColor.opacity(0.1))
                
                Text(goal.iconName)
                    .font(.system(size: 40))
            }
            .frame(width: 80, height: 80)
            
            Text(goal.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            VStack(alignment: .center, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(colorScheme == .dark ? 0.4 : 0.2))
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(statusBackgroundColor)
                            .frame(width: geometry.size.width * CGFloat(goal.progressPercentage / 100))
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(String(format: "%.1f", goal.progressPercentage))%")
                        .font(.caption)
                        .foregroundColor(statusBackgroundColor)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(NumberFormatterHelper.formatAbbreviatedAmount(goal.currentAmount)) / \(NumberFormatterHelper.formatAbbreviatedAmount(goal.targetAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
                .shadow(color: .gray.opacity(colorScheme == .dark ? 0.6 : 0.2), radius: 2)
        )
    }
    
    private var statusBackgroundColor: Color {
        switch goal.status {
        case .completed: return .green
        case .almostThere: return .blue
        case .inProgress: return .blue.opacity(0.7)
        case .justStarted: return .orange
        case .notStarted: return .red
        }
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

