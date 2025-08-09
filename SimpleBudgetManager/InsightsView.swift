//
//
//
//
import SwiftUI
import Charts

// MARK: - Color Theme
struct AppTheme {
    static let primary = Color(hex: "#5771FF")    // Vibrant indigo blue
    static let secondary = Color(hex: "FFB144")  // Warm orange
    static let accent = Color(hex: "FF7676")     // Soft red
    static let background = Color(hex: "F9F9FD") // Light gray with blue tint
    static let cardBg = Color.white
    static let textPrimary = Color(hex: "2A2B55") // Dark blue-gray
    static let textSecondary = Color(hex: "9292A0") // Medium gray
    
    // Gradient backgrounds
    static let primaryGradient = LinearGradient(
        colors: [primary, primary.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [secondary, secondary.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let incomeColor = Color(hex: "25C685") // Green
    static let expenseColor = Color(hex: "FF7676") // Red
}


extension Date {
    func isSameDay(as other: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: other)
    }
    
    func formattedDay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}

// MARK: - View Models
struct SummaryButton: Identifiable {
    enum ButtonType {
        case weekly, monthly, yearly
    }
    
    let id: Int
    let type: ButtonType
    let title: String
    let subtitle: String
    let systemImage: String
    let gradient: LinearGradient
}

struct FinancialStory: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let emoji: String
    
    // Store color as hex string instead of Color directly
    private var colorHex: String
    
    // Use a computed property for the Color
    var backgroundColor: Color {
        get { Color(hex: colorHex) }
        set { colorHex = newValue.toHex() ?? "#5771FF" } // Default to primary if conversion fails
    }
    
    // Coding keys that include the hex string
    private enum CodingKeys: String, CodingKey {
        case id, title, value, change, isPositive, emoji, colorHex
    }
    
    // Regular initializer that takes a Color
    init(title: String, value: String, change: String, isPositive: Bool, emoji: String, backgroundColor: Color) {
        self.title = title
        self.value = value
        self.change = change
        self.isPositive = isPositive
        self.emoji = emoji
        self.colorHex = backgroundColor.toHex() ?? "#5771FF" // Convert color to hex
    }
    
    // Decoder initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        value = try container.decode(String.self, forKey: .value)
        change = try container.decode(String.self, forKey: .change)
        isPositive = try container.decode(Bool.self, forKey: .isPositive)
        emoji = try container.decode(String.self, forKey: .emoji)
        colorHex = try container.decode(String.self, forKey: .colorHex)
    }
    
    // Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(value, forKey: .value)
        try container.encode(change, forKey: .change)
        try container.encode(isPositive, forKey: .isPositive)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(colorHex, forKey: .colorHex)
    }
}

// 2. Add Color extension for hex conversion if you don't already have it
extension Color {
    // Convert Color to hex string
    func toHex() -> String? {
        let uiColor = UIColor(self)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        let hexString = String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
        
        return hexString
    }
    
  
}
import SwiftUI
import Charts

