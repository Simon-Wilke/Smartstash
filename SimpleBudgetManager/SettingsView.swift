//
//  SettingsView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 3/2/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("showChart") private var showChart: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @State private var showingImportSheet = false
    @State private var showingOnboarding = false
    @State private var importedCSVData: String?
    @State private var importedTransactions: [Transaction] = []
    @State private var showImportSuccess = false
    @State private var importError: String?
    @State private var showImportError = false
    @EnvironmentObject var budgetViewModel: BudgetViewModel
    @State private var showingCSVMapping = false
    @State private var showingDocumentPicker = false // New property to control document picker

    // Delete All Transactions Confirmation
    @State private var showDeleteAllAlert = false
    @State private var showFinalDeleteWarning = false
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Transaction Management")) {
                    Button(action: { showingOnboarding = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(bluePurpleColor)
                            Text("Import Transactions from CSV")
                        }
                    }
                    
                    Button(action: exportCSV) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(bluePurpleColor)
                            Text("Export Transactions to CSV")
                        }
                    }
                }
                
                Section(header: Text("Display Options")) {
                    Toggle("Show Trend Chart", isOn: $showChart)
                }
                
                // ⚠️ Danger Zone - Delete All Transactions
                Section(header: Text("Danger Zone")) {
                    Button(action: { showDeleteAllAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Delete All Transactions")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("Support & Legal")) {
                    Link(destination: URL(string: "https://yourapp.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(bluePurpleColor)
                            Text("Terms of Service")
                        }
                    }
                    
                    Link(destination: URL(string: "https://yourapp.com/privacy")!) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(bluePurpleColor)
                            Text("Privacy Policy")
                        }
                    }
                    
                    Button(action: sendFeedback) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(bluePurpleColor)
                            Text("Send Feedback")
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .center) {
                        Text("Smartstash")
                            .font(.headline)
                        Text("Version 0.1.0")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("© 2025 Smartstash Inc. All rights reserved.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                
                Section {
                    VStack {
                        Text("Made with ❤️ by Simon in 🇺🇸 ")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 0)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitleDisplayMode(.automatic)
            .padding(.top, -60)
            .alert("Delete All Transactions?", isPresented: $showDeleteAllAlert) {
                Button("Yes, Continue", role: .destructive) {
                    showFinalDeleteWarning = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action is **irreversible**. Are you absolutely sure?")
            }
            .sheet(isPresented: $showFinalDeleteWarning) {
                DeleteAllConfirmationView(
                    deleteConfirmationText: $deleteConfirmationText,
                    confirmAction: deleteAllTransactions
                )
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(csvData: $importedCSVData)
                    .onDisappear {
                        if let csvData = importedCSVData {
                            // Instead of showing mapping view, directly parse and import
                            let result = parseCSV(csvData)
                            switch result {
                            case .success(let transactions):
                                importedTransactions = transactions
                                if !importedTransactions.isEmpty {
                                    for transaction in importedTransactions {
                                        budgetViewModel.addTransaction(transaction)
                                    }
                                    showImportSuccess = true
                                } else {
                                    importError = "No valid transactions found in CSV file."
                                    showImportError = true
                                }
                            case .failure(let error):
                                importError = error.localizedDescription
                                showImportError = true
                            }
                        }
                    }
            }
            .alert("Import Successful", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Successfully imported \(importedTransactions.count) transactions.")
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error occurred during import.")
            }
            .sheet(isPresented: $showingOnboarding) {
                CSVImportTutorial(isPresented: $showingOnboarding, startImport: {
                    // When the import button is clicked in the tutorial, show the document picker
                    showingDocumentPicker = true
                })
            }
        }
    }


    // 🗑️ Function to delete all transactions
    private func deleteAllTransactions() {
        budgetViewModel.transactions.removeAll()
        budgetViewModel.pendingTransactions.removeAll()
        budgetViewModel.saveTransactions()
        budgetViewModel.savePendingTransactions()
    }


    // MARK: - Export Transactions to CSV
    private func exportCSV() {
        let transactions = budgetViewModel.transactions // Get all transactions
        guard !transactions.isEmpty else {
            print("⚠️ No transactions to export.")
            return
        }

        var csvString = "Amount,Category,Date,Notes,Icon\n"

        for transaction in transactions {
            let amount = String(format: "%.2f", transaction.amount)
            let category = transaction.category
            let date = formatDate(transaction.date) // Format date
            let notes = transaction.notes ?? ""
            let icon = transaction.icon
            
            let row = "\(amount),\(category),\(date),\"\(notes)\",\(icon)\n"
            csvString.append(row)
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("SmartstashTransactions.csv")

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ CSV file saved at: \(fileURL.path)")
            
            let activityView = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.rootViewController?.present(activityView, animated: true)
            }
        } catch {
            print("❌ Failed to save CSV file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Date Formatting Helper
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // Adjust format as needed
        return formatter.string(from: date)
    }

    // MARK: - Send Feedback
    private func sendFeedback() {
        let email = "support@smartstash.app"
        let subject = "Feedback for SmartStash"
        let body = "Hello, I would like to share my feedback about SmartStash..."
        
        let emailString = "mailto:\(email)?subject=\(subject)&body=\(body)"
        
        if let emailURL = URL(string: emailString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
            UIApplication.shared.open(emailURL)
        }
    }

    // Error type for CSV parsing
    enum CSVParseError: Error, LocalizedError {
        case emptyFile
        case invalidFormat
        case missingRequiredColumns(String)
        
        var errorDescription: String? {
            switch self {
            case .emptyFile:
                return "The CSV file appears to be empty."
            case .invalidFormat:
                return "The CSV format appears to be invalid. Please check the file format."
            case .missingRequiredColumns(let columns):
                return "Missing required columns: \(columns)"
            }
        }
    }
    
    private func parseCSV(_ csvString: String) -> Result<[Transaction], Error> {
        // Check if file is empty
        guard !csvString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(CSVParseError.emptyFile)
        }
        
        var transactions: [Transaction] = []
        
        // Split by newline, handling different line endings
        let rows = csvString.components(separatedBy: CharacterSet.newlines)
        
        // Need at least a header row and one data row
        guard rows.count > 1 else {
            return .failure(CSVParseError.emptyFile)
        }
        
        // Parse header row to find column indexes
        let headerRow = rows[0].lowercased()
        let headers = headerRow.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Define essential and optional columns
        let essentialColumns = ["amount", "category", "date"]
        var missingColumns: [String] = []
        
        // Check for required columns
        for column in essentialColumns {
            if !headers.contains(where: { $0.contains(column) }) {
                missingColumns.append(column)
            }
        }
        
        // If missing essential columns, return error
        if !missingColumns.isEmpty {
            return .failure(CSVParseError.missingRequiredColumns(missingColumns.joined(separator: ", ")))
        }
        
        // Find column indexes (handling flexible column order)
        let amountIndex = headers.firstIndex(where: { $0.contains("amount") }) ?? -1
        let categoryIndex = headers.firstIndex(where: { $0.contains("category") }) ?? -1
        let typeIndex = headers.firstIndex(where: { $0.contains("type") })
        let dateIndex = headers.firstIndex(where: { $0.contains("date") }) ?? -1
        let recurrenceIndex = headers.firstIndex(where: { $0.contains("recur") })
        let notesIndex = headers.firstIndex(where: { $0.contains("note") || $0.contains("description") })
        let iconIndex = headers.firstIndex(where: { $0.contains("icon") })
        
        let dateFormatters = [
            createDateFormatter(format: "yyyy-MM-dd"),            // Standard date
            createDateFormatter(format: "MM/dd/yyyy"),           // US format
            createDateFormatter(format: "dd/MM/yyyy"),           // European format
            createDateFormatter(format: "yyyy/MM/dd"),           // Alternative standard format
            createDateFormatter(format: "MM-dd-yyyy"),           // US format with dashes
            createDateFormatter(format: "yyyy-MM-dd HH:mm:ss"),  // 24-hour time (no timezone)
            createDateFormatter(format: "yyyy-MM-dd HH:mm:ss Z"), // 24-hour time with timezone
            createDateFormatter(format: "yyyy/MM/dd HH:mm:ss Z") // Slash format with timezone
        ]
        
        // Process data rows
        for i in 1..<rows.count {
            let row = rows[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if row.isEmpty { continue }
            
            // Handle quoted values in CSV correctly
            let columns = parseCSVRow(row)
            
            // Skip if we don't have enough columns for essential data
            if columns.count <= max(amountIndex, categoryIndex, dateIndex) {
                continue
            }
            
            // Parse amount (required)
            let amountString = columns[amountIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            // Handle currency symbols and commas in numbers
            let cleanedAmountString = amountString.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
            guard let amount = Double(cleanedAmountString) else { continue }
            
            // Parse category (required)
            let category = columns[categoryIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if category.isEmpty { continue }
            
            var type: Transaction.TransactionType = .expense // Default
            if let typeIndex = typeIndex, typeIndex < columns.count {
                let typeString = columns[typeIndex].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                switch typeString {
                case let s where s.contains("income"):
                    type = .income
                case let s where s.contains("invest"):
                    type = .investment
                case let s where s.contains("save"):
                    type = .savings
                default:
                    type = .expense
                }
            }
            // Default to today's date (in case parsing fails)
            var date = Date()

            if dateIndex < columns.count {
                let dateString = columns[dateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("📅 Raw Date String from CSV: \(dateString)") // <-- Debugging step

                var parsedSuccessfully = false
                for formatter in dateFormatters {
                    if let parsedDate = formatter.date(from: dateString) {
                        date = parsedDate
                        parsedSuccessfully = true
                        break
                    }
                }

                if !parsedSuccessfully {
                    print("⚠️ Failed to parse date: \(dateString)")
                } else {
                    print("✅ Parsed Date: \(date)")
                }
            }
            
            // Parse recurrence (optional with default)
            var recurrence: Transaction.RecurrenceType = .oneTime
            if let recurrenceIndex = recurrenceIndex, recurrenceIndex < columns.count {
                let recurrenceString = columns[recurrenceIndex].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                switch recurrenceString {
                case let s where s.contains("daily"):
                    recurrence = .daily
                case let s where s.contains("week") && s.contains("bi"):
                    recurrence = .biWeekly
                case let s where s.contains("week"):
                    recurrence = .weekly
                case let s where s.contains("month"):
                    recurrence = .monthly
                case let s where s.contains("quarter"):
                    recurrence = .quarterly
                case let s where s.contains("year") || s.contains("annual"):
                    recurrence = .annually
                default:
                    recurrence = .oneTime
                }
            }
            
            // Parse notes (optional)
            var notes: String? = nil
            if let notesIndex = notesIndex, notesIndex < columns.count {
                let noteText = columns[notesIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !noteText.isEmpty {
                    notes = noteText
                }
            }
            // Set icon to always be the cash emoji 💰
            let icon = "💵"
            
            // Create transaction
            let transaction = Transaction(
                amount: amount,
                category: category,
                type: type,
                recurrence: recurrence,
                notes: notes,
                icon: icon,
                date: date
            )
            
            transactions.append(transaction)
        }
        
        return .success(transactions)
    }
    
    // Helper function to create date formatters
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter
    }
    
    // Helper function to parse CSV rows correctly (handling quoted values)
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn)
        return columns
    }
    
    // Helper function to get default icon based on category
    private func defaultIconForCategory(_ category: String) -> String {
        let lowercaseCategory = category.lowercased()
        
        if lowercaseCategory.contains("food") || lowercaseCategory.contains("grocer") || lowercaseCategory.contains("restaurant") {
            return "🛒" // Shopping cart
        } else if lowercaseCategory.contains("transport") || lowercaseCategory.contains("travel") || lowercaseCategory.contains("gas") {
            return "🚗" // Car
        } else if lowercaseCategory.contains("home") || lowercaseCategory.contains("rent") || lowercaseCategory.contains("mortgage") {
            return "🏠" // House
        } else if lowercaseCategory.contains("health") || lowercaseCategory.contains("medical") {
            return "❤️" // Heart
        } else if lowercaseCategory.contains("entertainment") || lowercaseCategory.contains("fun") {
            return "🎬" // Clapperboard (Movie)
        } else if lowercaseCategory.contains("income") || lowercaseCategory.contains("salary") {
            return "💰" // Money bag
        } else if lowercaseCategory.contains("saving") || lowercaseCategory.contains("invest") {
            return "📈" // Upward chart
        } else {
            return "💵" // Default: Money
        }
    }
}

// MARK: - Document Picker for CSV Import
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var csvData: String?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Support more file types (CSV, TXT, Excel)
        let supportedTypes: [UTType] = [
            UTType.commaSeparatedText,
            UTType.text,
            UTType.plainText
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access the file.")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                // Try to decode with different encodings if UTF8 fails
                if let content = String(data: data, encoding: .utf8) {
                    parent.csvData = content
                } else if let content = String(data: data, encoding: .ascii) {
                    parent.csvData = content
                } else if let content = String(data: data, encoding: .windowsCP1252) {
                    parent.csvData = content
                } else {
                    // Try to force unwrap as UTF8 as last resort
                    parent.csvData = String(data: data, encoding: .utf8)!
                }
            } catch {
                print("Error reading file: \(error)")
            }
        }
    }
}
struct CSVImportTutorial: View {
    @Binding var isPresented: Bool
    var startImport: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var currentStep = 0
    
