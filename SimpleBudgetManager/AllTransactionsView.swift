//
//  AllTransactionsView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 12/15/24.
//
import SwiftUI

struct AllTransactionsView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var selectedTransactions: Set<UUID> = []
    @State private var isEditing = false
    @State private var showAlert = false
    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedSort: TransactionSort = .dateDescending
    @State private var isCustomSorting = false // Track if custom sorting is active
    @State private var selectedDate: Date? = nil // Store selected date from calendar
    @State private var showCalendar = false // Control calendar sheet presentation
    @Environment(\.colorScheme) var colorScheme
    
    // New properties for search suggestions
    @State private var searchSuggestions: [String] = []
    @State private var showSuggestions: Bool = false
    @State private var recentSearches: [String] = []
    @FocusState private var isSearchFocused: Bool
    
    
    
    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case income = "Income"
        case expense = "Expense"
        case investment = "Investment"
        case savings = "Savings"
        
        var id: String { self.rawValue }
    }
    
    enum TransactionSort: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case amountHighToLow = "Amount: High to Low"
        case amountLowToHigh = "Amount: Low to High"
        case none = "Reset Sort"
        
        var id: String { self.rawValue }
    }
    
    var filteredTransactions: [Transaction] {
        // First filter by date if selected
        let dateFiltered: [Transaction]
        if let selectedDate = selectedDate {
            let calendar = Calendar.current
            dateFiltered = viewModel.transactions.filter {
                calendar.isDate($0.date, inSameDayAs: selectedDate)
            }
        } else {
            dateFiltered = viewModel.transactions
        }
        
        // Then filter by search text
        let searchFiltered = searchText.isEmpty
            ? dateFiltered
            : dateFiltered.filter {
                $0.category.lowercased().contains(searchText.lowercased()) ||
                $0.notes?.lowercased().contains(searchText.lowercased()) ?? false
            }
        
        // Then filter by transaction type
        let typeFiltered: [Transaction]
        switch selectedFilter {
        case .income:
            typeFiltered = searchFiltered.filter { $0.type == .income }
        case .expense:
            typeFiltered = searchFiltered.filter { $0.type == .expense }
        case .investment:
            typeFiltered = searchFiltered.filter { $0.type == .investment }
        case .savings:
            typeFiltered = searchFiltered.filter { $0.type == .savings }
        case .all:
            typeFiltered = searchFiltered
        }
        
        // Then sort
        var sortedTransactions = typeFiltered
        
        if isCustomSorting {
            switch selectedSort {
            case .dateDescending:
                sortedTransactions.sort { $0.date > $1.date }
            case .dateAscending:
                sortedTransactions.sort { $0.date < $1.date }
            case .amountHighToLow:
                sortedTransactions.sort { abs($0.amount) > abs($1.amount) }
            case .amountLowToHigh:
                sortedTransactions.sort { abs($0.amount) < abs($1.amount) }
            case .none:
                sortedTransactions.sort { $0.date > $1.date }
            }
        } else {
            // Default sort
            sortedTransactions.sort { $0.date > $1.date }
        }
        
        return sortedTransactions
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter buttons in horizontal scroll view
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // Calendar button (new)
                        Button(action: {
                            showCalendar = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: selectedDate != nil ? "calendar.badge.clock" : "calendar")
                                    .font(.system(size: 12))
                                Text(selectedDate != nil ? formattedSelectedDate : "Calendar")
                                    .font(.custom("Roboto-Medium", size: 14))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                selectedDate != nil
                                ? bluePurpleColor.opacity(colorScheme == .dark ? 0.7 : 0.2)
                                : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1)
                            )
                            .foregroundColor(
                                selectedDate != nil
                                ? (colorScheme == .dark ? .white : bluePurpleColor)
                                : (colorScheme == .dark ? .white : .gray)
                            )
                            .cornerRadius(10)
                        }
                        
                        // Sort button
                        Menu {
                            Button(action: {
                                selectedSort = .dateDescending
                                isCustomSorting = true
                            }) {
                                Label("Newest First", systemImage: "arrow.down")
                            }
                            
                            Button(action: {
                                selectedSort = .dateAscending
                                isCustomSorting = true
                            }) {
                                Label("Oldest First", systemImage: "arrow.up")
                            }
                            
                            Button(action: {
                                selectedSort = .amountHighToLow
                                isCustomSorting = true
                            }) {
                                Label("Amount: High to Low", systemImage: "dollarsign.circle")
                            }
                            
                            Button(action: {
                                selectedSort = .amountLowToHigh
                                isCustomSorting = true
                            }) {
                                Label("Amount: Low to High", systemImage: "dollarsign.circle")
                            }
                            
                            Button(action: {
                                selectedSort = .none
                                isCustomSorting = false
                            }) {
                                Label("Reset Sort", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 12))
                                Text("Sort")
                                    .font(.custom("Roboto-Medium", size: 14))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                isCustomSorting
                                ? bluePurpleColor.opacity(colorScheme == .dark ? 0.7 : 0.2)
                                : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1)
                            )
                            .foregroundColor(
                                isCustomSorting
                                ? (colorScheme == .dark ? .white : bluePurpleColor)
                                : (colorScheme == .dark ? .white : .gray)
                            )
                            .cornerRadius(10)
                        }

                        Divider()
                            .frame(height: 20)
                            .padding(.horizontal, 4)

                        // Filter buttons
                        TransactionFilterButton(
                            title: "All",
                            isSelected: selectedFilter == .all,
                            color: Color.gray
                        ) {
                            selectedFilter = .all
                        }
                        
                        TransactionFilterButton(
                            title: "Income",
                            isSelected: selectedFilter == .income,
                            color: colorForTransactionType(.income)
                        ) {
                            selectedFilter = .income
                        }
                        
                        TransactionFilterButton(
                            title: "Expense",
                            isSelected: selectedFilter == .expense,
                            color: colorForTransactionType(.expense)
                        ) {
                            selectedFilter = .expense
                        }
                        
                        TransactionFilterButton(
                            title: "Investment",
                            isSelected: selectedFilter == .investment,
                            color: colorForTransactionType(.investment)
                        ) {
                            selectedFilter = .investment
                        }
                        
                        TransactionFilterButton(
                            title: "Savings",
                            isSelected: selectedFilter == .savings,
                            color: colorForTransactionType(.savings)
                        ) {
                            selectedFilter = .savings
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .zIndex(1)
                
                // Enhanced search bar with suggestions
                enhancedSearchBar
                
                // Transaction count display
                if !filteredTransactions.isEmpty {
                    HStack {
                        Text("\(filteredTransactions.count) transaction\(filteredTransactions.count == 1 ? "" : "s") found")
                            .font(.custom("Roboto-Regular", size: 12))
                            .foregroundColor(Color.gray.opacity(0.7))
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                        Spacer()
                    }
                }
                
                // Main content
                ZStack {
                    if isLoading {
                        LoadingView()
                    } else {
                        if filteredTransactions.isEmpty {
                            EmptyTransactionsView(
                                title: selectedDate != nil ? "No Transactions on \(formattedSelectedDate)" : "No Transactions Found",
                                message: selectedDate != nil ? "Try selecting a different date or clear the date filter." : "Adjust your search or filters to see more transactions."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Use the new flat list view that preserves sorting
                            FlatTransactionListViewContent()
                        }
                    }
                    
                    // Search suggestions overlay
                    if showSuggestions && !searchSuggestions.isEmpty {
                        searchSuggestionsOverlay
                            .zIndex(2)
                    }
                }
                
                // Delete toolbar for selection mode
                if isEditing {
                    deleteToolbar
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: { isPresented = false }) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                            .frame(width: 25, height: 25)
                        
                        Image(systemName: "xmark")
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.top, 6)
                    .padding(.leading, 2)
                },
                trailing: HStack {
                    if selectedDate != nil {
                        Button(action: {
                            selectedDate = nil
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(Color.red)
                                .font(.system(size: 14))
                        }
                        .padding(.trailing, 2)
                    }
                    
                    Button(isEditing ? "Done" : "Select") {
                        toggleEditMode()
                    }
                    .foregroundColor(bluePurpleColor)
                }
            )
            .onAppear {
                simulateLoading()
                loadRecentSearches()
                updateSearchSuggestions()
            }
            .onChange(of: searchText) { oldValue, newValue in
                updateSearchSuggestions()
                showSuggestions = isSearchFocused && !newValue.isEmpty
            }
            .onChange(of: isSearchFocused) { oldValue, newValue in
                if newValue && !searchText.isEmpty {
                    showSuggestions = true
                } else {
                    // Add a slight delay to allow for suggestion selection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showSuggestions = false
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Are you sure?"),
                    message: Text("This will delete \(selectedTransactions.count) transactions."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteSelectedTransactions()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showCalendar) {
                CalendarPickerView(selectedDate: $selectedDate, showCalendar: $showCalendar)
                    .presentationDetents([.fraction(0.65)])
                                    .presentationDragIndicator(.visible)
                                    .accentColor(bluePurpleColor)
            }
        }
    }
    
    // Navigation title that reflects the current filter state
    var navigationTitle: String {
        if let selectedDate = selectedDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: selectedDate))"
        } else {
            return "All Transactions"
        }
    }
    
    // Formatted selected date for the calendar button
    var formattedSelectedDate: String {
        guard let date = selectedDate else { return "Calendar" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private var enhancedSearchBar: some View {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                            .padding(.leading, 4)
                        
                        TextField("Search by category or notes", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .focused($isSearchFocused)
                            .padding(.vertical, 6)
                            .autocorrectionDisabled(true)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                showSuggestions = false
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 20, height: 20)
                                        .padding(.trailing, 4)
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 4)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color(UIColor.secondarySystemBackground))
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    
    // Enhanced search suggestions overlay
        private var searchSuggestionsOverlay: some View {
            VStack(spacing: 0) {
                Spacer().frame(height: 0)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Display search suggestions
                    ForEach(searchSuggestions.prefix(4), id: \.self) { suggestion in
                        suggestionRow(suggestion, isRecent: false)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 5)
                )
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            }
        }
        
        // Enhanced suggestion row with improved styling
        private func suggestionRow(_ suggestion: String, isRecent: Bool) -> some View {
            Button(action: {
                searchText = suggestion
                addToRecentSearches(suggestion)
                showSuggestions = false
                isSearchFocused = false
            }) {
                HStack {
                    Image(systemName: isRecent ? "clock" : "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    Text(suggestion)
                        .font(.system(size: 15))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.clear)
        }
        
    
    // Updated LoadingView component
    @ViewBuilder
    private func LoadingView() -> some View {
        VStack {
            BouncingCirclesLoadingView()
                .frame(width: 100, height: 100)
                .padding()
            Text("").font(Font.custom("Sora-Bold", size: 20))
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, -50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    
    @ViewBuilder
    private func FlatTransactionListViewContent() -> some View {
        // Get all sorted transactions
        let sortedTransactions = filteredTransactions
        
        // Create a list view that preserves the order
        List {
            ForEach(0..<sortedTransactions.count, id: \.self) { index in
                let transaction = sortedTransactions[index]
                let showHeader = shouldShowHeader(at: index, in: sortedTransactions)
                
                if showHeader {
                    let date = Calendar.current.startOfDay(for: transaction.date)
                    let headerText = formattedDateHeader(for: date)
                    
                    Text(headerText)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray.opacity(0.5))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.top, 10)
                }
                
                HStack {
                    if isEditing {
                        Image(systemName: selectedTransactions.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedTransactions.contains(transaction.id) ? bluePurpleColor : .gray)
                            .onTapGesture {
                                toggleSelection(for: transaction)
                            }
                    }
                    
                    EnhancedTransactionRowView(transaction: transaction, viewModel: viewModel)
                        .padding(.vertical, 0)
                        .padding(.bottom, 0)
                }
                .listRowSeparator(.hidden)
                .swipeActions {
                    Button(role: .destructive) {
                        deleteTransaction(transaction)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }
    
    private var deleteToolbar: some View {
        VStack {
            Divider()
            HStack {
                Text("\(selectedTransactions.count) selected")
                    .font(.custom("Roboto-Medium", size: 14))
                Spacer()
                Button(action: { showAlert = true }) {
                    Text("Delete")
                        .font(.custom("Roboto-Medium", size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color(UIColor.secondarySystemBackground))
    }
    
    private func updateSearchSuggestions() {
        var suggestions: [String] = []
        
        if !searchText.isEmpty {
            let allCategories = Set(viewModel.transactions.map { $0.category })
            let allNotes = Set(viewModel.transactions.compactMap { $0.notes })
            
            suggestions.append(contentsOf: allCategories.filter {
                $0.lowercased().contains(searchText.lowercased())
            })
            
            suggestions.append(contentsOf: allNotes.filter {
                $0.lowercased().contains(searchText.lowercased())
            })
        }
        searchSuggestions = Array(Set(suggestions)).sorted().prefix(4).map { $0 }
    }
   
    private func loadRecentSearches() {
        if let savedSearches = UserDefaults.standard.stringArray(forKey: "recentTransactionSearches") {
            recentSearches = savedSearches
        }
    }
    
    private func addToRecentSearches(_ search: String) {
    
        recentSearches.removeAll { $0 == search }
        
      
        recentSearches.insert(search, at: 0)
        
   
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "recentTransactionSearches")
        
        // Update suggestions
        updateSearchSuggestions()
    }
    
    private func clearRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: "recentTransactionSearches")
        updateSearchSuggestions()
    }
    
    // Helper for shouldShowHeader
    private func shouldShowHeader(at index: Int, in transactions: [Transaction]) -> Bool {
        if index == 0 {
            return true // Always show header for the first item
        }
        
        let currentDate = Calendar.current.startOfDay(for: transactions[index].date)
        let previousDate = Calendar.current.startOfDay(for: transactions[index - 1].date)
        
        // Show header if the date is different from previous transaction
        return currentDate != previousDate
    }
    
    private func formattedDateHeader(for date: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        if date == today {
            return "Today (\(formattedDate(date)))"
        } else if date == yesterday {
            return "Yesterday (\(formattedDate(date)))"
        } else if date > today {
            return "Upcoming (\(formattedDate(date)))"
        } else {
            return formattedDate(date)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func toggleSelection(for transaction: Transaction) {
        if selectedTransactions.contains(transaction.id) {
            selectedTransactions.remove(transaction.id)
        } else {
            selectedTransactions.insert(transaction.id)
        }
    }
    
    private func deleteSelectedTransactions() {
        for id in selectedTransactions {
            if let index = viewModel.transactions.firstIndex(where: { $0.id == id }) {
                viewModel.transactions.remove(at: index)
            }
        }
        selectedTransactions.removeAll()
        viewModel.saveTransactions()
        
        if isEditing {
            isEditing = false
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        if let index = viewModel.transactions.firstIndex(where: { $0.id == transaction.id }) {
            viewModel.transactions.remove(at: index)
            viewModel.saveTransactions()
        }
    }
    
    private func toggleEditMode() {
        withAnimation {
            isEditing.toggle()
            if !isEditing {
                selectedTransactions.removeAll()
            }
        }
    }
    
    private func simulateLoading() {
        isLoading = true
        let shouldDelay = Double.random(in: 0...1) < 0.1 // 10% chance to delay
        let randomDelay = shouldDelay ? Double.random(in: 4...10) : 0
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
}

// Helper for measuring view sizes
struct BoundsPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
struct CalendarPickerView: View {
    @Binding var selectedDate: Date?
    @Binding var showCalendar: Bool
    @State private var date = Date()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with X button and Apply button in gray bar
            HStack {
                // Close Button
                Button(action: { showCalendar = false }) {
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
                
                Text("Select Date")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.leading, 30)
                
                Spacer()
                
                // Apply button
                Button("Apply") {
                    selectedDate = date
                    showCalendar = false
                }
                .fontWeight(.bold)
                .foregroundColor(bluePurpleColor)
                .padding()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
                .padding(.horizontal)
                .padding(.top, 16)
                .onChange(of: date) { selectedDate = $0 }
            
            Spacer()
        }
        .onAppear { if let selected = selectedDate { date = selected } }
    }
}

import SwiftUI

struct TransactionFilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
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
                .cornerRadius(10)
        }
    }
}

import SwiftUI

struct BouncingCirclesLoadingView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    let circleColors: [Color] = [.primaryBluePurple, .primaryBluePurple, .primaryBluePurple, .primaryBluePurple]
    let animationDuration: Double = 0.6
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [circleColors[index], circleColors[index].opacity(0.6)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 20, height: 20)
                        .offset(y: isAnimating ? -15 : 0)
                        .animation(
                            Animation
                                .easeInOut(duration: animationDuration)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * (animationDuration / 4)),
                            value: isAnimating
                        )
                        .shadow(color: circleColors[index].opacity(0.3), radius: 2, y: 2)
                }
            }
            .padding()
            
            Text("Loading!")
                .font(Font.custom("Sora-Bold", size: 20))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}