struct InsightsView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @StateObject private var storyManager = StoryManager()
    @State private var showingWeeklyStory = false
    @State private var showingMonthlyStory = false
    @State private var selectedTimeframe: Timeframe = .week
    @State private var animateChart = false
    @State private var animateCategoryChart = false
    @Environment(\.colorScheme) private var colorScheme
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    // Dynamic data based on selected timeframe
    var balanceData: [(day: String, date: String, balance: Double)] {
        switch selectedTimeframe {
        case .week:
            return getWeekData()
        case .month:
            return getMonthData()
        case .year:
            return getYearData()
        }
    }
    
    // Dynamic category breakdown based on timeframe
    var categoryBreakdown: [(category: String, amount: Double, icon: String, percentage: Double)] {
        let calendar = Calendar.current
        let today = Date()
        
        // Filter transactions based on timeframe
        let filteredExpenses: [Transaction]
        
        switch selectedTimeframe {
        case .week:
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
            filteredExpenses = viewModel.transactions.filter {
                $0.type == .expense && $0.date >= oneWeekAgo
            }
        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            filteredExpenses = viewModel.transactions.filter {
                $0.type == .expense && $0.date >= startOfMonth
            }
        case .year:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today))!
            filteredExpenses = viewModel.transactions.filter {
                $0.type == .expense && $0.date >= startOfYear
            }
        }
        
        // Group by category
        let expensesByCategory = Dictionary(grouping: filteredExpenses) { $0.category }
        
        // Calculate total for each category
        var categoryTotals = expensesByCategory.map { (category, transactions) -> (category: String, amount: Double, icon: String) in
            let total = transactions.reduce(0) { $0 + $1.amount }
            let icon = transactions.first?.icon ?? "questionmark"
            return (category: category, amount: total, icon: icon)
        }
        
        // Sort by amount (descending)
        categoryTotals.sort { $0.amount > $1.amount }
        
        // Calculate total expenses
        let totalExpense = categoryTotals.reduce(0) { $0 + $1.amount }
        
        // Calculate percentage
        return categoryTotals.map { category, amount, icon in
            let percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0
            return (category: category, amount: amount, icon: icon, percentage: percentage)
        }
    }
    
    // Get week data (last 7 days)
    private func getWeekData() -> [(day: String, date: String, balance: Double)] {
        let calendar = Calendar.current
        let today = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E" // Shows day abbreviation (e.g., Mon, Tue)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d" // Just the day number

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayString = dayFormatter.string(from: date)
            let dateString = dateFormatter.string(from: date)

            let dailyIncome = viewModel.transactions
                .filter { $0.date.isSameDay(as: date) && $0.type == .income }
                .reduce(0) { $0 + $1.amount }

            let dailyExpense = viewModel.transactions
                .filter { $0.date.isSameDay(as: date) && $0.type == .expense }
                .reduce(0) { $0 + $1.amount }

            let balance = dailyIncome - dailyExpense
            return (day: dayString, date: dateString, balance: balance)
        }.reversed() // Keep order from oldest to newest
    }
    
    // Get month data (weekly breakdown)
    private func getMonthData() -> [(day: String, date: String, balance: Double)] {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        // Calculate the number of weeks in the current month
        let weeksInMonth = calendar.range(of: .weekOfMonth, in: .month, for: today)?.count ?? 4
        
        return (0..<weeksInMonth).map { weekIndex in
            // Start of this week
            let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: startOfMonth)!
            // End of this week
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            // Get label for the week
            let weekLabel = "W\(weekIndex + 1)"
            let startDateStr = dateFormatter.string(from: weekStart)
            
            // Calculate balance for this week
            let weekIncome = viewModel.transactions
                .filter {
                    $0.type == .income &&
                    $0.date >= weekStart &&
                    $0.date <= min(weekEnd, today)
                }
                .reduce(0) { $0 + $1.amount }
            
            let weekExpense = viewModel.transactions
                .filter {
                    $0.type == .expense &&
                    $0.date >= weekStart &&
                    $0.date <= min(weekEnd, today)
                }
                .reduce(0) { $0 + $1.amount }
            
            let balance = weekIncome - weekExpense
            return (day: weekLabel, date: startDateStr, balance: balance)
        }
    }
    
    // Get year data (monthly breakdown)
    private func getYearData() -> [(day: String, date: String, balance: Double)] {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        
        let currentMonth = calendar.component(.month, from: today)
        
        return (0..<currentMonth).map { monthIndex in
            let monthDate = calendar.date(from: DateComponents(year: currentYear, month: monthIndex + 1, day: 1))!
            let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: monthDate)!
            
            let monthStr = monthFormatter.string(from: monthDate)
            let yearStr = yearFormatter.string(from: monthDate)
            
            let monthIncome = viewModel.transactions
                .filter {
                    $0.type == .income &&
                    $0.date >= monthDate &&
                    $0.date < nextMonthDate
                }
                .reduce(0) { $0 + $1.amount }
            
            let monthExpense = viewModel.transactions
                .filter {
                    $0.type == .expense &&
                    $0.date >= monthDate &&
                    $0.date < nextMonthDate
                }
                .reduce(0) { $0 + $1.amount }
            
            let balance = monthIncome - monthExpense
            return (day: monthStr, date: yearStr, balance: balance)
        }
    }
    
    // Calculate current balance
    var currentBalance: Double {
        let income = viewModel.transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        let expense = viewModel.transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        
        return income - expense
    }
    
    // Calculate weekly change
    var weeklyChange: Double {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        
        // Current week transactions
        let currentWeekIncome = viewModel.transactions
            .filter { $0.type == .income && $0.date >= oneWeekAgo }
            .reduce(0) { $0 + $1.amount }
        
        let currentWeekExpense = viewModel.transactions
            .filter { $0.type == .expense && $0.date >= oneWeekAgo }
            .reduce(0) { $0 + $1.amount }
        
        // Previous week transactions
        let previousWeekIncome = viewModel.transactions
            .filter { $0.type == .income && $0.date >= twoWeeksAgo && $0.date < oneWeekAgo }
            .reduce(0) { $0 + $1.amount }
        
        let previousWeekExpense = viewModel.transactions
            .filter { $0.type == .expense && $0.date >= twoWeeksAgo && $0.date < oneWeekAgo }
            .reduce(0) { $0 + $1.amount }
        
        let currentWeekNet = currentWeekIncome - currentWeekExpense
        let previousWeekNet = previousWeekIncome - previousWeekExpense
        
        return previousWeekNet != 0 ? currentWeekNet - previousWeekNet : currentWeekNet
    }
    
    // MARK: - Fixed summaryButtons implementation
    var summaryButtons: [SummaryButton] {
        // Get previous month name for the subtitle
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let previousMonthName = dateFormatter.string(from: previousMonth)
        
        return [
            SummaryButton(
                id: 1,
                type: .weekly,
                title: "Weekly Summary",
                subtitle: "Previous Week",
                systemImage: "chart.line.uptrend.xyaxis",
                gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            SummaryButton(
                id: 2,
                type: .monthly,
                title: "Monthly Report",
                subtitle: previousMonthName,
                systemImage: "calendar.badge.clock",
                gradient: LinearGradient(
                    colors: [AppTheme.secondary, AppTheme.secondary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Time Segmented Control
                    TimeSegmentControl(selectedTimeframe: $selectedTimeframe)

                    // Chart Section
                    ChartSection(
                        balanceData: balanceData,
                        animate: animateChart
                    )

                    // Transaction Categories
                    CategoryBreakdownSection(
                        categories: categoryBreakdown,
                        animate: animateCategoryChart
                    )

                    // Daily Breakdown
                    DailyBreakdownSection(
                        lastWeekData: balanceData.map { item in
                            let income = item.balance > 0 ? item.balance : 0
                            let expense = item.balance < 0 ? abs(item.balance) : 0
                            return (day: item.day, date: item.date, income: income, expense: expense)
                        }
                        
                    )
                    .padding(.horizontal, -16) // negate parent VStack padding

                    InsightsButtonsSection(
                        buttons: summaryButtons,
                        onTapWeekly: { showingWeeklyStory = true },
                        onTapMonthly: { showingMonthlyStory = true },
                        storyManager: storyManager
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(
                Color(uiColor: colorScheme == .dark ? .black : .systemBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.easeInOut(duration: 1.0)) {
                    animateChart = true
                }
                withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                    animateCategoryChart = true
                }
                storyManager.loadStoredStories()
                storyManager.updateTransactions(viewModel.transactions)
            }
            .onChange(of: selectedTimeframe) { newTimeframe in
                animateChart = false
                animateCategoryChart = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        animateChart = true
                    }
                    withAnimation(.easeInOut(duration: 1.2).delay(0.2)) {
                        animateCategoryChart = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingWeeklyStory) {
                WeeklyStoryView(
                    stories: storyManager.weeklyStory.isEmpty ? generateDefaultWeeklyStories() : storyManager.weeklyStory,
                    showStories: $showingWeeklyStory
                )
            }
            .fullScreenCover(isPresented: $showingMonthlyStory) {
                MonthlyStoryView(
                    stories: storyManager.monthlyStory.isEmpty ? generateDefaultMonthlyStories() : storyManager.monthlyStory,
                    showStories: $showingMonthlyStory
                )
            }
        }
        .environment(\.colorScheme, colorScheme)
    }

    // Fallback stories in case the StoryManager hasn't generated any stories yet
    private func generateDefaultWeeklyStories() -> [FinancialStory] {
        return [
            FinancialStory(
                title: "Weekly Spending",
                value: "$0.00",
                change: "$0.00",
                isPositive: true,
                emoji: "💰",
                backgroundColor: AppTheme.primary
            ),
            FinancialStory(
                title: "Top Category",
                value: "No Expenses",
                change: "$0.00",
                isPositive: true,
                emoji: "🛒",
                backgroundColor: AppTheme.secondary
            ),
            FinancialStory(
                title: "Weekly Balance",
                value: "$0.00",
                change: "$0.00",
                isPositive: true,
                emoji: "✨",
                backgroundColor: AppTheme.accent
            )
        ]
    }
    
    private func generateDefaultMonthlyStories() -> [FinancialStory] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let monthName = dateFormatter.string(from: Date())
        
        return [
            FinancialStory(
                title: "Monthly Spending",
                value: "$0.00",
                change: "$0.00",
                isPositive: true,
                emoji: "📊",
                backgroundColor: AppTheme.primary
            ),
            FinancialStory(
                title: "Monthly Savings",
                value: "$0.00",
                change: "$0.00",
                isPositive: true,
                emoji: "💸",
                backgroundColor: Color(hex: "63C7FF")
            ),
            FinancialStory(
                title: "Investments",
                value: "$0.00",
                change: monthName,
                isPositive: true,
                emoji: "📈",
                backgroundColor: Color(hex: "8676FF")
            )
        ]
    }
}
struct InsightsButtonsSection: View {
    let buttons: [SummaryButton]
    let onTapWeekly: () -> Void
    let onTapMonthly: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var storyManager: StoryManager
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Insights & Reports")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(buttons) { button in
                    Button(action: {
                        if isButtonEnabled(for: button) {
                            if button.type == .weekly {
                                onTapWeekly()
                            } else if button.type == .monthly {
                                onTapMonthly()
                            }
                        } else {
                            alertMessage = "Not enough data yet. Use the app a bit more to see this report."
                            showAlert = true
                        }
                    }) {
                        InsightButton(button: button)
                            .opacity(isButtonEnabled(for: button) ? 1.0 : 0.5)
                    }
                    .disabled(false) // keep buttons tappable to show alert
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Report Unavailable"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func isButtonEnabled(for button: SummaryButton) -> Bool {
        if button.type == .weekly {
            return storyManager.hasWeeklyStory()
        } else if button.type == .monthly {
            return storyManager.hasMonthlyStory()
        }
        return false
    }
}

extension StoryManager {
    // Force regenerate stories regardless of timing conditions
    func forceRegenerateStories() {
        // Force regenerate both weekly and monthly stories
        generateWeeklyStory()
        generateMonthlyStory()
        
        // Update the last update dates to now to prevent automatic regeneration
        let currentDate = Date()
        lastWeeklyUpdateDate = currentDate
        lastMonthlyUpdateDate = currentDate
        UserDefaults.standard.set(currentDate, forKey: "lastWeeklyUpdate")
        UserDefaults.standard.set(currentDate, forKey: "lastMonthlyUpdate")
        
        // Save the regenerated stories
        saveStories()
    }
}
import SwiftUI

struct PlayfulFinancialFeedbackCard: View {
    let weeklyChange: Double
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var statusInfo: (emoji: String, color: Color) {
        if weeklyChange > 40 {
            return ("🚀", Color.green)
        } else if weeklyChange > 10 {
            return ("🌟", Color(hue: 90/360, saturation: 0.6, brightness: 0.75))
        } else if weeklyChange >= 0 {
            return ("👍", Color.blue)
        } else if weeklyChange > -30 {
            return ("⚠️", Color.orange)
        } else {
            return ("🔍", Color.red)
        }
    }

    private var feedbackPhrase: String {
        if weeklyChange > 40 {
            return "Exceptional"
        } else if weeklyChange > 10 {
            return "On Track"
        } else if weeklyChange >= 0 {
            return "Stable"
        } else if weeklyChange > -30 {
            return "Watch Spending"
        } else {
            return "Action Needed"
        }
    }

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(statusInfo.color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Text(statusInfo.emoji)
                        .font(.system(size: 28))
                }
                .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusInfo.color)
                            .frame(width: 10, height: 10)

                        Text(feedbackPhrase)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(statusInfo.color)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(weeklyChange >= 0 ? "+" : "")\(String(format: "$%.2f", abs(weeklyChange)))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(weeklyChange >= 0 ? .green : .red)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))

                        Text("This Week")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(colorScheme == .dark ? Color.gray.opacity(0.6) : Color.gray)
                }
                .padding(.trailing, 4)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(
                ZStack(alignment: .bottomTrailing) {
                    // Direct dark/light background color
                    RoundedRectangle(cornerRadius: 18)
                        .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)

                    RoundedRectangle(cornerRadius: 18)
                        .trim(from: 0.7, to: 1.0)
                        .stroke(statusInfo.color.opacity(0.3), lineWidth: 3)

                    HStack(spacing: 4) {
                        ForEach(0..<8) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(statusInfo.color.opacity(0.03 + Double(i) * 0.01))
                                .frame(width: 3, height: 15 + CGFloat(i * 6))
                        }
                    }
                    .rotationEffect(.degrees(180))
                    .offset(x: -12, y: -4)

                    Path { path in
                        let startX: CGFloat = 80
                        let width: CGFloat = 300
                        let height: CGFloat = 40

                        path.move(to: CGPoint(x: startX, y: height))

                        for i in 0..<8 {
                            let x = startX + width * CGFloat(i) / 8
                            let randomFactor = CGFloat.random(in: 0.8...1.2)
                            let yOffset = height * 0.5 * (1 - CGFloat(i) / 8) * (weeklyChange >= 0 ? -1 : 1) * randomFactor
                            path.addLine(to: CGPoint(x: x, y: height + yOffset))
                        }
                    }
                    .stroke(statusInfo.color.opacity(0.15), lineWidth: 1.5)
                    .offset(x: 40, y: 10)
                }
            )
            .cornerRadius(18)
            .padding(.bottom, 10)
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1), radius: 10, x: 0, y: 4)
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
        }
    }
}
// MARK: - Component Views
struct BalanceCard: View {
    let balance: Double
    let weeklyChange: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Balance")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            Text("$\(String(format: "%.2f", balance))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            
            HStack {
                Text("\(weeklyChange >= 0 ? "+" : "")\(String(format: "%.2f", weeklyChange)) this week")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(weeklyChange >= 0 ? AppTheme.incomeColor.opacity(0.15) : AppTheme.expenseColor.opacity(0.15))
                    .foregroundColor(weeklyChange >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
                    .cornerRadius(12)
                
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.cardBg)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
import SwiftUI

// MARK: - Shadow Style Extension
extension View {
    /// Applies a consistent shadow style to a view
    /// - Parameters:
    ///   - intensity: The intensity level of the shadow (light, medium, strong)
    ///   - isElevated: Whether the view appears elevated with more pronounced shadow
    /// - Returns: A modified view with consistent shadow styling
    func consistentShadow(intensity: ShadowIntensity = .medium, isElevated: Bool = false) -> some View {
        let elevation = isElevated ? 1.5 : 1.0
        
        return self.shadow(
            color: Color.black.opacity(intensity.opacityValue * elevation),
            radius: intensity.radiusValue * elevation,
            x: 0,
            y: intensity.yOffsetValue * elevation
        )
    }
}

// MARK: - Shadow Intensity Options
enum ShadowIntensity {
    case light
    case medium
    case strong
    
    var opacityValue: Double {
        switch self {
        case .light: return 0.05
        case .medium: return 0.08
        case .strong: return 0.12
        }
    }
    
    var radiusValue: Double {
        switch self {
        case .light: return 4
        case .medium: return 8
        case .strong: return 12
        }
    }
    
    var yOffsetValue: Double {
        switch self {
        case .light: return 2
        case .medium: return 3
        case .strong: return 4
        }
    }
}

// MARK: - Card Style Extension
extension View {
    /// Applies a consistent card style to a view with proper shadow
    /// - Parameters:
    ///   - intensity: The shadow intensity level
    ///   - cornerRadius: The corner radius of the card
    ///   - isElevated: Whether the card appears elevated with more pronounced shadow
    /// - Returns: A modified view with consistent card styling
    func cardStyle(intensity: ShadowIntensity = .medium,
                  cornerRadius: CGFloat = 16,
                  isElevated: Bool = false) -> some View {
        let colorScheme = ColorScheme.current
        return self
            .background(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
            .cornerRadius(cornerRadius)
            .consistentShadow(intensity: intensity, isElevated: isElevated)
    }
}

// Helper for getting current color scheme (use this instead of @Environment in extensions)
extension ColorScheme {
    static var current: ColorScheme {
        #if os(iOS)
        return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        #else
        return .light
        #endif
    }
}

// MARK: - Consistent UI Constants
struct AppShadow {
    static let light = ShadowIntensity.light
    static let medium = ShadowIntensity.medium
    static let strong = ShadowIntensity.strong
}
import SwiftUI
import CoreHaptics

struct TimeSegmentControl: View {
    @Binding var selectedTimeframe: InsightsView.Timeframe
    @State private var engine: CHHapticEngine?
    @Environment(\.colorScheme) private var colorScheme
    @State private var indicatorOffset: CGFloat = 0
    @State private var segmentWidth: CGFloat = 0
    
    private let height: CGFloat = 36
    // Snappy animation duration
    private let transitionDuration: Double = 0.25
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
           
            ZStack(alignment: .leading) {
                // Background with minimal styling
                backgroundStyle
                
                // Sliding indicator
                slidingIndicator
                    .frame(width: segmentWidth)
                    .offset(x: indicatorOffset)
                    .animation(.spring(response: transitionDuration, dampingFraction: 0.7, blendDuration: 0.1), value: indicatorOffset)
                
                // Main control with text buttons
                HStack(spacing: 0) {
                    ForEach(Array(zip(InsightsView.Timeframe.allCases.indices, InsightsView.Timeframe.allCases)), id: \.0) { index, timeframe in
                        Button(action: {
                            updateSelection(to: timeframe, at: index)
                            playHaptic()
                        }) {
                            Text(timeframe.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(selectedTimeframe == timeframe ? .white :
                                              (colorScheme == .dark ? .white : .black))
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                let count = CGFloat(InsightsView.Timeframe.allCases.count)
                                                segmentWidth = geo.size.width
                                                
                                                // Set initial position based on selection
                                                if timeframe == selectedTimeframe {
                                                    indicatorOffset = segmentWidth * CGFloat(index)
                                                }
                                            }
                                    }
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 0)
        .frame(width: 300)
        .onAppear(perform: {
            setupHaptics()
        })
    }
    
    private var slidingIndicator: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.85)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color.accentColor.opacity(0.3), radius: 3, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .padding(3) // Add padding for nice spacing from edge
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                colorScheme == .dark ?
                    Color(UIColor.systemGray6) :
                    Color(UIColor.systemBackground)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func updateSelection(to timeframe: InsightsView.Timeframe, at index: Int) {
        withAnimation {
            selectedTimeframe = timeframe
            indicatorOffset = segmentWidth * CGFloat(index)
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptics failed: \(error.localizedDescription)")
        }
    }
    
    private func playHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            // Create a sharp, snappy haptic pattern
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            
            try engine?.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            print("Haptic failed: \(error.localizedDescription)")
        }
    }
}
import SwiftUI
import Charts

struct ChartSection: View {
    let balanceData: [(day: String, date: String, balance: Double)]
    let animate: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var maxBalance: Double {
        let max = balanceData.map { $0.balance }.max() ?? 1000
        return max > 0 ? max : 1000
    }

