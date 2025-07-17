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
    @State private var showingDocumentPicker = false
    @State private var showingColumnMapping = false
    
    @State private var showDeleteAllAlert = false
    @State private var showFinalDeleteWarning = false
    @State private var deleteConfirmationText = ""
    @State private var hasShownDeleteSheet = false
    @State private var hasShownDocumentPicker = false
    @State private var hasShownColumnMapping = false
    @State private var hasShownOnboarding = false
    
    var body: some View {
        List {
            Section("Transaction Management") {
                SettingsRow(icon: "square.and.arrow.down", color: .blue, title: "Import Transactions from CSV") {
                    showingOnboarding = true
                }
                SettingsRow(icon: "square.and.arrow.up", color: .indigo, title: "Export Transactions to CSV") {
                    exportCSV()
                }
            }
            
            Section("Display Options") {
                HStack {
                    IconBadge(icon: "chart.line.uptrend.xyaxis", color: .teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Trend Chart")
                            .font(.system(size: 16, weight: .medium))
                  
                    }
                    Spacer()
                    Toggle("", isOn: $showChart)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.vertical, 4)
            }
            
            Section("Danger Zone") {
                SettingsRow(icon: "trash.fill", color: .red, title: "Delete All Transactions", subtitle: "This action cannot be undone", titleColor: .red) {
                    showDeleteAllAlert = true
                    hasShownDeleteSheet = false
                }
            }
            
            Section("Support & Legal") {
                LinkRow(icon: "doc.text", color: .purple, title: "Terms of Service", subtitle: "Read our terms and conditions", url: "https://yourapp.com/terms")
                LinkRow(icon: "lock.shield", color: .green, title: "Privacy Policy", subtitle: "How we protect your data", url: "https://yourapp.com/privacy")
                SettingsRow(icon: "envelope", color: .orange, title: "Send Feedback", subtitle: "Help us improve the app") {
                    sendFeedback()
                }
            }
            
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Smartstash Finance")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Version 0.1.0")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("© 2025 Smartstash Inc.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        
        .onChange(of: importedCSVData) { newValue in
            guard let data = newValue, !data.isEmpty else { return }
            if !showingColumnMapping {
                showingColumnMapping = true
            }
        }
        
        .alert("Delete All Transactions?", isPresented: $showDeleteAllAlert) {
            Button("Yes, Continue", role: .destructive) {
                showFinalDeleteWarning = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action is **irreversible**. Are you absolutely sure?")
        }
        
        .sheet(isPresented: $showFinalDeleteWarning, onDismiss: {
            hasShownDeleteSheet = true
        }) {
            DeleteAllConfirmationView(
                deleteConfirmationText: $deleteConfirmationText,
                confirmAction: deleteAllTransactions
            )
        }
        
        .sheet(isPresented: $showingOnboarding, onDismiss: {
            hasShownOnboarding = true
        }) {
            CSVImportTutorial(
                isPresented: $showingOnboarding,
                startImport: {
                    importedCSVData = nil
                    showingDocumentPicker = true
                    hasShownDocumentPicker = false
                }
            )
        }
        
        .sheet(isPresented: $showingDocumentPicker, onDismiss: {
            hasShownDocumentPicker = true
        }) {
            DocumentPicker(csvData: $importedCSVData)
        }
        
        .sheet(isPresented: $showingColumnMapping, onDismiss: {
            hasShownColumnMapping = true
        }) {
            CSVColumnMappingView(isPresented: $showingColumnMapping, csvData: $importedCSVData) { mappedTransactions in
                importedTransactions = mappedTransactions
                if !importedTransactions.isEmpty {
                    for transaction in importedTransactions {
                        budgetViewModel.addTransaction(transaction)
                    }
                    showImportSuccess = true
                } else {
                    importError = "No valid transactions found in CSV file."
                    showImportError = true
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
    }
    
    private func deleteAllTransactions() {
        budgetViewModel.transactions.removeAll()
        budgetViewModel.pendingTransactions.removeAll()
        budgetViewModel.saveTransactions()
        budgetViewModel.savePendingTransactions()
    }
    
    
    private func exportCSV() {
        let transactions = budgetViewModel.transactions
        guard !transactions.isEmpty else {
            print("⚠️ No transactions to export.")
            return
        }
        
        var csvString = "Amount,Category,Date,Notes,Icon,Type\n"
        
        for transaction in transactions {
            let amount = String(format: "%.2f", transaction.amount)
            let category = transaction.category
            let date = formatDate(transaction.date)
            let notes = transaction.notes ?? ""
            let icon = transaction.icon
            let type = transaction.type.rawValue
            
            let row = "\(amount),\(category),\(date),\"\(notes)\",\(icon),\(type)\n"
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
    
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    
    private func sendFeedback() {
        let email = "support@smartstash.app"
        let subject = "Feedback for SmartStash"
        let body = "Hello, I would like to share my feedback about SmartStash..."
        
        let emailString = "mailto:\(email)?subject=\(subject)&body=\(body)"
        if let emailURL = URL(string: emailString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
            UIApplication.shared.open(emailURL)
        }
    }
    struct SettingsRow: View {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String?
        let titleColor: Color
        let action: () -> Void
        
        init(icon: String, color: Color, title: String, subtitle: String? = nil, titleColor: Color = .primary, action: @escaping () -> Void) {
            self.icon = icon
            self.color = color
            self.title = title
            self.subtitle = subtitle
            self.titleColor = titleColor
            self.action = action
        }
        
        var body: some View {
            Button(action: action) {
                HStack {
                    IconBadge(icon: icon, color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(titleColor)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    struct LinkRow: View {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let url: String
        
        var body: some View {
            Link(destination: URL(string: url)!) {
                HStack {
                    IconBadge(icon: icon, color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    struct IconBadge: View {
        let icon: String
        let color: Color
        
        var body: some View {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    
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
        
        
        let rows = csvString.components(separatedBy: CharacterSet.newlines)
        
        
        guard rows.count > 1 else {
            return .failure(CSVParseError.emptyFile)
        }
        
        
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
            image: "arrow.down.doc.fill",
            title: "Easy as Pie",
            description: "Import transactions directly from your bank or financial app's CSV export."
        ),
        TutorialStep(
            image: "table",
            title: "Required Format",
            description: "CSV must include: amount, category, and date. Transaction type and notes are optional but helpful."
        ),
        TutorialStep(
            image: "doc.text",
            title: "Example Formats",
            description: "Examples:\namount,category,date,notes\n45.67,Groceries,2025-02-28,Shopping\n\nOR\n\nDate,Description,Category,Amount\n02/28/2025,Purchase,Groceries,45.67"
        ),
        TutorialStep(
            image: "creditcard.fill",
            title: "Supported Banks",
            description: "Compatible with most financial institutions. The app automatically detects column headers."
        ),
        TutorialStep(
            image: "checkmark.circle.fill",
            title: "Start Import",
            description: "Tap 'Import CSV' to select your file and begin."
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
                            .padding(.trailing, 330)
                            .padding(.top, 6)
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
    @Environment(\.colorScheme) var colorScheme
    
    // Theme colors - now adapting to dark mode
    private var primaryColor: Color {
        Color(hex: "5E5CE6") // Main brand color - a vibrant blue-purple
    }
    
    private var secondaryColor: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : Color(hex: "F2F2F7")
    }
    
    private var accentColor: Color {
        Color(hex: "FF375F") // Accent color for highlights
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "1C1C1E")
    }
    
    private var subtextColor: Color {
        colorScheme == .dark ? Color(hex: "AEAEB2") : Color(hex: "8E8E93")
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemBackground)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }
    
    private var separatorColor: Color {
        colorScheme == .dark ? Color(UIColor.separator).opacity(0.7) : Color(UIColor.separator).opacity(0.5)
    }
    
    @State private var headers: [String] = []
    @State private var previewRows: [[String]] = []
    @State private var columnMappings: [String: Int] = [:]
    @State private var currentStep = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedField: String? = nil // Track which field is being mapped
    @State private var isProcessing = false // Track processing state
    
    // Required column types
    private let requiredMappings = ["amount", "category", "date"]
    // Optional column types
    private let optionalMappings = ["notes", "type", "icon", "recurrence"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundColor
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header with progress
                    headerView
                    
                    // Main content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            // Step indicator
                            stepIndicatorView
                                .padding(.top, 10)
                            
                            // Title and description
                            titleView
                            
                            // Main content area
                            contentView
                        }
                        .padding(.horizontal)
                    }
                    
                    // Bottom navigation
                    navigationButtons
                }
            }
            .navigationBarTitle("Import Transactions", displayMode: .inline)
            .navigationBarItems(leading: closeButton) // Changed from trailing to leading
            .onAppear {
                if let csvData = csvData {
                    parseCSVHeaders(csvData)
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Import Alert"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(item: $selectedField) { field in
                columnSelectionSheet(for: field)
            }
        }
    }
    
    // MARK: - UI Components
    
    // Close button - now positioned on the left
    private var closeButton: some View {
        Button(action: { isPresented = false }) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "xmark")
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.leading, 2)
          
        }
   
    }
    
    // Header view with progress indicator
    private var headerView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
                .background(separatorColor)
        }
    }
    
    // Step indicator view
    private var stepIndicatorView: some View {
        HStack(spacing: 4) {
            ForEach(0..<2) { step in
                Capsule()
                    .fill(step == currentStep ? primaryColor : secondaryColor)
                    .frame(height: 4)
            }
        }
        .frame(width: 40)
        .padding(.vertical, 10)
    }
    
    // Title view with step-specific titles
    private var titleView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentStep == 0 ? "Preview Your Data" : "Map Your Columns")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textColor)
            
            Text(currentStep == 0 ?
                "We found \(headers.count) columns and \(previewRows.count) rows." :
                "Map your CSV columns to the appropriate transaction fields.")
                .font(.system(size: 16))
                .foregroundColor(subtextColor)
                .padding(.bottom, 10)
        }
    }
    
    // Main content view - switches between preview and mapping
    private var contentView: some View {
        VStack {
            if currentStep == 0 {
                previewTableView
            } else {
                columnMappingView
            }
            
            Spacer(minLength: 60)
        }
    }
    
    // Bottom navigation buttons
    private var navigationButtons: some View {
        VStack(spacing: 0) {
            Divider()
                .background(separatorColor)
            
            HStack {
                // Back button
                Button(action: {
                    if currentStep > 0 {
                        currentStep -= 1
                    } else {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text(currentStep > 0 ? "Back" : "Cancel")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                    .padding(.vertical, 12)
                }
                
                Spacer()
                
                // Next/Import button
                Button(action: {
                    if currentStep == 0 {
                        currentStep += 1
                    } else {
                        isProcessing = true
                        processImport()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text(currentStep == 0 ? "Next" : "Import")
                            Image(systemName: currentStep == 0 ? "chevron.right" : "square.and.arrow.down")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 120)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(areRequiredMappingsFilled() || currentStep == 0 ? primaryColor : Color.gray.opacity(0.3))
                    )
                }
                .disabled((currentStep == 1 && !areRequiredMappingsFilled()) || isProcessing)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(backgroundColor)
        }
    }
    
    // MARK: - Preview Table View
    private var previewTableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if previewRows.isEmpty {
                emptyDataView
            } else {
                dataPreviewView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(separatorColor, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 16).fill(backgroundColor))
        )
        .padding(.vertical, 8)
    }
    
    private var emptyDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(subtextColor)
            
            Text("No data found in CSV file")
                .font(.headline)
                .foregroundColor(subtextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    private var dataPreviewView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(headers, id: \.self) { header in
                        Text(header)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(primaryColor)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(width: 140, alignment: .leading)
                            .background(secondaryColor)
                            .border(separatorColor, width: 0.5)
                    }
                }
                
                // Data rows (up to 6 rows)
                ForEach(0..<min(previewRows.count, 6), id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(0..<min(previewRows[rowIndex].count, headers.count), id: \.self) { colIndex in
                            Text(previewRows[rowIndex][colIndex])
                                .font(.system(size: 14))
                                .foregroundColor(textColor)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .frame(width: 140, alignment: .leading)
                                .background(rowIndex % 2 == 0 ?
                                    (colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white) :
                                    (colorScheme == .dark ? Color(hex: "1C1C1E") : Color(UIColor.systemGray6)))
                                .border(separatorColor, width: 0.5)
                        }
                    }
                }
            }
        }
        .frame(height: 320)
        .padding(3)
    }
    
    // MARK: - Column Mapping View
    private var columnMappingView: some View {
        VStack(spacing: 16) {
            // Required fields with header
            VStack(alignment: .leading, spacing: 6) {
                Text("Required Fields")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.leading, 4)
                
                VStack(spacing: 12) {
                    ForEach(requiredMappings, id: \.self) { field in
                        mappingRow(field: field, isRequired: true)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 2, x: 0, y: 1)
                )
            }
            
            // Optional fields with header
            VStack(alignment: .leading, spacing: 6) {
                Text("Optional Fields")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.leading, 4)
                    .padding(.top, 10)
                
                VStack(spacing: 12) {
                    ForEach(optionalMappings, id: \.self) { field in
                        mappingRow(field: field, isRequired: false)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 2, x: 0, y: 1)
                )
            }
        }
    }
    
    // Individual mapping row
    private func mappingRow(field: String, isRequired: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayName(for: field))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(accentColor)
                        .font(.system(size: 16, weight: .bold))
                } else {
                    Text("(optional)")
                        .font(.system(size: 14))
                        .foregroundColor(subtextColor)
                }
                
                Spacer()
            }
            
            Button(action: {
                selectedField = field
            }) {
                HStack {
                    if let index = columnMappings[field], index < headers.count {
                        Text(headers[index])
                            .foregroundColor(textColor)
                    } else {
                        Text(isRequired ? "Select a column" : "None (Skip)")
                            .foregroundColor(isRequired ? subtextColor : textColor)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(subtextColor)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(separatorColor, lineWidth: 1)
                )
            }
            .disabled(headers.isEmpty)
            
            // Preview of selected mapping
            if let index = columnMappings[field], index < previewRows.count && !previewRows.isEmpty {
                previewForMapping(columnIndex: index)
            }
        }
    }
    
    // Preview display for a mapped column
    private func previewForMapping(columnIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview:")
                .font(.system(size: 14))
                .foregroundColor(subtextColor)
            
            // Show up to 3 sample values from column
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<min(3, previewRows.count), id: \.self) { rowIndex in
                    if columnIndex < previewRows[rowIndex].count {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(primaryColor.opacity(0.2))
                                .frame(width: 8, height: 8)
                            
                            Text(previewRows[rowIndex][columnIndex])
                                .font(.system(size: 14))
                                .foregroundColor(subtextColor)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }
    
    // Column selection sheet
    private func columnSelectionSheet(for field: String) -> some View {
        NavigationView {
            List {
                // None option for optional fields
                if !requiredMappings.contains(field) {
                    Button(action: {
                        columnMappings[field] = nil
                        selectedField = nil
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("None (Skip this field)")
                                    .foregroundColor(textColor)
                            }
                            
                            Spacer()
                            
                            if columnMappings[field] == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(primaryColor)
                            }
                        }
                    }
                }
                
                // Column options
                ForEach(Array(headers.enumerated()), id: \.element) { index, header in
                    Button(action: {
                        columnMappings[field] = index
                        selectedField = nil
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(header)
                                    .font(.system(size: 16, weight: columnMappings[field] == index ? .semibold : .regular))
                                    .foregroundColor(textColor)
                                
                                Spacer()
                                
                                if columnMappings[field] == index {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(primaryColor)
                                }
                            }
                            
                            // Preview of values
                            if !previewRows.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(0..<min(2, previewRows.count), id: \.self) { rowIndex in
                                        if index < previewRows[rowIndex].count {
                                            Text(previewRows[rowIndex][index])
                                                .font(.system(size: 14))
                                                .foregroundColor(subtextColor)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Select Column for \(displayName(for: field))", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                selectedField = nil
            })
        }
    }
    
    // MARK: - Helper Methods
    
    // Convert field name to display name
    private func displayName(for field: String) -> String {
        switch field {
        case "amount": return "Amount"
        case "category": return "Category"
        case "date": return "Date"
        case "notes": return "Notes/Description"
        case "type": return "Transaction Type"
        case "icon": return "Icon"
        case "recurrence": return "Recurrence"
        default: return field.capitalized
        }
    }
    
    // Check if all required mappings are filled
    private func areRequiredMappingsFilled() -> Bool {
        for field in requiredMappings {
            if columnMappings[field] == nil {
                return false
            }
        }
        return true
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
            if lowercaseHeader.contains("amount") || lowercaseHeader.contains("price") ||
               lowercaseHeader.contains("sum") || lowercaseHeader.contains("value") {
                columnMappings["amount"] = index
            }
            // Check for category
            else if lowercaseHeader.contains("category") || lowercaseHeader.contains("categ") ||
                    lowercaseHeader.contains("type") && lowercaseHeader.contains("transaction") {
                columnMappings["category"] = index
            }
            // Check for date
            else if lowercaseHeader.contains("date") || lowercaseHeader.contains("time") {
                columnMappings["date"] = index
            }
            // Check for notes/description
            else if lowercaseHeader.contains("note") || lowercaseHeader.contains("description") ||
                    lowercaseHeader.contains("memo") || lowercaseHeader.contains("details") {
                columnMappings["notes"] = index
            }
            // Check for transaction type (income/expense)
            else if (lowercaseHeader.contains("type") && !lowercaseHeader.contains("transaction")) ||
                     lowercaseHeader.contains("direction") {
                columnMappings["type"] = index
            }
            // Check for icon
            else if lowercaseHeader.contains("icon") || lowercaseHeader.contains("symbol") ||
                    lowercaseHeader.contains("emoji") {
                columnMappings["icon"] = index
            }
            // Check for recurrence
            else if lowercaseHeader.contains("recur") || lowercaseHeader.contains("repeat") ||
                    lowercaseHeader.contains("frequency") || lowercaseHeader.contains("schedule") {
                columnMappings["recurrence"] = index
            }
        }
    }
    
    // Process the import with the selected mappings
    private func processImport() {
        // Validate required mappings
        for field in requiredMappings {
            if columnMappings[field] == nil {
                errorMessage = "Please select a column for \(displayName(for: field))"
                showError = true
                isProcessing = false
                return
            }
        }
        
        guard let csvData = csvData else {
            errorMessage = "No CSV data available"
            showError = true
            isProcessing = false
            return
        }
        
        // Introduce a small delay to show processing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result = parseTransactionsWithMappings(csvData)
            
            switch result {
            case .success(let transactions):
                if transactions.isEmpty {
                    self.errorMessage = "No valid transactions found in the CSV file"
                    self.showError = true
                } else {
                    self.onComplete(transactions)
                    self.isPresented = false
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
            self.isProcessing = false
        }
    }
    
    // Parse transactions based on column mappings
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
        
        // Enhanced date formatters with more format options
        let dateFormatters = [
            // ISO formats
            createDateFormatter(format: "yyyy-MM-dd"),
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss"),
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ssZ"),
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
            
            // US formats
            createDateFormatter(format: "MM/dd/yyyy"),
            createDateFormatter(format: "MM/dd/yy"),
            createDateFormatter(format: "M/d/yyyy"),
            createDateFormatter(format: "M/d/yy"),
            
            // European formats
            createDateFormatter(format: "dd/MM/yyyy"),
            createDateFormatter(format: "dd/MM/yy"),
            createDateFormatter(format: "d/M/yyyy"),
            createDateFormatter(format: "d/M/yy"),
            
            // Asian formats
            createDateFormatter(format: "yyyy/MM/dd"),
            createDateFormatter(format: "yy/MM/dd"),
            
            // Date with time formats
            createDateFormatter(format: "MM-dd-yyyy"),
            createDateFormatter(format: "dd-MM-yyyy"),
            createDateFormatter(format: "yyyy-MM-dd HH:mm:ss"),
            createDateFormatter(format: "MM/dd/yyyy HH:mm:ss"),
            createDateFormatter(format: "dd/MM/yyyy HH:mm:ss"),
            
            // Special formats with month names
            createDateFormatter(format: "MMM d, yyyy"),
            createDateFormatter(format: "MMMM d, yyyy"),
            createDateFormatter(format: "d MMM yyyy"),
            createDateFormatter(format: "d MMMM yyyy")
        ]
        
        var successCount = 0
        var failureCount = 0
        var unparsedDates: [String] = []  // Track date strings that couldn't be parsed
        
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
                let originalDateString = columns[dateIndex]
                let dateString = originalDateString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !dateString.isEmpty {
                    // Try to clean up the date string - remove extra quotes and normalize separators
                    var normalizedDateString = dateString.replacingOccurrences(of: "\"", with: "")
                    // Try parsing with each formatter
                    for formatter in dateFormatters {
                        if let parsedDate = formatter.date(from: normalizedDateString) {
                            date = parsedDate
                            dateParseSuccess = true
                            break
                        }
                    }
                    
                    // If still not parsed, try more aggressive normalization
                    if !dateParseSuccess {
                        // Replace all non-alphanumeric characters with a space except - and /
                        normalizedDateString = dateString.replacingOccurrences(of: "[^a-zA-Z0-9\\-/]", with: " ", options: .regularExpression)
                        normalizedDateString = normalizedDateString.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        normalizedDateString = normalizedDateString.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        for formatter in dateFormatters {
                            if let parsedDate = formatter.date(from: normalizedDateString) {
                                date = parsedDate
                                dateParseSuccess = true
                                break
                            }
                        }
                    }
                    
                    if !dateParseSuccess {
                        // Track unparsed dates for reporting to the user
                        if !unparsedDates.contains(dateString) {
                            unparsedDates.append(dateString)
                        }
                        
                        // Try to extract year, month, day as fallback
                        if let (year, month, day) = extractDateComponents(from: dateString) {
                            var dateComponents = DateComponents()
                            dateComponents.year = year
                            dateComponents.month = month
                            dateComponents.day = day
                            
                            if let fallbackDate = Calendar.current.date(from: dateComponents) {
                                date = fallbackDate
                                dateParseSuccess = true
                            }
                        }
                    }
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
            func emojiFromName(_ name: String) -> String? {
                let mapping: [String: String] = [
                    "tshirt": "👕",
                    "cpu": "🖥️",      // Changed from brain to computer
                    "phone": "📱",
                    "heart": "❤️",
                    "car": "🚗",
                    "cart": "🛒",
                    "film": "🎬",
                    "money": "💰",
                    "chart": "📈",
                    "note": "📝",
                    "house": "🏠",
                    "banknote": "💵",
                    "food": "🍎",      // Changed from burger to apple
                    "game": "🎮",
                    "gift": "🎁"
                ]
                
                return mapping[name.lowercased()]
            }

            var icon = "💵" // Always default

            if let iconIndex = iconIndex, iconIndex < columns.count {
                let iconText = columns[iconIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !iconText.isEmpty {
                    // If iconText is already an emoji (check first character Unicode range)
                    if iconText.unicodeScalars.first?.properties.isEmojiPresentation == true {
                        icon = iconText
                    } else if let converted = emojiFromName(iconText) {
                        icon = converted
                    }
                    // else icon stays default 💵
                }
            } else {
                icon = defaultIconForCategory(category) // fallback based on category (should also be emoji)
                
                // Just in case defaultIconForCategory returns something invalid, force default:
                if icon.unicodeScalars.first?.properties.isEmojiPresentation != true {
                    icon = "💵"
                }
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
        
        // If we had date parsing issues, return an error or warning
        if !unparsedDates.isEmpty && unparsedDates.count <= 5 {
            errorMessage = "Warning: Could not parse dates in the following format(s): \(unparsedDates.joined(separator: ", ")). Using the dates as found in the file."
            showError = true
        } else if !unparsedDates.isEmpty {
            errorMessage = "Warning: Some dates could not be parsed correctly. Please check your date formats."
            showError = true
        }
        
        return .success(transactions)
    }

    // Helper function to create date formatters
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX") // Use consistent locale for parsing
        formatter.timeZone = TimeZone.current // Use current time zone
        formatter.isLenient = true // Be lenient when parsing
        return formatter
    }

    // Helper function to extract date components from a string when formatters fail
    private func extractDateComponents(from dateString: String) -> (year: Int, month: Int, day: Int)? {
        // Try to extract numbers from the string
        let numbers = dateString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
            .compactMap { Int($0) }
        
        guard numbers.count >= 3 else { return nil }
        
        // Try to guess which numbers represent year/month/day
        var year = 0
        var month = 0
        var day = 0
        
        // Check for 4-digit year
        for num in numbers {
            if num >= 1900 && num <= 2100 {
                year = num
                break
            }
        }
        
        // If no 4-digit year found, try other heuristics
        if year == 0 {
            // Sort numbers in descending order
            let sortedNumbers = numbers.sorted(by: >)
            
            if numbers.count == 3 {
                // Common case: three numbers representing day, month, year
                if sortedNumbers[0] > 31 { // Largest is likely year
                    year = sortedNumbers[0]
                    if sortedNumbers[1] > 12 { // Second largest is day
                        day = sortedNumbers[1]
                        month = sortedNumbers[2]
                    } else { // Second largest is month
                        month = sortedNumbers[1]
                        day = sortedNumbers[2]
                    }
                } else { // No number > 31, try to disambiguate
                    if sortedNumbers[0] > 12 { // Largest is day
                        day = sortedNumbers[0]
                        month = sortedNumbers[1]
                        year = 2000 + sortedNumbers[2] // Assume 2-digit year
                    } else { // Largest could be month or day
                        day = sortedNumbers[1]
                        month = sortedNumbers[0]
                        year = 2000 + sortedNumbers[2] // Assume 2-digit year
                    }
                }
            } else {
                // More complex case, take largest number as year if > 31
                for num in sortedNumbers {
                    if num > 31 {
                        year = num
                        break
                    }
                }
                
                // If still no year, use current year
                if year == 0 {
                    year = Calendar.current.component(.year, from: Date())
                }
                
                // Find a number between 1-12 for month
                for num in numbers {
                    if num >= 1 && num <= 12 && num != year {
                        month = num
                        break
                    }
                }
                
                // Find a number between 1-31 for day
                for num in numbers {
                    if num >= 1 && num <= 31 && num != year && num != month {
                        day = num
                        break
                    }
                }
            }
        } else {
            // If we found a 4-digit year, find month and day
            let nonYearNumbers = numbers.filter { $0 != year }
            
            // Find a number between 1-12 for month
            for num in nonYearNumbers {
                if num >= 1 && num <= 12 {
                    month = num
                    break
                }
            }
            
            // Find a number between 1-31 for day
            for num in nonYearNumbers {
                if num >= 1 && num <= 31 && num != month {
                    day = num
                    break
                }
            }
        }
        
        // Validate and correct found values
        if year < 100 {
            year += 2000 // Assume 21st century for 2-digit years
        }
        
        if month < 1 || month > 12 {
            month = 1 // Default to January if invalid month
        }
        
        if day < 1 || day > 31 {
            day = 1 // Default to 1st of month if invalid day
        }
        
        return (year, month, day)
    }
        
    // Always returns the money emoji
    private func defaultIconForCategory(_ category: String) -> String {
        return "💵"
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var showConfetti = false
    @State private var isShaking = false
    @State private var scale: CGFloat = 1.0
    
    // Custom colors
    private let accentColor = Color("AccentColor", bundle: nil) // Uses asset catalog color
    private let warningColor = Color(UIColor.systemRed)
    
    // Animation properties
    @State private var animateWarning = false
    @State private var buttonPressed = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemGray6),
                        colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    Spacer()
                    
                    // Static, flat warning icon
                    ZStack {
                        Circle()
                            .fill(warningColor.opacity(0.1))
                            .frame(width: 150, height: 150)

                        Circle()
                            .stroke(warningColor.opacity(0.25), lineWidth: 6)
                            .frame(width: 150, height: 150)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 70)
                            .foregroundColor(warningColor)
                    }
                    .padding(.bottom, 10)
                    // Title with animation
                    Text("Delete All Data?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    // Warning subtitle
                    Text("This action cannot be undone. All your saved items will be permanently removed.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 10)
                    
                    Spacer()
                    
                    // Text Field with animated styling
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type DELETE to confirm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 5)
                        
                        TextField("DELETE", text: $deleteConfirmationText)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                deleteConfirmationText.isEmpty ? Color.clear :
                                                deleteConfirmationText == "DELETE" ? warningColor : Color.gray,
                                                lineWidth: 2
                                            )
                                    )
                            )
                            .multilineTextAlignment(.center)
                            .font(.system(size: 17, weight: .medium))
                            .autocapitalization(.none)
                            .overlay(
                                HStack {
                                    if !deleteConfirmationText.isEmpty {
                                        Button(action: {
                                            deleteConfirmationText = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .padding(.trailing, 16)
                                        }
                                        .transition(.opacity)
                                        .animation(.easeInOut, value: deleteConfirmationText.isEmpty)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            )
                            .modifier(ShakeEffect(animatableData: isShaking ? 1 : 0))
                            .onChange(of: deleteConfirmationText) { newText in
                                if newText.lowercased() == "smartstashisthebest" {
                                    showConfetti = true
                                    ConfettiHelper.shared.showConfetti()
                                    withAnimation(.spring()) {
                                        scale = 1.05
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        showConfetti = false
                                    }
                                }
                            }
                    }
                    .padding(.horizontal, 24)
                    
                    // Delete Button with improved styling and animation
                    Button(action: {
                        if deleteConfirmationText == "DELETE" {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                buttonPressed = true
                            }
                            
                            // Add haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                confirmAction()
                                dismiss()
                            }
                        } else {
                            withAnimation(.default) {
                                isShaking = true
                            }
                            // Add haptic feedback for error
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isShaking = false
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Delete All")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(deleteConfirmationText == "DELETE" ? warningColor : Color.gray.opacity(0.6))
                                .shadow(
                                    color: deleteConfirmationText == "DELETE" ? warningColor.opacity(0.4) : Color.clear,
                                    radius: 8, x: 0, y: 4
                                )
                        )
                        .scaleEffect(buttonPressed ? 0.95 : 1.0)
                    }
                    .disabled(deleteConfirmationText != "DELETE")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    
                    // Cancel button with improved styling
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemGray6))
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                .scaleEffect(scale)
            }
            .navigationTitle("Delete All Data")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Shake effect modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 5), y: 0))
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