    let steps = [
        TutorialStep(
            image: "doc.text.magnifyingglass",
            title: "Import Transactions from CSV",
            description: "You can easily import your transactions from a CSV file from your bank or financial app."
        ),
        TutorialStep(
            image: "doc.plaintext",
            title: "What You Need",
            description: "Your CSV file should contain at least these columns: amount, category, and date. Other information like transaction type and notes are helpful but optional."
        ),
        TutorialStep(
            image: "list.bullet.rectangle",
            title: "CSV Format Examples",
            description: "Your file might look like this:\n\namount,category,date,notes\n45.67,Groceries,2025-02-28,Weekly shopping\n\nOR\n\nDate,Description,Category,Amount\n02/28/2025,Store purchase,Groceries,45.67"
        ),
        TutorialStep(
            image: "building.columns",
            title: "Common Bank CSV Formats",
            description: "We support exports from most banks and financial apps. The app will automatically detect column headers from your CSV file."
        ),
        TutorialStep(
            image: "arrow.down.doc",
            title: "Ready to Import",
            description: "Tap 'Import CSV' below to select your file and begin importing your transactions."
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background adapts to Dark Mode
                Color(colorScheme == .dark ? .black : .white)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        // Close Button on the Left
                        Button(action: {
                            isPresented = false
                        }) {
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
                    .padding(.horizontal)
                    
                    // TabView for tutorial steps
                    TabView(selection: $currentStep) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            VStack(spacing: 20) {
                                Image(systemName: steps[index].image)
                                    .font(.system(size: 80))
                                    .foregroundColor(bluePurpleColor)
                                    .padding(.bottom, 20)
                                
                                Text(steps[index].title)
                                    .font(.largeTitle.bold())
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .multilineTextAlignment(.center)
                                
                                ScrollView {
                                    Text(steps[index].description)
                                        .font(.body)
                                        .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .frame(height: 150)
                            }
                            .padding(.bottom, 30)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(bluePurpleColor)
                                .frame(width: (geometry.size.width / CGFloat(steps.count)) * CGFloat(currentStep + 1), height: 6)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    
                    // Navigation buttons
                    if currentStep == steps.count - 1 {
                        Button(action: {
                            isPresented = false
                            startImport() // This calls the closure passed into the view
                        }) {
                            Text("Import CSV")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bluePurpleColor)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 10)
                        
                        Button(action: { isPresented = false }) {
                            Text("Nevermind")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                                .padding(.vertical, 10)
                        }
                    } else {
                        Button(action: { withAnimation { currentStep += 1 } }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bluePurpleColor)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 10)
                        
                        Button(action: {
                            isPresented = false
                            startImport() // This calls the closure passed into the view
                        }) {
                            Text("Skip & Import Now")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.7))
                                .padding(.vertical, 10)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
    }
}
struct TutorialStep {
    let image: String
    let title: String
    let description: String
}
struct CSVColumnMappingView: View {
    @Binding var isPresented: Bool
    @Binding var csvData: String?
    var onComplete: ([Transaction]) -> Void
    