    var minBalance: Double {
        let min = balanceData.map { $0.balance }.min() ?? 0
        return min < 0 ? min : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Balance Overview")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            if balanceData.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor((colorScheme == .dark ? Color.white : Color.gray).opacity(0.5))
                        Text("No data available for this period")
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .padding()
                .background(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            } else {
                Chart {
                    ForEach(balanceData.indices, id: \.self) { index in
                        let item = balanceData[index]

                        LineMark(
                            x: .value("Day", "\(item.day)\n\(item.date)"),
                            y: .value("Balance", animate ? item.balance : minBalance)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", "\(item.day)\n\(item.date)"),
                            y: .value("Balance", animate ? item.balance : minBalance)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.3),
                                    Color.accentColor.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", "\(item.day)\n\(item.date)"),
                            y: .value("Balance", animate ? item.balance : minBalance)
                        )
                        .foregroundStyle(Color.white)
                        .symbolSize(30)

                        PointMark(
                            x: .value("Day", "\(item.day)\n\(item.date)"),
                            y: .value("Balance", animate ? item.balance : minBalance)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(20)
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .extended, position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    }
                }
                .frame(height: 240)
                .padding()
                .background(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }
    }
}
struct CategoryBreakdownSection: View {
    let categories: [(category: String, amount: Double, icon: String, percentage: Double)]
    let animate: Bool
    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            if categories.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 32))
                            .foregroundColor((colorScheme == .dark ? Color.white : Color.gray).opacity(0.5))
                        Text("No expenses in this period")
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .padding()
                .background(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                .cornerRadius(16)
                .consistentShadow(intensity: .medium, isElevated: false)
            } else {
                // Apply the navigation link and card styling separately
                NavigationLink {
                    SimplifiedCategoryDetailView(categories: categories)
                        .navigationTransition(.zoom(sourceID: "categoryZoom", in: namespace))
                } label: {
                    breakdownChart
                        .matchedTransitionSource(id: "categoryZoom", in: namespace)
                        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                        .cornerRadius(16)
                        .consistentShadow(intensity: .medium, isElevated: false)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var breakdownChart: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 14)
                    .foregroundColor(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                ForEach(0..<min(categories.count, 5), id: \.self) { index in
                    let startAngle = getStartAngle(at: index)
                    let endAngle = animate ? getEndAngle(at: index) : startAngle
                    
                    Circle()
                        .trim(from: startAngle/360, to: endAngle/360)
                        .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .foregroundColor(getCategoryColor(at: index))
                        .rotationEffect(Angle(degrees: -90))
                        .frame(width: 100, height: 100)
                        .animation(.easeInOut(duration: 1.0).delay(0.1 * Double(index)), value: animate)
                }
                
                VStack {
                    Text("Total")
                        .font(.caption2)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                    Text("$\(String(format: "%.0f", categories.reduce(0) { $0 + $1.amount }))")
                        .font(.body.bold())
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .opacity(animate ? 1 : 0)
                        .animation(.easeIn(duration: 0.6).delay(0.3), value: animate)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<min(categories.count, 5), id: \.self) { index in
                    let category = categories[index]
                    HStack(spacing: 8) {
                        Circle()
                            .fill(getCategoryColor(at: index))
                            .frame(width: 12, height: 12)
                            .scaleEffect(animate ? 1 : 0.1)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1 * Double(index)), value: animate)
                        
                        Image(systemName: category.icon)
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .opacity(animate ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.2 + 0.1 * Double(index)), value: animate)
                        
                        Text(category.category)
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .lineLimit(1)
                            .opacity(animate ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.3 + 0.1 * Double(index)), value: animate)
                        