    @State private var headers: [String] = []
    @State private var previewRows: [[String]] = []
    @State private var columnMappings: [String: Int] = [:]
    @State private var currentStep = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedField: String? = nil // Track which field is being mapped
    
    // Required column types
    private let requiredMappings = ["amount", "category", "date"]
    // Optional column types
    private let optionalMappings = ["notes", "type", "icon", "recurrence"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                StepProgressView(currentStep: currentStep, totalSteps: 2)
                    .padding()
                
                // Header
                Text(currentStep == 0 ? "Preview Your Data" : "Map Your Columns")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Preview table or column mapping
                if currentStep == 0 {
                    previewTableView
                } else {
                    columnMappingView
                }
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    Button(action: {
                        if currentStep > 0 {
                            currentStep -= 1
                        } else {
                            isPresented = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text(currentStep > 0 ? "Back" : "Cancel")
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentStep == 0 {
                            currentStep += 1
                        } else {
                            processImport()
                        }
                    }) {
                        HStack {
                            Text(currentStep == 0 ? "Next" : "Import")
                            Image(systemName: currentStep == 0 ? "chevron.right" : "square.and.arrow.down")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(bluePurpleColor)
                        .cornerRadius(10)
                    }
                    .disabled(currentStep == 1 && !areRequiredMappingsFilled())
                }
                .padding()
            }
            .navigationBarTitle("Import Transactions", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            })
            .onAppear {
                if let csvData = csvData {
                    parseCSVHeaders(csvData)
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Import Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(item: $selectedField) { field in
                columnSelectionSheet(for: field)
            }
        }
    }
    