                        Spacer()
                        
                        Text("\(animate ? Int(category.percentage) : 0)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                            .animation(.easeInOut(duration: 1.0).delay(0.4 + 0.1 * Double(index)), value: animate)
                    }
                }
            }
        }
        .padding()
    }
    
    private func getCategoryColor(at index: Int) -> Color {
        let colors: [Color] = [
            AppTheme.primary,
            AppTheme.accent,
            AppTheme.secondary,
            Color(hex: "8676FF"),
            Color(hex: "63C7FF")
        ]
        return colors[index % colors.count]
    }

    private func getStartAngle(at index: Int) -> Double {
        if index == 0 { return 0 }
        var sum: Double = 0
        for i in 0..<index { sum += categories[i].percentage }
        return sum * 3.6
    }

    private func getEndAngle(at index: Int) -> Double {
        var sum: Double = 0
        for i in 0...index { sum += categories[i].percentage }
        return sum * 3.6
    }
}
struct SimplifiedCategoryDetailView: View {
    let categories: [(category: String, amount: Double, icon: String, percentage: Double)]
    
    @State private var selectedCategoryIndex: Int? = nil
    @State private var animate = false
    @State private var chartRotation: Double = -90
    @Environment(\.colorScheme) private var colorScheme
    
    // New state variables for enhanced animations
    @State private var highlightedCategoryIndex: Int? = nil
    @State private var showDetails = false
    @State private var sortOrder: SortOrder = .default
    
    // Define sorting options
    enum SortOrder {
        case `default`, amount, percentage, alphabetical
        
        var description: String {
            switch self {
            case .default: return "Default"
            case .amount: return "By Amount"
            case .percentage: return "By Percentage"
            case .alphabetical: return "Alphabetical"
            }
        }
    }
    
    // Computed property for sorted categories
    private var sortedCategories: [(category: String, amount: Double, icon: String, percentage: Double)] {
        switch sortOrder {
        case .default:
            return categories
        case .amount:
            return categories.sorted(by: { $0.amount > $1.amount })
        case .percentage:
            return categories.sorted(by: { $0.percentage > $1.percentage })
        case .alphabetical:
            return categories.sorted(by: { $0.category < $1.category })
        }
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header with total amount
                    VStack(spacing: 12) {
                        Text("Total Spending")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                        
                        Text("$\(String(format: "%.2f", categories.reduce(0) { $0 + $1.amount }))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .padding(.top, 30)
                    .opacity(selectedCategoryIndex == nil ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: selectedCategoryIndex)
                    
                    // Large animated donut chart - with more space around it
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(lineWidth: 30)
                            .foregroundColor(Color.gray.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .blur(radius: 0.5)
                        
                        // Category segments
                        ForEach(0..<categories.count, id: \.self) { index in
                            let startAngle = getStartAngle(at: index, for: categories)
                            let endAngle = animate ? getEndAngle(at: index, for: categories) : startAngle
                            let isSelected = selectedCategoryIndex == index
                            let isHighlighted = highlightedCategoryIndex == index
                            
                            Circle()
                                .trim(from: startAngle / 360, to: endAngle / 360)
                                .stroke(style: StrokeStyle(
                                    lineWidth: isSelected ? 38 : (isHighlighted ? 34 : 30),
                                    lineCap: .round
                                ))
                                .foregroundColor(getCategoryColor(at: index))
                                .opacity(selectedCategoryIndex == nil || isSelected ? 1.0 : 0.7)
                                .rotationEffect(.degrees(chartRotation))
                                .frame(width: 280, height: 280)
                                .animation(.easeInOut(duration: 1.2).delay(0.05 * Double(index)), value: animate)
                                .animation(.spring(response: 0.3), value: selectedCategoryIndex)
                                .animation(.spring(response: 0.2), value: highlightedCategoryIndex)
                                .shadow(color: getCategoryColor(at: index).opacity(isSelected ? 0.4 : 0), radius: 8, x: 0, y: 0)
                                .onTapGesture {
                                    withAnimation {
                                        if selectedCategoryIndex == index {
                                            selectedCategoryIndex = nil
                                        } else {
                                            selectedCategoryIndex = index
                                            // Small rotation effect on selection
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                                chartRotation = -90 + Double.random(in: -3...3)
                                            }
                                        }
                                    }
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                        }
                        
                        // Chart center content
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                                .frame(width: 210, height: 210)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            // Content based on selection
                            if let selectedIndex = selectedCategoryIndex {
                                let category = categories[selectedIndex]
                                VStack(spacing: 8) {
                                    // Category icon
                                    ZStack {
                                        Circle()
                                            .fill(getCategoryColor(at: selectedIndex).opacity(0.2))
                                            .frame(width: 64, height: 64)
                                        
                                        Image(systemName: category.icon)
                                            .font(.system(size: 30))
                                            .foregroundColor(getCategoryColor(at: selectedIndex))
                                    }
                                    .padding(.bottom, 6)
                                    
                                    // Category name
                                    Text(category.category)
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    // Amount
                                    Text("$\(String(format: "%.2f", category.amount))")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(getCategoryColor(at: selectedIndex))
                                    
                                    // Percentage
                                    HStack(spacing: 4) {
                                        Text("\(Int(category.percentage))%")
                                            .font(.system(.subheadline).bold())
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                                        
                                        Text("of total")
                                            .font(.system(.caption))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                                    }
                                }
                                .transition(AnyTransition.opacity.combined(with: AnyTransition.scale))
                                .id("selected-\(selectedIndex)")
                            } else {
                                // Default center content
                                VStack(spacing: 10) {
                                    Text("Categories")
                                        .font(.system(.headline))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                                    
                                    Text("\(categories.count)")
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    Text("Tap to view details")
                                        .font(.system(.caption))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray)
                                }
                                .transition(.opacity.combined(with: .scale))
                                .id("total")
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: selectedCategoryIndex)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    
                    // Category list section with improved spacing
                    VStack(spacing: 20) {
                        // Section header for list with sort menu
                        HStack {
                            Text("Spending by Category")
                                .font(.system(.headline))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Spacer()
                            
                            Menu {
                                Button("Default Order") {
                                    withAnimation {
                                        sortOrder = .default
                                    }
                                }
                                
                                Button("By Amount") {
                                    withAnimation {
                                        sortOrder = .amount
                                    }
                                }
                                
                                Button("By Percentage") {
                                    withAnimation {
                                        sortOrder = .percentage
                                    }
                                }
                                
                                Button("Alphabetical") {
                                    withAnimation {
                                        sortOrder = .alphabetical
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(sortOrder.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                                    
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(colorScheme == .dark ? Color(UIColor.tertiarySystemBackground) : Color.white)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .opacity(animate ? 1 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.3), value: animate)
                        
                        // Categories list with more spacing
                        VStack(spacing: 16) {
                            ForEach(0..<sortedCategories.count, id: \.self) { index in
                                let category = sortedCategories[index]
                                let originalIndex = categories.firstIndex { $0.category == category.category } ?? index
                                let isSelected = selectedCategoryIndex == originalIndex
                                
                                HStack(spacing: 16) {
                                    // Category icon
                                    ZStack {
                                        Circle()
                                            .fill(getCategoryColor(at: originalIndex).opacity(isSelected ? 1.0 : 0.9))
                                            .frame(width: 48, height: 48)
                                            .shadow(color: getCategoryColor(at: originalIndex).opacity(isSelected ? 0.3 : 0.1),
                                                    radius: isSelected ? 5 : 2,
                                                    x: 0,
                                                    y: isSelected ? 3 : 1)
                                        
                                        Image(systemName: category.icon)
                                            .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(.white)
                                    }
                                    .opacity(animate ? 1 : 0)
                                    .scaleEffect(animate ? (isSelected ? 1.1 : 1.0) : 0.5)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05 * Double(index)), value: animate)
                                    .animation(.spring(response: 0.3), value: selectedCategoryIndex)
                                    
                                    // Category details
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(category.category)
                                            .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                            .opacity(animate ? 1 : 0)
                                            .animation(.easeIn(duration: 0.5).delay(0.1 + 0.05 * Double(index)), value: animate)
                                        
                                        HStack(spacing: 4) {
                                            // Progress bar
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    // Background track
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(height: 8)
                                                    
                                                    // Fill
                                                    Capsule()
                                                        .fill(getCategoryColor(at: originalIndex).opacity(0.8))
                                                        .frame(width: animate ? geometry.size.width * CGFloat(category.percentage / 100) : 0, height: 8)
                                                        .animation(.easeInOut(duration: 1.2).delay(0.2 + 0.05 * Double(index)), value: animate)
                                                }
                                            }
                                            .frame(height: 8)
                                            .padding(.vertical, 2)
                                            
                                            // Percentage
                                            Text("\(Int(category.percentage))%")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(getCategoryColor(at: originalIndex))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(getCategoryColor(at: originalIndex).opacity(0.15))
                                                )
                                        }
                                        .opacity(animate ? 1 : 0)
                                        .animation(.easeIn(duration: 0.5).delay(0.15 + 0.05 * Double(index)), value: animate)
                                    }
                                    
                                    Spacer()
                                    
                                    // Amount
                                    Text("$\(String(format: "%.2f", category.amount))")
                                        .font(.system(size: 18, weight: isSelected ? .bold : .semibold))
                                        .foregroundColor(isSelected ? getCategoryColor(at: originalIndex) :
                                                            (colorScheme == .dark ? .white : .black))
                                        .opacity(animate ? 1 : 0)
                                        .animation(.easeIn(duration: 0.5).delay(0.2 + 0.05 * Double(index)), value: animate)
                                        .animation(.easeInOut(duration: 0.3), value: selectedCategoryIndex)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(colorScheme == .dark ?
                                              Color(UIColor.secondarySystemBackground) :
                                                Color.white)
                                        .shadow(color: isSelected ?
                                                getCategoryColor(at: originalIndex).opacity(0.25) :
                                                    Color.black.opacity(0.05),
                                                radius: isSelected ? 10 : 5,
                                                x: 0,
                                                y: isSelected ? 5 : 2)
                                )
                                .scaleEffect(isSelected ? 1.03 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedCategoryIndex)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(getCategoryColor(at: originalIndex).opacity(isSelected ? 0.5 : 0), lineWidth: 2)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        if selectedCategoryIndex == originalIndex {
                                            selectedCategoryIndex = nil
                                        } else {
                                            selectedCategoryIndex = originalIndex
                                        }
                                    }
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                .onHover { hovering in
                                    withAnimation {
                                        highlightedCategoryIndex = hovering ? originalIndex : nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                    .padding(.top, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(colorScheme == .dark ?
                                  Color(UIColor.systemBackground) :
                                    Color(UIColor.secondarySystemBackground))
                            .ignoresSafeArea(.all, edges: .bottom)
                    )
                }
                .padding(.bottom, 40)
            }
        }
   
       
        .onAppear {
            // Sequential animations for a more polished appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animate = true
                }
                
                // Add gentle rotation animation to the chart
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    chartRotation = -87
                }
                
                // Show detailed view after chart animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showDetails = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCategoryColor(at index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "FF6B6B"), // Bright Red
            Color(hex: "48BFE3"), // Sky Blue
            Color(hex: "5E60CE"), // Purple
            Color(hex: "64DFDF"), // Teal
            Color(hex: "80FFDB"), // Mint
            Color(hex: "FFADAD"), // Salmon
            Color(hex: "FFD6A5"), // Peach
            Color(hex: "FDFFB6"), // Yellow
            Color(hex: "CAFFBF"), // Lime
            Color(hex: "9BF6FF"), // Light Blue
            Color(hex: "BDB2FF"), // Lavender
            Color(hex: "FFC6FF")  // Pink
        ]
        return colors[index % colors.count]
    }
    
    private func getStartAngle(at index: Int, for categoryList: [(category: String, amount: Double, icon: String, percentage: Double)]) -> Double {
        if index == 0 {
            return 0
        }
        var sum: Double = 0
        for i in 0..<index {
            sum += categoryList[i].percentage
        }
        return sum * 3.6
    }
    
    private func getEndAngle(at index: Int, for categoryList: [(category: String, amount: Double, icon: String, percentage: Double)]) -> Double {
        var sum: Double = 0
        for i in 0...index {
            sum += categoryList[i].percentage
        }
        return sum * 3.6
    }
    
    // MARK: - Sharing Functions
    
    private func shareReport() {
        // Implement PDF export functionality
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // This would be implemented with PDFKit or similar
        print("Exporting to PDF...")
    }
    
    private func shareAsImage() {
        // Implement image sharing functionality
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // This would be implemented with UIGraphicsImageRenderer or similar
        print("Sharing as image...")
    }
    
    private func shareData() {
        // Implement data sharing functionality
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // This would be implemented by creating a CSV or similar
        print("Sharing data...")
    }
}
struct DailyBreakdownSection: View {
    let lastWeekData: [(day: String, date: String, income: Double, expense: Double)]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title aligned like other section titles
            Text("Breakdown")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 16)  // same as other titles

            // Scroll view for cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(lastWeekData.indices, id: \.self) { index in
                        let item = lastWeekData[index]
                        DailyBreakdownCard(
                            day: item.day,
                            date: item.date,
                            income: item.income,
                            expense: item.expense
                        )
                    }
                    .padding(.vertical, 8)
                }
                // Here, add horizontal padding to inset cards just a bit,
                // so cards start a bit inside but not fully padded like parent VStack.
                .padding(.horizontal, 18)
            }
        }
    }
}



// MARK: - Redesigned DailyBreakdownCard
struct DailyBreakdownCard: View {
    let day: String
    let date: String
    let income: Double
    let expense: Double
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient background
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(date)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(day.prefix(1))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Content section
            VStack(spacing: 14) {
                // Income row
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                        
                        Text("$\(String(format: "%.2f", income))")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    Spacer()
                }

                // Expense row
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expense")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                        
                        Text("$\(String(format: "%.2f", expense))")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }

                    Spacer()
                }

                // Net total
                Divider()
                    .padding(.horizontal, -16)

                HStack {
                    Text("Net")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)

                    Spacer()

                    let netAmount = income - expense
                    Text("$\(String(format: "%.2f", netAmount))")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(netAmount >= 0 ? .green : .red)
                }
            }
            .padding(16)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .consistentShadow(intensity: isPressed ? .strong : .medium, isElevated: isPressed)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation {
                        isPressed = false
                    }
                }
            }
        }
        .frame(width: 220)
    }
}

struct BreakdownData {
    let day: String
    let date: String
    let income: Double
    let expense: Double
}
struct InsightButton: View {
    let button: SummaryButton
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(button.gradient)
                    .frame(width: 48, height: 48)

                Image(systemName: button.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(button.title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : AppTheme.textPrimary)

                Text(button.subtitle)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : AppTheme.textSecondary)
        }
        .padding()
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : AppTheme.cardBg)
        .cornerRadius(16)
        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
    }
}


struct WeeklyStoryView: View {
    @State private var currentStoryIndex = 0
    @State private var progressValues: [CGFloat]
    @State private var timer: Timer? = nil
    let stories: [FinancialStory]
    @Binding var showStories: Bool
    @State private var isPaused = false
    @State private var animateValue = false

    init(stories: [FinancialStory], showStories: Binding<Bool>) {
        self.stories = stories
        self._showStories = showStories
        self._progressValues = State(initialValue: Array(repeating: 0, count: stories.count))
    }