    // MARK: - Preview Table View
    private var previewTableView: some View {
        VStack(alignment: .leading) {
            Text("Here's a preview of your data:")
                .font(.subheadline)
                .padding(.horizontal)
            
            if previewRows.isEmpty {
                Text("No data found in CSV file")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            ForEach(headers, id: \.self) { header in
                                Text(header)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(8)
                                    .frame(width: 120, alignment: .leading)
                                    .background(Color.gray.opacity(0.2))
                                    .border(Color.gray.opacity(0.5), width: 0.5)
                            }
                        }
                        
                        // Data rows (up to 6 rows)
                        ForEach(0..<min(previewRows.count, 6), id: \.self) { rowIndex in
                            HStack(spacing: 0) {
                                ForEach(0..<min(previewRows[rowIndex].count, headers.count), id: \.self) { colIndex in
                                    Text(previewRows[rowIndex][colIndex])
                                        .font(.caption)
                                        .padding(8)
                                        .frame(width: 120, alignment: .leading)
                                        .background(rowIndex % 2 == 0 ? Color.white : Color.gray.opacity(0.1))
                                        .border(Color.gray.opacity(0.5), width: 0.5)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Text("We detected \(headers.count) columns and \(previewRows.count) rows in your file.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
        }
    }
    
    // MARK: - Column Mapping View
    private var columnMappingView: some View {
        VStack(alignment: .leading) {
            Text("Map each column to the appropriate field:")
                .font(.subheadline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Required fields
                    ForEach(requiredMappings, id: \.self) { field in
                        mappingRow(field: field, isRequired: true)
                    }
                    
                    // Optional fields
                    ForEach(optionalMappings, id: \.self) { field in
                        mappingRow(field: field, isRequired: false)
                    }
                }
                .padding()
            }
        }
    }
    
    // Individual mapping row
    private func mappingRow(field: String, isRequired: Bool) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(field.capitalized)
                    .fontWeight(.semibold)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                } else {
                    Text("(optional)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Button(action: {
                selectedField = field
            }) {
                HStack {
                    Text(selectedHeaderName(for: field))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(headers.isEmpty)
            
            if let index = columnMappings[field], index < previewRows.count && !previewRows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Show up to 3 sample values from column
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(0..<min(3, previewRows.count), id: \.self) { rowIndex in
                            if index < previewRows[rowIndex].count {
                                Text("- \(previewRows[rowIndex][index])")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
                .padding(.leading)
            }
        }
    }
    
    // Column selection sheet
    private func columnSelectionSheet(for field: String) -> some View {
        NavigationView {
            List {
                ForEach(Array(headers.enumerated()), id: \.element) { index, header in
                    Button(action: {
                        columnMappings[field] = index
                        selectedField = nil
                    }) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(header)
                                    .fontWeight(columnMappings[field] == index ? .bold : .regular)
                                
                                Spacer()
                                
                                if columnMappings[field] == index {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(bluePurpleColor)
                                }
                            }
                            
                            // Preview of values in this column
                            if !previewRows.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(0..<min(3, previewRows.count), id: \.self) { rowIndex in
                                        if index < previewRows[rowIndex].count {
                                            Text(previewRows[rowIndex][index])
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.leading, 8)
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundColor(.primary)
                }
                
                if !requiredMappings.contains(field) {
                    Button(action: {
                        columnMappings[field] = nil
                        selectedField = nil
                    }) {
                        Text("None")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationBarTitle("Select column for \(field.capitalized)", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                selectedField = nil
            })
        }
    }
    
    // MARK: - Helper Methods
    
    // Check if all required mappings are filled
    private func areRequiredMappingsFilled() -> Bool {
        for field in requiredMappings {
            if columnMappings[field] == nil {
                return false
            }
        }
        return true
    }
    
    // Get display name for currently selected header
    private func selectedHeaderName(for field: String) -> String {
        if let index = columnMappings[field], index < headers.count {
            return headers[index]
        }
        return "Select a column"
    }
    
    // Parse CSV to get headers and preview rows
    private func parseCSVHeaders(_ csvString: String) {
        let rows = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !rows.isEmpty else {
            errorMessage = "CSV file appears to be empty"
            showError = true
            return
        }
        
        // Parse header row
        headers = parseCSVRow(rows[0])
        
        // Parse data rows for preview
        previewRows = rows.dropFirst().prefix(10).map { parseCSVRow($0) }
        
        // Setup initial mappings by guessing based on header names
        setupInitialMappings()
    }
    
    // Parse a single CSV row, handling quoted values correctly
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn)
        return columns
    }
    
    // Auto-detect column mappings based on header names
    private func setupInitialMappings() {
        columnMappings = [:]
        
        for (index, header) in headers.enumerated() {
            let lowercaseHeader = header.lowercased()
            
            // Check for amount
            if lowercaseHeader.contains("amount") || lowercaseHeader.contains("price") || lowercaseHeader.contains("sum") {
                columnMappings["amount"] = index
            }
            // Check for category
            else if lowercaseHeader.contains("category") || lowercaseHeader.contains("categ") {
                columnMappings["category"] = index
            }
            // Check for date
            else if lowercaseHeader.contains("date") || lowercaseHeader.contains("time") {
                columnMappings["date"] = index
            }
            // Check for notes/description
            else if lowercaseHeader.contains("note") || lowercaseHeader.contains("description") || lowercaseHeader.contains("memo") {
                columnMappings["notes"] = index
            }
            // Check for transaction type (income/expense)
            else if lowercaseHeader.contains("type") && !columnMappings.values.contains(index) {
                columnMappings["type"] = index
            }
            // Check for icon
            else if lowercaseHeader.contains("icon") || lowercaseHeader.contains("symbol") {
                columnMappings["icon"] = index
            }
            // Check for recurrence
            else if lowercaseHeader.contains("recur") || lowercaseHeader.contains("repeat") || lowercaseHeader.contains("frequency") {
                columnMappings["recurrence"] = index
            }
        }
    }
    
    // Process the import with the selected mappings
    private func processImport() {
        // Validate required mappings
        for field in requiredMappings {
            if columnMappings[field] == nil {
                errorMessage = "Please select a column for \(field.capitalized)"
                showError = true
                return
            }
        }
        
        guard let csvData = csvData else {
            errorMessage = "No CSV data available"
            showError = true
            return
        }
        
        let result = parseTransactionsWithMappings(csvData)
        
        switch result {
        case .success(let transactions):
            if transactions.isEmpty {
                errorMessage = "No valid transactions found in the CSV file"
                showError = true
            } else {
                onComplete(transactions)
                isPresented = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // Parse transactions with user-defined column mappings
        private func parseTransactionsWithMappings(_ csvString: String) -> Result<[Transaction], Error> {
            let rows = csvString.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            // Skip header row
            guard rows.count > 1 else {
                return .failure(CSVParseError.emptyFile)
            }
            
            var transactions: [Transaction] = []
            
            // Get required column indices
            guard let amountIndex = columnMappings["amount"],
                  let categoryIndex = columnMappings["category"],
                  let dateIndex = columnMappings["date"] else {
                return .failure(CSVParseError.missingRequiredColumns("One or more required columns are not mapped"))
            }
            
            // Get optional column indices
            let notesIndex = columnMappings["notes"]
            let typeIndex = columnMappings["type"]
            let recurrenceIndex = columnMappings["recurrence"]
            let iconIndex = columnMappings["icon"]
            
            // Date formatters for parsing different date formats
            let dateFormatters = [
                createDateFormatter(format: "yyyy-MM-dd"),
                createDateFormatter(format: "MM/dd/yyyy"),
                createDateFormatter(format: "dd/MM/yyyy"),
                createDateFormatter(format: "yyyy/MM/dd"),
                createDateFormatter(format: "MM-dd-yyyy"),
                createDateFormatter(format: "yyyy-MM-dd HH:mm:ss"),
                createDateFormatter(format: "yyyy-MM-dd HH:mm:ss Z"),
                createDateFormatter(format: "yyyy/MM/dd HH:mm:ss Z")
            ]
            
            var successCount = 0
            var failureCount = 0
            
            // Process data rows
            for i in 1..<rows.count {
                let row = rows[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if row.isEmpty { continue }
                
                let columns = parseCSVRow(row)
                
                // Skip if row doesn't have enough columns for required fields
                let maxRequiredIndex = max(amountIndex, categoryIndex, dateIndex)
                if columns.count <= maxRequiredIndex {
                    failureCount += 1
                    continue
                }
                
                // Parse amount
                let amountString = columns[amountIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                // Handle currency symbols, commas, and parentheses for negative values
                var cleanedAmountString = amountString.replacingOccurrences(of: "[^0-9.,-]", with: "", options: .regularExpression)
                
                // Handle negative amounts in parentheses e.g. ($50.00)
                if amountString.contains("(") && amountString.contains(")") {
                    cleanedAmountString = "-" + cleanedAmountString
                }
                
                // Replace commas in numbers (e.g., 1,000.00 -> 1000.00)
                cleanedAmountString = cleanedAmountString.replacingOccurrences(of: ",", with: "")
                
                guard let amount = Double(cleanedAmountString) else {
                    failureCount += 1
                    continue
                }
                
                // Parse category
                let category = columns[categoryIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if category.isEmpty {
                    failureCount += 1
                    continue
                }
                
                // Parse transaction type
                var type: Transaction.TransactionType = .expense // Default
                if let typeIndex = typeIndex, typeIndex < columns.count {
                    let typeString = columns[typeIndex].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if typeString.contains("income") || typeString.contains("deposit") || typeString.contains("credit") {
                        type = .income
                    } else if typeString.contains("invest") {
                        type = .investment
                    } else if typeString.contains("save") {
                        type = .savings
                    }
                } else {
                    // If no type column is mapped, use amount sign as a hint
                    if amount > 0 {
                        type = .income
                    }
                }
                
                // Parse date
                var date = Date()
                var dateParseSuccess = false
                if dateIndex < columns.count {
                    let dateString = columns[dateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    for formatter in dateFormatters {
                        if let parsedDate = formatter.date(from: dateString) {
                            date = parsedDate
                            dateParseSuccess = true
                            break
                        }
                    }
                    
                    if !dateParseSuccess {
                        // Try to handle more complex date formats here
                        // For now, we'll use today's date and continue
                        print("⚠️ Could not parse date: \(dateString) - using today's date")
                    }
                }
                
                // Parse recurrence
                var recurrence: Transaction.RecurrenceType = .oneTime
                if let recurrenceIndex = recurrenceIndex, recurrenceIndex < columns.count {
                    let recurrenceString = columns[recurrenceIndex].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if recurrenceString.contains("daily") {
                        recurrence = .daily
                    } else if recurrenceString.contains("week") && recurrenceString.contains("bi") {
                        recurrence = .biWeekly
                    } else if recurrenceString.contains("week") {
                        recurrence = .weekly
                    } else if recurrenceString.contains("month") {
                        recurrence = .monthly
                    } else if recurrenceString.contains("quarter") {
                        recurrence = .quarterly
                    } else if recurrenceString.contains("year") || recurrenceString.contains("annual") {
                        recurrence = .annually
                    }
                }
                
                // Parse notes
                var notes: String? = nil
                if let notesIndex = notesIndex, notesIndex < columns.count {
                    let noteText = columns[notesIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !noteText.isEmpty {
                        notes = noteText
                    }
                }
                
                // Parse icon or use default
                var icon = "💵" // Default icon
                if let iconIndex = iconIndex, iconIndex < columns.count {
                    let iconText = columns[iconIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !iconText.isEmpty {
                        icon = iconText
                    }
                } else {
                    // Generate icon based on category if none provided
                    icon = defaultIconForCategory(category)
                }
                
                // Create transaction
                let transaction = Transaction(
                    amount: amount,
                    category: category,
                    type: type,
                    recurrence: recurrence,
                    notes: notes,
                    icon: icon,
                    date: date
                )
                
                transactions.append(transaction)
                successCount += 1
            }
            
            print("✅ Successfully imported \(successCount) transactions")
            if failureCount > 0 {
                print("⚠️ Failed to import \(failureCount) rows due to formatting issues")
            }
            
            return .success(transactions)
        }
        
        // Helper function to create date formatters
        private func createDateFormatter(format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter
        }
        
        // Helper function to get default icon based on category
        private func defaultIconForCategory(_ category: String) -> String {
            let lowercaseCategory = category.lowercased()
            
            if lowercaseCategory.contains("food") || lowercaseCategory.contains("grocer") || lowercaseCategory.contains("restaurant") {
                return "🛒" // Shopping cart
            } else if lowercaseCategory.contains("transport") || lowercaseCategory.contains("travel") || lowercaseCategory.contains("gas") {
                return "🚗" // Car
            } else if lowercaseCategory.contains("home") || lowercaseCategory.contains("rent") || lowercaseCategory.contains("mortgage") {
                return "🏠" // House
            } else if lowercaseCategory.contains("health") || lowercaseCategory.contains("medical") {
                return "❤️" // Heart
            } else if lowercaseCategory.contains("entertainment") || lowercaseCategory.contains("fun") {
                return "🎬" // Clapperboard (Movie)
            } else if lowercaseCategory.contains("income") || lowercaseCategory.contains("salary") {
                return "💰" // Money bag
            } else if lowercaseCategory.contains("saving") || lowercaseCategory.contains("invest") {
                return "📈" // Upward chart
            } else if lowercaseCategory.contains("bill") || lowercaseCategory.contains("utility") {
                return "📝" // Note
            } else if lowercaseCategory.contains("cloth") || lowercaseCategory.contains("shop") {
                return "👕" // Clothing
            } else if lowercaseCategory.contains("tech") || lowercaseCategory.contains("electr") {
                return "📱" // Mobile phone
            } else {
                return "💵" // Default: Money
            }
        }
        
        // Error type for CSV parsing
        enum CSVParseError: Error, LocalizedError {
            case emptyFile
            case invalidFormat
            case missingRequiredColumns(String)
            
            var errorDescription: String? {
                switch self {
                case .emptyFile:
                    return "The CSV file appears to be empty."
                case .invalidFormat:
                    return "The CSV format appears to be invalid. Please check the file format."
                case .missingRequiredColumns(let columns):
                    return "Missing required columns: \(columns)"
                }
            }
        }
    }

    // Make String identifiable for the sheet presentation
    extension String: Identifiable {
        public var id: String {
            self
        }
    }
// MARK: - Progress View
struct StepProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? bluePurpleColor : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? bluePurpleColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 40)
    }
}
import SwiftUI
import UIKit

struct DeleteAllConfirmationView: View {
    @Binding var deleteConfirmationText: String
    var confirmAction: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = false // 🎉 Easter egg state

    var body: some View {
        NavigationView {
            VStack(spacing: 35) { // Increased spacing for a well-balanced layout
                
                // ⚠️ Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 75, height: 75) // Slightly larger icon
                    .foregroundColor(.red)
                    .padding(.top, 20)
                
                // 🔴 Serious Header
                Text("Confirm Deletion")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 40) // Keeps width natural
                
                // ⚠️ Warning Message
                VStack(spacing: 12) { // Adds proper spacing
                    Text("This action will **permanently delete** all transactions.")
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Once deleted, your data **cannot be recovered**.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 45) // Expands but keeps it reasonable
                
                Divider()
                    .padding(.horizontal, 50) // Slightly wider divider
                
                // 🛑 Explicit Confirmation Instruction
                Text("Type **DELETE** below to confirm.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // 🔤 Input Field (Slightly Wider, but Not Stretched)
                TextField("DELETE", text: $deleteConfirmationText)
                    .padding()
                    .frame(height: 50)
                    .frame(maxWidth: 350) // Keeps width natural, not overly stretched
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .font(.headline)
                    .onChange(of: deleteConfirmationText) { newText in
                        if newText.lowercased() == "smartstashisthebest" {
                            showConfetti = true
                            ConfettiHelper.shared.showConfetti()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showConfetti = false
                            }
                        }
                    }
                
                // ❌ Final Delete Button (Wider but Not Overly Stretched)
                Button(action: {
                    if deleteConfirmationText == "DELETE" {
                        confirmAction()
                        dismiss()
                    }
                }) {
                    Text("Permanently Delete All Transactions")
                        .fontWeight(.bold)
                        .frame(maxWidth: 350) // Balanced width
                        .frame(height: 50)
                        .background(deleteConfirmationText == "DELETE" ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(deleteConfirmationText != "DELETE")
                
                Spacer()
            }
            .padding(.top, 50)
            .padding(.bottom, 30)
            .frame(maxWidth: 500) // Ensures nothing gets stretched too much
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}
import UIKit

class ConfettiHelper {
    static let shared = ConfettiHelper()

    func showConfetti() {
        guard let window = UIApplication.shared.windows.first else { return }
        let confettiView = ConfettiView(frame: window.bounds)
        window.addSubview(confettiView)
        confettiView.startConfetti()
    }
}

// 🎊 Confetti View with Smooth Start & Natural Fall
class ConfettiView: UIView {
    private let confettiLayer = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupConfetti()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConfetti() {
        confettiLayer.emitterPosition = CGPoint(x: bounds.midX, y: -100) // ⬆️ Starts higher up, off-screen
        confettiLayer.emitterSize = CGSize(width: bounds.width, height: 50) // ➡️ Wider spread
        confettiLayer.emitterShape = .line
        confettiLayer.renderMode = .additive

        let confettiColors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange, .systemPink
        ]

        let confettiTypes = confettiColors.map { createConfettiCell(color: $0) }
        
        confettiLayer.emitterCells = confettiTypes
        layer.addSublayer(confettiLayer)
    }

    private func createConfettiCell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 10  // 🎉 More particles
        cell.lifetime = 5.0  // ⏳ Ensures particles last until they exit screen
        cell.lifetimeRange = 2.0
        cell.velocity = 250  // ⬇️ Faster downward movement
        cell.velocityRange = 50
        cell.yAcceleration = 100  // ⬇️ Ensures they naturally fall off the screen
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 4
        cell.spin = 4.0
        cell.spinRange = 2.5
        cell.scale = 0.4  // 🔎 Larger confetti particles
        cell.scaleRange = 0.2
        cell.color = color.cgColor  // ✅ Uses regular colors
        cell.contents = createConfettiShape().cgImage
        return cell
    }

    private func createConfettiShape() -> UIImage {
        let size = CGSize(width: 15, height: 15)  // 🔎 Larger confetti
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()!

        let shapeType = Int.random(in: 0...1)  // 0 = Circle, 1 = Square
        if shapeType == 0 {
            context.addEllipse(in: CGRect(origin: .zero, size: size))  // 🔵 Circle Shape
        } else {
            context.addRect(CGRect(origin: .zero, size: size))  // 🟥 Square Shape
        }

        context.setFillColor(UIColor.white.cgColor)  // White base color, recolored by cell
        context.fillPath()

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    func startConfetti() {
        confettiLayer.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {  // 🎉 Shorter effect but natural
            self.stopConfetti()
        }
    }

    func stopConfetti() {
        confettiLayer.birthRate = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {  // ⏳ Ensures smooth exit before removing
            self.removeFromSuperview()
        }
    }
}