    var body: some View {
        ZStack {
          
            stories[currentStoryIndex].backgroundColor
                           .ignoresSafeArea()
                       
            VStack {
                // Progress bars
                HStack(spacing: 4) {
                    ForEach(0..<stories.count, id: \.self) { index in
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .frame(height: 4)

                                Capsule()
                                    .foregroundColor(.white)
                                    .frame(width: geometry.size.width * progressValues[index], height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Header with Date
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading) {
                        Text("Weekly Insights")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(weekDateRangeFormatted())
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Button(action: { showStories = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Main content
                VStack(alignment: .center, spacing: 24) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(stories[currentStoryIndex].emoji)
                                .font(.system(size: 60))
                        )

                    Text(stories[currentStoryIndex].title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    Text(stories[currentStoryIndex].value)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(animateValue ? 1.0 : 0.8)
                        .opacity(animateValue ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animateValue)

                    HStack(spacing: 6) {
                        Image(systemName: stories[currentStoryIndex].isPositive ? "arrow.up.right" : "arrow.down.right")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(
                                stories[currentStoryIndex].isPositive ?
                                AppTheme.incomeColor.opacity(0.7) :
                                AppTheme.expenseColor.opacity(0.7)
                            )
                            .cornerRadius(8)

                        Text(stories[currentStoryIndex].change)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Tap areas for navigation
                HStack(spacing: 0) {
                    Rectangle()
                        .opacity(0.001)
                        .onTapGesture { goToPreviousStory() }

                    Rectangle()
                        .opacity(0.001)
                        .onTapGesture { goToNextStory() }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pauseStory() }
                .onEnded { _ in resumeStory() }
        )
        .onAppear {
            startTimer()
            withAnimation {
                animateValue = true
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: currentStoryIndex) { _ in
            animateValue = false
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation {
                    animateValue = true
                }
            }
        }
    }

  
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !isPaused, progressValues[currentStoryIndex] < 1.0 {
                progressValues[currentStoryIndex] += 0.005
            } else if !isPaused {
                goToNextStory()
            }
        }
    }

    func pauseStory() {
        isPaused = true
        timer?.invalidate()
    }

    func resumeStory() {
        isPaused = false
        startTimer()
    }

    func goToNextStory() {
        if currentStoryIndex < stories.count - 1 {
            progressValues[currentStoryIndex] = 1.0
            currentStoryIndex += 1
            startTimer()
        } else {
            showStories = false // Close stories when last one ends
        }
    }

    func goToPreviousStory() {
        if currentStoryIndex > 0 {
            progressValues[currentStoryIndex] = 0
            currentStoryIndex -= 1
            progressValues[currentStoryIndex] = 0
            startTimer()
        }
    }
}
#Preview {
    InsightsView(viewModel: BudgetViewModel())
}

import SwiftUI
import Charts

// A dedicated class for managing financial stories
class StoryManager: ObservableObject {
    @Published var weeklyStory: [FinancialStory] = []
    @Published var monthlyStory: [FinancialStory] = []
    @Published var lastWeeklyUpdateDate: Date?
    @Published var lastMonthlyUpdateDate: Date?
    
    private var transactions: [Transaction] = []
    
    // Call this whenever the transaction list changes
    func updateTransactions(_ newTransactions: [Transaction]) {
        self.transactions = newTransactions
        checkAndGenerateStories()
        saveStories()
    }
    
    // This would be triggered by the app at launch
    func loadStoredStories() {
        // Load saved stories
        if let savedWeeklyStory = UserDefaults.standard.data(forKey: "weeklyStory") {
            if let decodedStory = try? JSONDecoder().decode([FinancialStory].self, from: savedWeeklyStory) {
                self.weeklyStory = decodedStory
            }
        }
        
        if let savedMonthlyStory = UserDefaults.standard.data(forKey: "monthlyStory") {
            if let decodedStory = try? JSONDecoder().decode([FinancialStory].self, from: savedMonthlyStory) {
                self.monthlyStory = decodedStory
            }
        }
        
        // Load last update timestamps
        lastWeeklyUpdateDate = UserDefaults.standard.object(forKey: "lastWeeklyUpdate") as? Date
        lastMonthlyUpdateDate = UserDefaults.standard.object(forKey: "lastMonthlyUpdate") as? Date
    }
    
    private func saveStories() {
        if let encoded = try? JSONEncoder().encode(weeklyStory) {
            UserDefaults.standard.set(encoded, forKey: "weeklyStory")
        }
        
        if let encoded = try? JSONEncoder().encode(monthlyStory) {
            UserDefaults.standard.set(encoded, forKey: "monthlyStory")
        }
    }
    
    func checkAndGenerateStories() {
        let currentDate = Date()
        
        // Check if weekly story needs update (every Monday or first run)
        if shouldUpdateWeekly(currentDate: currentDate) {
            generateWeeklyStory()
            lastWeeklyUpdateDate = currentDate
            UserDefaults.standard.set(currentDate, forKey: "lastWeeklyUpdate")
        }
        
        // Check if monthly story needs update (first day of month or first run)
        if shouldUpdateMonthly(currentDate: currentDate) {
            generateMonthlyStory()
            lastMonthlyUpdateDate = currentDate
            UserDefaults.standard.set(currentDate, forKey: "lastMonthlyUpdate")
        }
    }
    
    private func shouldUpdateWeekly(currentDate: Date) -> Bool {
        // Update weekly story if:
        // 1. We've never generated a weekly story before
        // 2. It's been at least 7 days since the last update
        // 3. It's Monday (weekday == 2) and we haven't updated today
        
        if lastWeeklyUpdateDate == nil {
            // If no data, check if it's Monday
            let calendar = Calendar.current
            let isMonday = calendar.component(.weekday, from: currentDate) == 2
            
            // Only generate a story on Monday if there's no previous data
            return isMonday && !transactions.isEmpty
        }
        
        let calendar = Calendar.current
        
        // Check if it's Monday and we haven't updated today
        let isToday = calendar.isDate(lastWeeklyUpdateDate!, inSameDayAs: currentDate)
        let isMonday = calendar.component(.weekday, from: currentDate) == 2
        
        if isMonday && !isToday {
            return true
        }
        
        // Check if it's been at least 7 days
        if let lastUpdate = lastWeeklyUpdateDate,
           let daysSinceLastUpdate = calendar.dateComponents([.day], from: lastUpdate, to: currentDate).day,
           daysSinceLastUpdate >= 7 {
            return true
        }
        
        return false
    }
    
    private func shouldUpdateMonthly(currentDate: Date) -> Bool {
        // Update monthly story if:
        // 1. We've never generated a monthly story before
        // 2. It's the first day of the month and we haven't updated today
        
        if lastMonthlyUpdateDate == nil {
            // If no data, check if it's the first of the month
            let calendar = Calendar.current
            let isFirstOfMonth = calendar.component(.day, from: currentDate) == 1
            
            // Only generate a story on the first of month if there's no previous data
            return isFirstOfMonth && !transactions.isEmpty
        }
        
        let calendar = Calendar.current
        
        // Check if it's the first day of the month and we haven't updated today
        let isToday = calendar.isDate(lastMonthlyUpdateDate!, inSameDayAs: currentDate)
        let dayOfMonth = calendar.component(.day, from: currentDate)
        
        if dayOfMonth == 1 && !isToday {
            return true
        }
        
        return false
    }
    
    func generateWeeklyStory() {
        // Check if there are any transactions before proceeding
        if transactions.isEmpty {
            weeklyStory = []
            return
        }
        
        // Calculate metrics for the week that just FINISHED
        let calendar = Calendar.current
        let today = Date()
        
        // Find the most recent Monday (start of current week)
        var mostRecentMonday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        // The end of last week is the day before the most recent Monday
        let endOfLastWeek = calendar.date(byAdding: .day, value: -1, to: mostRecentMonday)!
        
        // The start of last week is 7 days before the end of last week
        let startOfLastWeek = calendar.date(byAdding: .day, value: -6, to: endOfLastWeek)!
        
        // The end of two weeks ago is the day before the start of last week
        let endOfTwoWeeksAgo = calendar.date(byAdding: .day, value: -1, to: startOfLastWeek)!
        
        // The start of two weeks ago is 7 days before the end of two weeks ago
        let startOfTwoWeeksAgo = calendar.date(byAdding: .day, value: -6, to: endOfTwoWeeksAgo)!
        
        // Last week's expenses (week that just finished)
        let lastWeekExpenses = transactions.filter { $0.type == .expense && $0.date >= startOfLastWeek && $0.date <= endOfLastWeek }
        let lastWeekSpending = lastWeekExpenses.reduce(0) { $0 + $1.amount }
        
        // Two weeks ago metrics for comparison
        let twoWeeksAgoExpenses = transactions.filter { $0.type == .expense && $0.date >= startOfTwoWeeksAgo && $0.date <= endOfTwoWeeksAgo }
        let twoWeeksAgoSpending = twoWeeksAgoExpenses.reduce(0) { $0 + $1.amount }
        
        // Calculate change
        let spendingChange = twoWeeksAgoSpending != 0 ? lastWeekSpending - twoWeeksAgoSpending : lastWeekSpending
        
        // Find top spending category for last week
        let expensesByCategory = Dictionary(grouping: lastWeekExpenses) { $0.category }
        let categorySums = expensesByCategory.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }
        
        let topCategory = categorySums.max(by: { $0.value < $1.value })
        
        // Calculate balance for the last week
        let lastWeekIncome = transactions.filter { $0.type == .income && $0.date >= startOfLastWeek && $0.date <= endOfLastWeek }.reduce(0) { $0 + $1.amount }
        let lastWeekExpense = transactions.filter { $0.type == .expense && $0.date >= startOfLastWeek && $0.date <= endOfLastWeek }.reduce(0) { $0 + $1.amount }
        let lastWeekBalance = lastWeekIncome - lastWeekExpense
        
        // Create the weekly stories
        var stories: [FinancialStory] = []
        
        // Format date range for the title
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let startDateStr = dateFormatter.string(from: startOfLastWeek)
        let endDateStr = dateFormatter.string(from: endOfLastWeek)
        let dateRangeStr = "\(startDateStr) - \(endDateStr)"
        
        // 1. Weekly Spending Story
        stories.append(
            FinancialStory(
                title: "Last Week's Spending",
                value: "$\(String(format: "%.2f", lastWeekSpending))",
                change: spendingChange >= 0 ? "+$\(String(format: "%.2f", abs(spendingChange)))" : "-$\(String(format: "%.2f", abs(spendingChange)))",
                isPositive: spendingChange < 0, // Less spending = positive
                emoji: "💰",
                backgroundColor: AppTheme.primary
            )
        )
        
        // 2. Top Category Story
        if let top = topCategory {
            stories.append(
                FinancialStory(
                    title: "Top Category (\(dateRangeStr))",
                    value: top.key,
                    change: "$\(String(format: "%.2f", top.value))",
                    isPositive: false,
                    emoji: "🛒",
                    backgroundColor: AppTheme.secondary
                )
            )
        } else {
            stories.append(
                FinancialStory(
                    title: "Top Category (\(dateRangeStr))",
                    value: "No Expenses",
                    change: "$0.00",
                    isPositive: true,
                    emoji: "🛒",
                    backgroundColor: AppTheme.secondary
                )
            )
        }
        
        // 3. Weekly Balance Story
        stories.append(
            FinancialStory(
                title: "Last Week's Balance",
                value: "$\(String(format: "%.2f", lastWeekBalance))",
                change: spendingChange >= 0 ? "-$\(String(format: "%.2f", abs(spendingChange)))" : "+$\(String(format: "%.2f", abs(spendingChange)))",
                isPositive: spendingChange < 0,
                emoji: "✨",
                backgroundColor: AppTheme.accent
            )
        )
        
        // 4. NEW: Most Frequent Expense Story
        let frequencyByCategory = Dictionary(grouping: lastWeekExpenses) { $0.category }
        let categoryFrequencies = frequencyByCategory.mapValues { $0.count }
        let mostFrequentCategory = categoryFrequencies.max(by: { $0.value < $1.value })
        
        if let mostFrequent = mostFrequentCategory {
            let categoryAmount = lastWeekExpenses.filter { $0.category == mostFrequent.key }.reduce(0) { $0 + $1.amount }
            stories.append(
                FinancialStory(
                    title: "Most Frequent Expense",
                    value: mostFrequent.key,
                    change: "\(mostFrequent.value) transactions",
                    isPositive: false,
                    emoji: "🔄",
                    backgroundColor: Color(hex: "FF7D6B")
                )
            )
        }
        
        // 5. NEW: Income Trend Story
        let twoWeeksAgoIncome = transactions.filter { $0.type == .income && $0.date >= startOfTwoWeeksAgo && $0.date <= endOfTwoWeeksAgo }.reduce(0) { $0 + $1.amount }
        let incomeChange = twoWeeksAgoIncome != 0 ? lastWeekIncome - twoWeeksAgoIncome : lastWeekIncome
        let incomeChangePercentage = twoWeeksAgoIncome != 0 ? (incomeChange / twoWeeksAgoIncome) * 100 : 100
        
        stories.append(
            FinancialStory(
                title: "Income Trend",
                value: "$\(String(format: "%.2f", lastWeekIncome))",
                change: incomeChange >= 0 ? "+\(String(format: "%.1f", abs(incomeChangePercentage)))%" : "-\(String(format: "%.1f", abs(incomeChangePercentage)))%",
                isPositive: incomeChange >= 0,
                emoji: "📈",
                backgroundColor: Color(hex: "4CAF50")
            )
        )
        
        // 6. NEW: Savings Story
        let lastWeekSavings = transactions.filter { $0.type == .savings && $0.date >= startOfLastWeek && $0.date <= endOfLastWeek }.reduce(0) { $0 + $1.amount }
        let twoWeeksAgoSavings = transactions.filter { $0.type == .savings && $0.date >= startOfTwoWeeksAgo && $0.date <= endOfTwoWeeksAgo }.reduce(0) { $0 + $1.amount }
        let savingsChange = twoWeeksAgoSavings != 0 ? lastWeekSavings - twoWeeksAgoSavings : lastWeekSavings
        
        stories.append(
            FinancialStory(
                title: "Weekly Savings",
                value: "$\(String(format: "%.2f", lastWeekSavings))",
                change: savingsChange >= 0 ? "+$\(String(format: "%.2f", abs(savingsChange)))" : "-$\(String(format: "%.2f", abs(savingsChange)))",
                isPositive: savingsChange >= 0,
                emoji: "🏦",
                backgroundColor: Color(hex: "63C7FF")
            )
        )
        
        self.weeklyStory = stories
    }
    
    func generateMonthlyStory() {
        // Check if there are any transactions before proceeding
        if transactions.isEmpty {
            monthlyStory = []
            return
        }
        
        // Calculate metrics for the month that JUST FINISHED, not the current one
        let calendar = Calendar.current
        let today = Date()
        
        // Get start of current month
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        
        // Get start of previous month (the month that just finished)
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth)!
        
        // Get end of previous month (which is right before start of current month)
        let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfCurrentMonth)!
        
        // Get start of two months ago (for comparison)
        let startOfTwoMonthsAgo = calendar.date(byAdding: .month, value: -1, to: startOfLastMonth)!
        
        // Get end of two months ago (which is right before start of last month)
        let endOfTwoMonthsAgo = calendar.date(byAdding: .second, value: -1, to: startOfLastMonth)!
        
        // Last month's expenses (month that just finished)
        let lastMonthExpenses = transactions.filter { $0.type == .expense && $0.date >= startOfLastMonth && $0.date <= endOfLastMonth }
        let lastMonthSpending = lastMonthExpenses.reduce(0) { $0 + $1.amount }
        
        // Two months ago metrics for comparison
        let twoMonthsAgoExpenses = transactions.filter { $0.type == .expense && $0.date >= startOfTwoMonthsAgo && $0.date <= endOfTwoMonthsAgo }
        let twoMonthsAgoSpending = twoMonthsAgoExpenses.reduce(0) { $0 + $1.amount }
        
        // Calculate change
        let spendingChange = twoMonthsAgoSpending != 0 ? lastMonthSpending - twoMonthsAgoSpending : lastMonthSpending
        
        // Calculate savings trend for the last month
        let lastMonthSavings = transactions.filter { $0.type == .savings && $0.date >= startOfLastMonth && $0.date <= endOfLastMonth }.reduce(0) { $0 + $1.amount }
        let twoMonthsAgoSavings = transactions.filter { $0.type == .savings && $0.date >= startOfTwoMonthsAgo && $0.date <= endOfTwoMonthsAgo }.reduce(0) { $0 + $1.amount }
        let savingsChange = lastMonthSavings - twoMonthsAgoSavings
        
        // Calculate investment performance for the last month
        let lastMonthInvestments = transactions.filter { $0.type == .investment && $0.date >= startOfLastMonth && $0.date <= endOfLastMonth }.reduce(0) { $0 + $1.amount }
        
        // Format last month name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let lastMonthName = dateFormatter.string(from: startOfLastMonth)
        
        // Create monthly stories
        var stories: [FinancialStory] = []
        
        // 1. Monthly Spending Story
        stories.append(
            FinancialStory(
                title: "\(lastMonthName) Spending",
                value: "$\(String(format: "%.2f", lastMonthSpending))",
                change: spendingChange >= 0 ? "+$\(String(format: "%.2f", abs(spendingChange)))" : "-$\(String(format: "%.2f", abs(spendingChange)))",
                isPositive: spendingChange < 0, // Less spending = positive
                emoji: "📊",
                backgroundColor: AppTheme.primary
            )
        )
        
        // 2. Savings Story
        stories.append(
            FinancialStory(
                title: "\(lastMonthName) Savings",
                value: "$\(String(format: "%.2f", lastMonthSavings))",
                change: savingsChange >= 0 ? "+$\(String(format: "%.2f", abs(savingsChange)))" : "-$\(String(format: "%.2f", abs(savingsChange)))",
                isPositive: savingsChange >= 0,
                emoji: "💸",
                backgroundColor: Color(hex: "63C7FF")
            )
        )
        
        // Find top spending category for last month
        let expensesByCategory = Dictionary(grouping: lastMonthExpenses) { $0.category }
        let categorySums = expensesByCategory.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }
        
        let topCategory = categorySums.max(by: { $0.value < $1.value })
        
        // 3. Top Category Story instead of Investment Story
        if let top = topCategory {
            stories.append(
                FinancialStory(
                    title: "Top Category (\(lastMonthName))",
                    value: top.key,
                    change: "$\(String(format: "%.2f", top.value))",
                    isPositive: false,
                    emoji: "🛒",
                    backgroundColor: Color(hex: "8676FF")
                )
            )
        } else {
            stories.append(
                FinancialStory(
                    title: "Top Category (\(lastMonthName))",
                    value: "No Expenses",
                    change: "$0.00",
                    isPositive: true,
                    emoji: "🛒",
                    backgroundColor: Color(hex: "8676FF")
                )
            )
        }
        
        // 4. NEW: Income vs Expenses Story
        let lastMonthIncome = transactions.filter { $0.type == .income && $0.date >= startOfLastMonth && $0.date <= endOfLastMonth }.reduce(0) { $0 + $1.amount }
        let incomeToExpenseRatio = lastMonthIncome != 0 ? (lastMonthSpending / lastMonthIncome) * 100 : 0
        let monthlyBalance = lastMonthIncome - lastMonthSpending
        
        stories.append(
            FinancialStory(
                title: "Monthly Balance",
                value: "$\(String(format: "%.2f", monthlyBalance))",
                change: "\(String(format: "%.1f", incomeToExpenseRatio))% of income spent",
                isPositive: monthlyBalance >= 0,
                emoji: "⚖️",
                backgroundColor: Color(hex: "FF9800")
            )
        )
        
        // 5. NEW: Investment Performance Story
        let twoMonthsAgoInvestments = transactions.filter { $0.type == .investment && $0.date >= startOfTwoMonthsAgo && $0.date <= endOfTwoMonthsAgo }.reduce(0) { $0 + $1.amount }
        let investmentChange = lastMonthInvestments - twoMonthsAgoInvestments
        
        stories.append(
            FinancialStory(
                title: "Investment Activity",
                value: "$\(String(format: "%.2f", lastMonthInvestments))",
                change: investmentChange >= 0 ? "+$\(String(format: "%.2f", abs(investmentChange)))" : "-$\(String(format: "%.2f", abs(investmentChange)))",
                isPositive: investmentChange >= 0,
                emoji: "📈",
                backgroundColor: Color(hex: "4CAF50")
            )
        )
        
        // 6. NEW: Spending per Category Growth
        // Find category with highest growth
        let twoMonthsAgoExpensesByCategory = Dictionary(grouping: twoMonthsAgoExpenses) { $0.category }
        let twoMonthsAgoCategorySums = twoMonthsAgoExpensesByCategory.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }
        
        var categoryGrowth: [String: Double] = [:]
        for (category, amount) in categorySums {
            let previousAmount = twoMonthsAgoCategorySums[category] ?? 0
            if previousAmount > 0 {
                categoryGrowth[category] = ((amount - previousAmount) / previousAmount) * 100
            } else if amount > 0 {
                categoryGrowth[category] = 100
            }
        }
        
        let highestGrowthCategory = categoryGrowth.max(by: { $0.value < $1.value })
        
        if let highest = highestGrowthCategory, highest.value > 0 {
            stories.append(
                FinancialStory(
                    title: "Fastest Growing Expense",
                    value: highest.key,
                    change: "+\(String(format: "%.1f", highest.value))%",
                    isPositive: false,
                    emoji: "🔥",
                    backgroundColor: Color(hex: "F44336")
                )
            )
        } else if let highest = categoryGrowth.min(by: { $0.value > $1.value }), highest.value < 0 {
            stories.append(
                FinancialStory(
                    title: "Most Reduced Expense",
                    value: highest.key,
                    change: "\(String(format: "%.1f", highest.value))%",
                    isPositive: true,
                    emoji: "📉",
                    backgroundColor: Color(hex: "4CAF50")
                )
            )
        }
        
        self.monthlyStory = stories
    }
    
    // Helper methods to check if stories are available
    func hasWeeklyStory() -> Bool {
        return !weeklyStory.isEmpty
    }
    
    func hasMonthlyStory() -> Bool {
        return !monthlyStory.isEmpty
    }
}
struct MonthlyStoryView: View {
    @State private var currentStoryIndex = 0
    @State private var progressValues: [CGFloat]
    @State private var timer: Timer? = nil
    let stories: [FinancialStory]
    @Binding var showStories: Bool
    @State private var isPaused = false
    @State private var animateValue = false

    init(stories: [FinancialStory], showStories: Binding<Bool>) {
        self.stories = stories
        self._showStories = showStories
        self._progressValues = State(initialValue: Array(repeating: 0, count: stories.count))
    }

    var body: some View {
        ZStack {
            // Fallback background (in case dynamic one fails)
            AppTheme.primary
                .ignoresSafeArea()
            
            // Actual story-specific background
            stories[currentStoryIndex].backgroundColor
                .ignoresSafeArea()

            VStack {
                // Progress bars
                HStack(spacing: 4) {
                    ForEach(0..<stories.count, id: \.self) { index in
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .frame(height: 4)

                                Capsule()
                                    .foregroundColor(.white)
                                    .frame(width: geometry.size.width * progressValues[index], height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Header with Date
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading) {
                        Text("Monthly Insights")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(monthNameFormatted())
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Button(action: { showStories = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Main content
                VStack(alignment: .center, spacing: 24) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(stories[currentStoryIndex].emoji)
                                .font(.system(size: 60))
                        )

                    Text(stories[currentStoryIndex].title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    Text(stories[currentStoryIndex].value)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(animateValue ? 1.0 : 0.8)
                        .opacity(animateValue ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animateValue)

                    HStack(spacing: 6) {
                        if !stories[currentStoryIndex].title.contains("Investments") {
                            Image(systemName: stories[currentStoryIndex].isPositive ? "arrow.up.right" : "arrow.down.right")
                                .foregroundColor(.white)
                                .padding(6)
                                .background(
                                    stories[currentStoryIndex].isPositive ?
                                    AppTheme.incomeColor.opacity(0.7) :
                                    AppTheme.expenseColor.opacity(0.7)
                                )
                                .cornerRadius(8)
                        }

                        Text(stories[currentStoryIndex].change)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Tap areas for navigation
                HStack(spacing: 0) {
                    Rectangle()
                        .opacity(0.001)
                        .onTapGesture { goToPreviousStory() }

                    Rectangle()
                        .opacity(0.001)
                        .onTapGesture { goToNextStory() }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pauseStory() }
                .onEnded { _ in resumeStory() }
        )
        .onAppear {
            startTimer()
            withAnimation {
                animateValue = true
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: currentStoryIndex) { _ in
            animateValue = false
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation {
                    animateValue = true
                }
            }
        }
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !isPaused, progressValues[currentStoryIndex] < 1.0 {
                progressValues[currentStoryIndex] += 0.005
            } else if !isPaused {
                goToNextStory()
            }
        }
    }

    func pauseStory() {
        isPaused = true
        timer?.invalidate()
    }

    func resumeStory() {
        isPaused = false
        startTimer()
    }

    func goToNextStory() {
        if currentStoryIndex < stories.count - 1 {
            progressValues[currentStoryIndex] = 1.0
            currentStoryIndex += 1
            startTimer()
        } else {
            showStories = false
        }
    }

    func goToPreviousStory() {
        if currentStoryIndex > 0 {
            progressValues[currentStoryIndex] = 0
            currentStoryIndex -= 1
            progressValues[currentStoryIndex] = 0
            startTimer()
        }
    }
}
private func monthNameFormatted() -> String {
    let calendar = Calendar.current
    let today = Date()
    
    // Get the start of current month
    let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
    
    // Get the previous month (the month that just finished)
    let previousMonth = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth)!
    
    // Format the date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM yyyy"
    return dateFormatter.string(from: previousMonth)
}

// MARK: - Fixed Weekly date range formatter
private func weekDateRangeFormatted() -> String {
    let calendar = Calendar.current
    let today = Date()
    
    // Find the most recent Monday (start of current week)
    var mostRecentMonday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
    
    // The end of last week is the day before the most recent Monday
    let endOfLastWeek = calendar.date(byAdding: .day, value: -1, to: mostRecentMonday)!
    
    // The start of last week is 7 days before the end of last week
    let startOfLastWeek = calendar.date(byAdding: .day, value: -6, to: endOfLastWeek)!
    
    // Format the dates
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM d"
    
    // For the end date, check if it's in the same month
    let startMonth = calendar.component(.month, from: startOfLastWeek)
    let endMonth = calendar.component(.month, from: endOfLastWeek)
    
    let startDateString = dateFormatter.string(from: startOfLastWeek)
    
    if startMonth == endMonth {
        // If same month, just show the day for end date
        dateFormatter.dateFormat = "d"
    }
    
    let endDateString = dateFormatter.string(from: endOfLastWeek)
    
    return "\(startDateString) - \(endDateString)"
}
