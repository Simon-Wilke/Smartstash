//
//  ReceiptScannerView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 4/30/25.
//
import SwiftUI
import AVFoundation
import Vision
import VisionKit

class TransactionCoordinator: ObservableObject {
    @Published var scannedAmount: Double?
    @Published var scannedDate: Date?
    @Published var shouldOpenTransactionEntry = false
    
    func setScannedDataAndProceed(amount: Double, date: Date? = nil) {
        self.scannedAmount = amount
        self.scannedDate = date
        self.shouldOpenTransactionEntry = true
    }
    
    func resetScannedData() {
        self.scannedAmount = nil
        self.scannedDate = nil
        self.shouldOpenTransactionEntry = false
    }
}

class ReceiptOCRManager {
    // MARK: - Properties
    private var isProcessing: Bool = false
    private var recognizedTotal: String = ""
    private var recognizedDate: Date?
    private var showingResults: Bool = false
    private var onCompletion: ((String, Date?, Bool) -> Void)?

    // MARK: - Public methods
    func scanReceipt(from image: UIImage, completion: @escaping (String, Date?, Bool) -> Void) {
        isProcessing = true
        onCompletion = completion
        recognizeTextFromImage(image)
    }

    // MARK: - Private methods
    private func recognizeTextFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            completeProcess(with: "Invalid image", date: nil, success: false)
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self, error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                self?.completeProcess(with: "Text recognition failed", date: nil, success: false)
                return
            }
            
            // Extract all text with confidence scores
            var allText: [String] = []
            var textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)] = []
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                
                // Only include text with reasonable confidence
                if candidate.confidence > 0.3 {
                    allText.append(candidate.string)
                    textBlocks.append((
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    ))
                }
            }
            
            // Sort blocks by vertical position (top to bottom)
            textBlocks.sort { $0.boundingBox.maxY > $1.boundingBox.maxY }
            
            let fullText = allText.joined(separator: "\n")
            print("=== FULL OCR TEXT ===")
            print(fullText)
            print("===================")
            
            // Extract date and amount
            let extractedDate = self.extractDate(from: fullText, textBlocks: textBlocks)
            let extractedAmount = self.extractAmount(from: fullText, textBlocks: textBlocks)
            
            print("Extracted date: \(extractedDate?.description ?? "nil")")
            print("Extracted amount: \(extractedAmount)")
            
            self.completeProcess(with: extractedAmount, date: extractedDate, success: !extractedAmount.isEmpty)
        }
        
        // Configure for better accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-CA"]
        request.automaticallyDetectsLanguage = true
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                self.completeProcess(with: "OCR processing failed", date: nil, success: false)
            }
        }
    }
    
    // MARK: - Date Extraction
    private func extractDate(from text: String, textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> Date? {
        print("=== DATE EXTRACTION DEBUG ===")
        
        // Strategy 1: Use NSDataDetector for built-in date detection
        if let detectedDate = extractDateUsingDetector(from: text) {
            print("Found date using NSDataDetector: \(detectedDate)")
            return detectedDate
        }
        
        // Strategy 2: Manual pattern matching with common formats
        if let patternDate = extractDateUsingPatterns(from: text) {
            print("Found date using patterns: \(patternDate)")
            return patternDate
        }
        
        // Strategy 3: Look in top portion of receipt (common location)
        let topBlocks = Array(textBlocks.suffix(textBlocks.count / 2))
        for block in topBlocks {
            if let blockDate = extractDateUsingPatterns(from: block.text) {
                print("Found date in top block: \(blockDate)")
                return blockDate
            }
        }
        
        print("No date found")
        return nil
    }
    
    private func extractDateUsingDetector(from text: String) -> Date? {
        print("🔍 === DATE EXTRACTION DEBUG (NSDataDetector) ===")
        print("📝 Input text length: \(text.count) characters")
        print("📝 Input text preview: \(String(text.prefix(200)))")
        print("📝 Full text: \(text)")
        
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            print("📅 NSDataDetector found \(matches.count) potential date matches")
            
            let calendar = Calendar.current
            let now = Date()
            let threeYearsAgo = calendar.date(byAdding: .year, value: -3, to: now)!
            let oneMonthFromNow = calendar.date(byAdding: .month, value: 1, to: now)!
            
            print("📅 Date validation range: \(threeYearsAgo) to \(oneMonthFromNow)")
            
            // Log all matches first
            for (index, match) in matches.enumerated() {
                let matchedText = (text as NSString).substring(with: match.range)
                print("📅 Match \(index + 1): '\(matchedText)' at range \(match.range)")
                
                if let date = match.date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    print("📅   → Parsed as: \(formatter.string(from: date))")
                    print("📅   → Raw date: \(date)")
                    
                    let isValid = date >= threeYearsAgo && date <= oneMonthFromNow
                    print("📅   → Valid date range: \(isValid)")
                    
                    if !isValid {
                        if date < threeYearsAgo {
                            print("📅   → ❌ Too old (before \(threeYearsAgo))")
                        } else if date > oneMonthFromNow {
                            print("📅   → ❌ Too far in future (after \(oneMonthFromNow))")
                        }
                    }
                } else {
                    print("📅   → ❌ Could not parse as date")
                }
            }
            
            // Find the most reasonable date
            for (index, match) in matches.enumerated() {
                guard let date = match.date else {
                    print("📅 Skipping match \(index + 1): no date object")
                    continue
                }
                
                // Filter out unreasonable dates
                if date >= threeYearsAgo && date <= oneMonthFromNow {
                    let matchedText = (text as NSString).substring(with: match.range)
                    print("✅ SELECTED DATE: '\(matchedText)' → \(date)")
                    print("🔍 === END DATE EXTRACTION DEBUG ===")
                    return date
                } else {
                    print("❌ Rejected match \(index + 1): date out of valid range")
                }
            }
            
            print("❌ No valid dates found in range")
            
        } catch {
            print("❌ NSDataDetector error: \(error)")
        }
        
        print("🔍 === END DATE EXTRACTION DEBUG (No date found) ===")
        return nil
    }
    
    private func extractDateUsingPatterns(from text: String) -> Date? {
        let datePatterns = [
            // MM/DD/YYYY, MM/DD/YY
            ("(\\d{1,2})/(\\d{1,2})/(\\d{2,4})", "MM/dd/yyyy"),
            // DD/MM/YYYY, DD/MM/YY
            ("(\\d{1,2})/(\\d{1,2})/(\\d{2,4})", "dd/MM/yyyy"),
            // YYYY-MM-DD
            ("(\\d{4})-(\\d{1,2})-(\\d{1,2})", "yyyy-MM-dd"),
            // MM-DD-YYYY
            ("(\\d{1,2})-(\\d{1,2})-(\\d{2,4})", "MM-dd-yyyy"),
            // Month DD, YYYY
            ("(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* (\\d{1,2}),? (\\d{4})", "MMM d, yyyy"),
            // DD Month YYYY
            ("(\\d{1,2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* (\\d{4})", "d MMM yyyy")
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        
        for (pattern, format) in datePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for match in matches {
                    let matchedString = nsString.substring(with: match.range)
                    print("Trying to parse date: '\(matchedString)' with format: '\(format)'")
                    
                    // Try different format variations
                    let formats = [format, format.replacingOccurrences(of: "yyyy", with: "yy")]
                    
                    for tryFormat in formats {
                        dateFormatter.dateFormat = tryFormat
                        if let date = dateFormatter.date(from: matchedString) {
                            // Validate date is reasonable
                            let calendar = Calendar.current
                            let now = Date()
                            let threeYearsAgo = calendar.date(byAdding: .year, value: -3, to: now)!
                            let oneMonthFromNow = calendar.date(byAdding: .month, value: 1, to: now)!
                            
                            if date >= threeYearsAgo && date <= oneMonthFromNow {
                                return date
                            }
                        }
                    }
                }
            } catch {
                print("Regex error for pattern \(pattern): \(error)")
            }
        }
        
        return nil
    }
    
    // MARK: - Amount Extraction
    private func extractAmount(from text: String, textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> String {
        print("=== AMOUNT EXTRACTION DEBUG ===")
        
        var candidates: [(amount: Double, confidence: Double, source: String)] = []
        
        // Strategy 1: Look for explicit total indicators
        candidates.append(contentsOf: findAmountsWithTotalKeywords(in: text))
        
        // Strategy 2: Look in bottom portion (where totals usually are)
        candidates.append(contentsOf: findAmountsInBottomSection(textBlocks: textBlocks))
        
        // Strategy 3: Find largest reasonable amount
        candidates.append(contentsOf: findLargestReasonableAmount(in: text))
        
        // Sort by confidence and select best candidate
        candidates.sort { $0.confidence > $1.confidence }
        
        print("Amount candidates found:")
        for candidate in candidates.prefix(5) {
            print("  $\(String(format: "%.2f", candidate.amount)) - confidence: \(candidate.confidence) - source: \(candidate.source)")
        }
        
        if let bestCandidate = candidates.first {
            return String(format: "%.2f", bestCandidate.amount)
        }
        
        return ""
    }
    
    private func findAmountsWithTotalKeywords(in text: String) -> [(amount: Double, confidence: Double, source: String)] {
        var results: [(amount: Double, confidence: Double, source: String)] = []
        
        let totalKeywords = [
            "total", "amount due", "balance due", "grand total",
            "payment", "charged", "amount paid", "final total"
        ]
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let lowerLine = line.lowercased()
            
            // Skip subtotal lines
            if lowerLine.contains("subtotal") || lowerLine.contains("sub-total") ||
               lowerLine.contains("before tax") || lowerLine.contains("pre-tax") {
                continue
            }
            
            // Check if line contains total keywords
            for keyword in totalKeywords {
                if lowerLine.contains(keyword) {
                    if let amounts = extractAllAmountsFromLine(line) {
                        for amount in amounts {
                            let confidence = keyword == "total" ? 0.9 : 0.8
                            results.append((amount, confidence, "keyword: \(keyword)"))
                        }
                    }
                    break
                }
            }
        }
        
        return results
    }
    
    private func findAmountsInBottomSection(textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> [(amount: Double, confidence: Double, source: String)] {
        var results: [(amount: Double, confidence: Double, source: String)] = []
        
        // Focus on bottom third of receipt
        let bottomBlocks = Array(textBlocks.prefix(textBlocks.count / 3))
        
        for (index, block) in bottomBlocks.enumerated() {
            if let amounts = extractAllAmountsFromLine(block.text) {
                for amount in amounts {
                    // Higher confidence for blocks closer to bottom
                    let positionConfidence = 0.6 + (0.3 * Double(index) / Double(bottomBlocks.count))
                    results.append((amount, positionConfidence, "bottom section"))
                }
            }
        }
        
        return results
    }
    
    private func findLargestReasonableAmount(in text: String) -> [(amount: Double, confidence: Double, source: String)] {
        var results: [(amount: Double, confidence: Double, source: String)] = []
        var allAmounts: [Double] = []
        
        // Find all amounts in the text
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if let amounts = extractAllAmountsFromLine(line) {
                allAmounts.append(contentsOf: amounts)
            }
        }
        
        // Filter out unreasonable amounts (too small or too large)
        let reasonableAmounts = allAmounts.filter { $0 >= 0.01 && $0 <= 10000.0 }
        
        if let maxAmount = reasonableAmounts.max() {
            // If the largest amount appears multiple times, it's more likely to be the total
            let occurrences = reasonableAmounts.filter { abs($0 - maxAmount) < 0.01 }.count
            let confidence = occurrences > 1 ? 0.7 : 0.5
            results.append((maxAmount, confidence, "largest amount"))
        }
        
        return results
    }
    
    private func extractAllAmountsFromLine(_ line: String) -> [Double]? {
        var amounts: [Double] = []
        
        // Patterns for currency amounts
        let patterns = [
            "\\$\\s*([0-9]+(?:[,.][0-9]{2})?)", // $XX.XX or $XX,XX
            "([0-9]+\\.[0-9]{2})\\s*\\$?", // XX.XX with optional $
            "([0-9]+,[0-9]{2})\\s*\\$?", // XX,XX with optional $
            "([0-9]+(?:\\.[0-9]{2})?)\\s*(?:USD|CAD|dollars?)", // XX.XX USD/CAD/dollars
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsString = line as NSString
                let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let amountString = nsString.substring(with: match.range(at: 1))
                        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".")
                        
                        if let amount = Double(cleanAmount), amount > 0 {
                            amounts.append(amount)
                        }
                    }
                }
            } catch {
                print("Regex error: \(error)")
            }
        }
        
        return amounts.isEmpty ? nil : amounts
    }
    
    private func completeProcess(with result: String, date: Date?, success: Bool) {
        DispatchQueue.main.async {
            self.recognizedTotal = result
            self.recognizedDate = date
            self.isProcessing = false
            self.showingResults = true
            self.onCompletion?(result, date, success)
        }
    }
}
struct ReceiptScannerView: View {
    @StateObject var coordinator = TransactionCoordinator()
    @State private var showingCamera = false
    @State private var scannedImage: UIImage?
    @State private var recognizedTotal: String?
    @State private var isProcessing = false
    @State private var animationTrigger = false
    @State private var showingResults = false
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    @State private var recognizedDate: Date? = nil
    
    private let ocrManager = ReceiptOCRManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // Tasteful beta badge
                    HStack {
                        Spacer()
                        Text("Early Beta – Feature in Development")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                bluePurpleColor.opacity(0.1)
                            )
                            .foregroundColor(bluePurpleColor)
                            .cornerRadius(12)
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Receipt preview
                    if let scannedImage = scannedImage {
                        Image(uiImage: scannedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 350)
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .frame(maxWidth: .infinity)
                                .frame(height: 350)
                            
                            VStack(spacing: 16) {
                                Image(systemName: "receipt")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .foregroundColor(.gray)
                                
                                Text("No Receipt Scanned")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Processing animation
                    if isProcessing {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .trim(from: 0, to: 0.75)
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [
                                                bluePurpleColor.opacity(0.2),
                                                bluePurpleColor,
                                                bluePurpleColor.opacity(0.8)
                                            ]),
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(Angle(degrees: animationTrigger ? 360 : 0))
                                    .animation(
                                        Animation.linear(duration: 1.2)
                                            .repeatForever(autoreverses: false),
                                        value: animationTrigger
                                    )
                                
                                Circle()
                                    .fill(bluePurpleColor.opacity(0.6))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(animationTrigger ? 1.2 : 0.8)
                                    .animation(
                                        Animation.easeInOut(duration: 1.0)
                                            .repeatForever(autoreverses: true),
                                        value: animationTrigger
                                    )
                            }
                            .frame(height: 80)
                            
                            Text("Processing receipt...")
                                .font(.headline)
                                .foregroundColor(bluePurpleColor)
                                .opacity(animationTrigger ? 1.0 : 0.7)
                                .animation(
                                    Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true),
                                    value: animationTrigger
                                )
                        }
                        .padding(.vertical, 20)
                        .onAppear {
                            withAnimation {
                                animationTrigger = true
                            }
                        }
                        .onDisappear {
                            animationTrigger = false
                        }
                    }
                    
                    // Scan button
                    Button(action: {
                        self.showingCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.headline)
                            Text("Scan Receipt")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .foregroundColor(.white)
                        .background(bluePurpleColor)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Receipt Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .foregroundColor(bluePurpleColor)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CustomCameraView(image: $scannedImage, onImageCaptured: {
                    self.isProcessing = true
                    if let image = scannedImage {
                        processReceiptImage(image)
                    }
                })
            }
            .sheet(isPresented: $showingResults) {
                ResultsView(
                    recognizedTotal: $recognizedTotal,
                    recognizedDate: $recognizedDate,
                    coordinator: coordinator,
                    onDismiss: {
                        showingResults = false
                    }
                )
            }
            .fullScreenCover(isPresented: $coordinator.shouldOpenTransactionEntry) {
                ModifiedAddTransactionView(
                    viewModel: viewModel,
                    isPresented: $isPresented,
                    prefilledAmount: coordinator.scannedAmount,
                    prefilledDate: coordinator.scannedDate
                )
            }
        }
    }
    
    private func processReceiptImage(_ image: UIImage) {
        ocrManager.scanReceipt(from: image) { (extractedTotal, extractedDate, success) in
            self.recognizedTotal = extractedTotal
            self.recognizedDate = extractedDate
            self.isProcessing = false
            self.showingResults = true
        }
    }
}

struct ResultsView: View {
    @Binding var recognizedTotal: String?
    @Binding var recognizedDate: Date?
    @ObservedObject var coordinator: TransactionCoordinator
    var onDismiss: () -> Void

    @State private var amount: Double?
    @State private var selectedDate: Date = Date()
    @State private var isEditingDate = false
    @FocusState private var isAmountFocused: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 25) {
                // Header
                VStack(spacing: 8) {
                    Text("Receipt Details")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Review and confirm the information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Total Card
                if let total = recognizedTotal, !total.isEmpty {
                    VStack(spacing: 10) {
                        Text("Detected Amount")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("$\(total)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(bluePurpleColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(bluePurpleColor.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 10) {
                        Text("No Amount Detected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Please enter manually")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                }

                // Date Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Transaction Date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Edit") {
                            isEditingDate = true
                        }
                        .font(.subheadline)
                        .foregroundColor(bluePurpleColor)
                    }

                    Text(dateFormatter.string(from: recognizedDate ?? selectedDate))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(bluePurpleColor)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(bluePurpleColor.opacity(0.1))
                )
                .padding(.horizontal, 24)

                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adjust amount if needed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)

                    HStack {
                        Text("$")
                            .font(.title3)
                            .foregroundColor(isAmountFocused ? bluePurpleColor : .secondary)

                        TextField("0.00", text: Binding(
                            get: {
                                if let amount = self.amount {
                                    return String(format: "%.2f", amount)
                                } else if let total = self.recognizedTotal,
                                          let parsed = Double(total.replacingOccurrences(of: ",", with: ".")) {
                                    return String(format: "%.2f", parsed)
                                }
                                return ""
                            },
                            set: { newValue in
                                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                self.amount = Double(filtered)
                            }
                        ))
                        .keyboardType(.decimalPad)
                        .font(.title3)
                        .focused($isAmountFocused)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isAmountFocused ? bluePurpleColor : Color.gray.opacity(0.3), lineWidth: 2)
                            .background(Color(.systemGray6).cornerRadius(16))
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        let finalAmount = getCurrentAmount()
                        let finalDate = recognizedDate ?? selectedDate

                        guard let amount = finalAmount, amount > 0 else { return }

                        coordinator.setScannedDataAndProceed(amount: amount, date: finalDate)
                        onDismiss()
                    }) {
                        Text("Use This Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(.white)
                            .background(bluePurpleColor)
                            .cornerRadius(16)
                    }
                    .disabled(getCurrentAmount() == nil || getCurrentAmount() == 0)
                    .opacity(getCurrentAmount() == nil || getCurrentAmount() == 0 ? 0.6 : 1.0)

                    Button(action: {
                        onDismiss()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(bluePurpleColor)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(bluePurpleColor, lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $isEditingDate) {
            NavigationView {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: Calendar.current.date(byAdding: .year, value: -2, to: Date())!...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                    Spacer()
                }
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isEditingDate = false
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            recognizedDate = selectedDate
                            isEditingDate = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            if let recognized = recognizedDate {
                selectedDate = recognized
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    isAmountFocused = false
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(bluePurpleColor)
            }
        }
    }

    private func getCurrentAmount() -> Double? {
        if let amount = self.amount {
            return amount
        } else if let total = recognizedTotal,
                  let parsed = Double(total.replacingOccurrences(of: ",", with: ".")) {
            return parsed
        }
        return nil
    }
}

    




// Modified Transaction Entry View that accepts both prefilled amount AND date
struct ModifiedAddTransactionView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    var prefilledAmount: Double?
    var prefilledDate: Date?  // ✅ Add date parameter

    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var type: Transaction.TransactionType = .expense
    @State private var recurrence: Transaction.RecurrenceType = .oneTime
    @State private var notes: String = ""
    @State private var selectedIcon: String = "💵"
    @State private var showDecimalPad: Bool = false
    @State private var keyframeBounce: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isDatePickerPresented = false
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
            let decimalPart = String(components[1].prefix(2))
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
    
    init(viewModel: BudgetViewModel, isPresented: Binding<Bool>, prefilledAmount: Double?, prefilledDate: Date? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.prefilledAmount = prefilledAmount
        self.prefilledDate = prefilledDate
        
        // Initialize the amount field with the scanned value if provided
        if let prefilled = prefilledAmount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            
            if let formattedAmount = formatter.string(from: NSNumber(value: prefilled)) {
                _amount = State(initialValue: formattedAmount)
            }
        }
        
        // ✅ Initialize the date with scanned value if provided
        if let prefilled = prefilledDate {
            _selectedDate = State(initialValue: prefilled)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ✅ Update header to show scanned date if available
            TransactionHeaderView(
                title: prefilledDate != nil ? "Scanned Transaction" : "Add Transaction",
                onClose: { isPresented = false },
                onDateTap: { isDatePickerPresented.toggle() }
            )
            
            TransactionTypeSelector(selectedType: $type)
                .padding(.top, -70)
            
            // ✅ Add visual indicator if data was scanned from receipt
            if prefilledAmount != nil || prefilledDate != nil {
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(bluePurpleColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data from Receipt")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(bluePurpleColor)
                        HStack {
                            if prefilledAmount != nil {
                                Text("Amount: ✓")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            if prefilledDate != nil {
                                Text("Date: ✓")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
                .background(bluePurpleColor.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            
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
            .padding(.top, prefilledAmount != nil || prefilledDate != nil ? 30 : 50)
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
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                if showDecimalPad {
                    decimalPadView()
                        .padding(.bottom, 20)
                        .frame(height: 350)
                        .transition(.opacity.combined(with: .scale(scale: 1.1)))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showDecimalPad)
            
            // Save Button
            SaveButtonView(
                onSave: {
                    let cleanedAmount = amount.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
                    
                    if let amountValue = Double(cleanedAmount), !category.isEmpty, amountValue > 0 {
                        let transaction = Transaction(
                            amount: amountValue,
                            category: category,
                            type: type,
                            recurrence: recurrence,
                            notes: notes.isEmpty ? nil : notes,
                            icon: selectedIcon,
                            date: selectedDate  // ✅ Uses the selectedDate (which can be from receipt)
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
        .onAppear {
            // Convert the prefilled amount to the proper format when the view appears
            if let prefilled = prefilledAmount {
                amount = String(format: "%.2f", prefilled)
            }
            
            // ✅ Set the date if it was scanned from receipt
            if let prefilled = prefilledDate {
                selectedDate = prefilled
            }
        }
        
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
                        
                        // Title - show if date was scanned
                        VStack(spacing: 4) {
                            Text("Select Date & Time")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(UIColor.label))
                            
                            if prefilledDate != nil {
                                Text("Receipt date: \(prefilledDate!.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.primary)
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
import AVFoundation
import UIKit

struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageCaptured: () -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> CustomCameraViewController {
        let viewController = CustomCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: CustomCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CustomCameraViewControllerDelegate {
        let parent: CustomCameraView
        
        init(_ parent: CustomCameraView) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            parent.image = image
            parent.onImageCaptured()
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func didCancel() {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

protocol CustomCameraViewControllerDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
    func didCancel()
}

class CustomCameraViewController: UIViewController {
    weak var delegate: CustomCameraViewControllerDelegate?
    
    // Camera components
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    
    // UI elements
    private var shutterButton: UIButton!
    private var cancelButton: UIButton!
    private var receiptOverlayView: UIView!
    private var flashButton: UIButton!
    private var torchButton: UIButton!
    private var overlayView: UIView!
    private var maskView: UIView!

    private var captureIndicator: UIView!
    private var topControlsStackView: UIStackView!
    private var bottomControlsView: UIView!
    private var guidanceLabel: UILabel!
    private var guidanceLabelContainer: UIView!
    private var cornerViews: [UIView] = []
    
    private var isFlashEnabled = false
    private var isTorchEnabled = false
    private var isUsingFrontCamera = false
    private var currentCameraInput: AVCaptureDeviceInput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
        setupUI()
        setupGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCaptureSession()
        animateGuidanceAppearance()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateOverlayMask()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        // Setup the camera input
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            showAlert(title: "Camera Error", message: "Unable to access the camera")
            return
        }
        
        currentCameraInput = input
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // Setup photo output
        photoOutput = AVCapturePhotoOutput()
        photoOutput?.isHighResolutionCaptureEnabled = true
        
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        // Set session preset for better quality
        captureSession.sessionPreset = .photo
    }
    
    private func setupUI() {
        setupPreviewLayer()
        setupOverlayGuide()
        setupTopControls()
        setupBottomControls()
        setupCaptureIndicator()
        layoutConstraints()
    }
    
    private func setupPreviewLayer() {
        guard let previewLayer = previewLayer else { return }
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupOverlayGuide() {
        // Create the clear rectangle for receipt area
        receiptOverlayView = UIView()
        receiptOverlayView.translatesAutoresizingMaskIntoConstraints = false
        receiptOverlayView.backgroundColor = .clear
        view.addSubview(receiptOverlayView)
        
        // Create corner indicators
        createCornerIndicators()
        
        // Create container for guidance label with proper padding
        guidanceLabelContainer = UIView()
        guidanceLabelContainer.translatesAutoresizingMaskIntoConstraints = false
        guidanceLabelContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        guidanceLabelContainer.layer.cornerRadius = 12
        guidanceLabelContainer.clipsToBounds = true
        guidanceLabelContainer.alpha = 0
        view.addSubview(guidanceLabelContainer)
        
        // Add guidance label inside container
        guidanceLabel = UILabel()
        guidanceLabel.translatesAutoresizingMaskIntoConstraints = false
        guidanceLabel.text = "Position receipt within frame"
        guidanceLabel.textColor = .white
        guidanceLabel.textAlignment = .center
        guidanceLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        guidanceLabel.numberOfLines = 1
        guidanceLabelContainer.addSubview(guidanceLabel)
        
        NSLayoutConstraint.activate([
            receiptOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            receiptOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            receiptOverlayView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            receiptOverlayView.heightAnchor.constraint(equalTo: receiptOverlayView.widthAnchor, multiplier: 1.3),
            
            guidanceLabelContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guidanceLabelContainer.topAnchor.constraint(equalTo: receiptOverlayView.bottomAnchor, constant: 40),
            guidanceLabelContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            guidanceLabelContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            guidanceLabelContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Proper padding constraints for the label inside container
            guidanceLabel.topAnchor.constraint(equalTo: guidanceLabelContainer.topAnchor, constant: 12),
            guidanceLabel.leadingAnchor.constraint(equalTo: guidanceLabelContainer.leadingAnchor, constant: 16),
            guidanceLabel.trailingAnchor.constraint(equalTo: guidanceLabelContainer.trailingAnchor, constant: -16),
            guidanceLabel.bottomAnchor.constraint(equalTo: guidanceLabelContainer.bottomAnchor, constant: -12)
        ])
    }
    
    private func updateOverlayMask() {
        guard let maskView = maskView, let receiptOverlayView = receiptOverlayView else { return }
        
        // Update mask frame to match overlay view
        maskView.frame = overlayView.bounds
        
        // Remove existing mask layers
        maskView.layer.sublayers?.removeAll()
        
        // Create new mask layer
        let maskLayer = CAShapeLayer()
        let bounds = overlayView.bounds
        let path = UIBezierPath(rect: bounds)
        
        // Get the actual receipt frame from the receiptOverlayView
        let receiptFrame = receiptOverlayView.frame
        let receiptPath = UIBezierPath(roundedRect: receiptFrame, cornerRadius: 12)
        path.append(receiptPath.reversing())
        
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        
        maskView.layer.addSublayer(maskLayer)
    }
    
    private func createCornerIndicators() {
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 3
        
        for i in 0..<4 {
            let cornerView = UIView()
            cornerView.translatesAutoresizingMaskIntoConstraints = false
            cornerView.backgroundColor = .clear
            receiptOverlayView.addSubview(cornerView)
            cornerViews.append(cornerView)
            
            let horizontalLine = UIView()
            horizontalLine.backgroundColor = .white
            horizontalLine.translatesAutoresizingMaskIntoConstraints = false
            cornerView.addSubview(horizontalLine)
            
            let verticalLine = UIView()
            verticalLine.backgroundColor = .white
            verticalLine.translatesAutoresizingMaskIntoConstraints = false
            cornerView.addSubview(verticalLine)
            
            switch i {
            case 0: // Top-left
                NSLayoutConstraint.activate([
                    cornerView.topAnchor.constraint(equalTo: receiptOverlayView.topAnchor),
                    cornerView.leadingAnchor.constraint(equalTo: receiptOverlayView.leadingAnchor),
                    cornerView.widthAnchor.constraint(equalToConstant: cornerLength),
                    cornerView.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontalLine.topAnchor.constraint(equalTo: cornerView.topAnchor),
                    horizontalLine.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor),
                    horizontalLine.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontalLine.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    verticalLine.topAnchor.constraint(equalTo: cornerView.topAnchor),
                    verticalLine.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor),
                    verticalLine.widthAnchor.constraint(equalToConstant: cornerWidth),
                    verticalLine.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            case 1: // Top-right
                NSLayoutConstraint.activate([
                    cornerView.topAnchor.constraint(equalTo: receiptOverlayView.topAnchor),
                    cornerView.trailingAnchor.constraint(equalTo: receiptOverlayView.trailingAnchor),
                    cornerView.widthAnchor.constraint(equalToConstant: cornerLength),
                    cornerView.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontalLine.topAnchor.constraint(equalTo: cornerView.topAnchor),
                    horizontalLine.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor),
                    horizontalLine.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontalLine.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    verticalLine.topAnchor.constraint(equalTo: cornerView.topAnchor),
                    verticalLine.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor),
                    verticalLine.widthAnchor.constraint(equalToConstant: cornerWidth),
                    verticalLine.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            case 2: // Bottom-left
                NSLayoutConstraint.activate([
                    cornerView.bottomAnchor.constraint(equalTo: receiptOverlayView.bottomAnchor),
                    cornerView.leadingAnchor.constraint(equalTo: receiptOverlayView.leadingAnchor),
                    cornerView.widthAnchor.constraint(equalToConstant: cornerLength),
                    cornerView.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontalLine.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor),
                    horizontalLine.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor),
                    horizontalLine.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontalLine.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    verticalLine.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor),
                    verticalLine.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor),
                    verticalLine.widthAnchor.constraint(equalToConstant: cornerWidth),
                    verticalLine.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            case 3: // Bottom-right
                NSLayoutConstraint.activate([
                    cornerView.bottomAnchor.constraint(equalTo: receiptOverlayView.bottomAnchor),
                    cornerView.trailingAnchor.constraint(equalTo: receiptOverlayView.trailingAnchor),
                    cornerView.widthAnchor.constraint(equalToConstant: cornerLength),
                    cornerView.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontalLine.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor),
                    horizontalLine.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor),
                    horizontalLine.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontalLine.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    verticalLine.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor),
                    verticalLine.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor),
                    verticalLine.widthAnchor.constraint(equalToConstant: cornerWidth),
                    verticalLine.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            default:
                break
            }
        }
    }
    
    private func setupTopControls() {
        // Create background blur for top controls
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        view.addSubview(blurView)
        
        topControlsStackView = UIStackView()
        topControlsStackView.translatesAutoresizingMaskIntoConstraints = false
        topControlsStackView.axis = .horizontal
        topControlsStackView.distribution = .fillEqually
        topControlsStackView.spacing = 12
        blurView.contentView.addSubview(topControlsStackView)
        
        // Flash button
        flashButton = createControlButton(imageName: "bolt.slash.fill", action: #selector(toggleFlash))
        
        // Torch button
        torchButton = createControlButton(imageName: "flashlight.off.fill", action: #selector(toggleTorch))
        
        topControlsStackView.addArrangedSubview(flashButton)
        topControlsStackView.addArrangedSubview(torchButton)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            blurView.widthAnchor.constraint(equalToConstant: 96),
            blurView.heightAnchor.constraint(equalToConstant: 44),
            
            topControlsStackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 8),
            topControlsStackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
            topControlsStackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -12),
            topControlsStackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupBottomControls() {
        bottomControlsView = UIView()
        bottomControlsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomControlsView)
        
        // Setup shutter button with modern design
               let deepBlueColor = UIColor(red: 78/255, green: 87/255, blue: 255/255, alpha: 1.0)
               shutterButton = UIButton(type: .custom)
               shutterButton.translatesAutoresizingMaskIntoConstraints = false
               shutterButton.backgroundColor = .white
               shutterButton.layer.cornerRadius = 35
               shutterButton.layer.borderWidth = 4
               shutterButton.layer.borderColor = deepBlueColor.cgColor
               shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
               bottomControlsView.addSubview(shutterButton)
        
        // Cancel button with modern styling
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        cancelButton.layer.cornerRadius = 22
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        bottomControlsView.addSubview(cancelButton)
    }
    
    private func setupCaptureIndicator() {
        captureIndicator = UIView()
        captureIndicator.translatesAutoresizingMaskIntoConstraints = false
        captureIndicator.backgroundColor = .white
        captureIndicator.alpha = 0
        captureIndicator.isUserInteractionEnabled = false
        view.addSubview(captureIndicator)
        
        NSLayoutConstraint.activate([
            captureIndicator.topAnchor.constraint(equalTo: view.topAnchor),
            captureIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captureIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            captureIndicator.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func layoutConstraints() {
        NSLayoutConstraint.activate([
            bottomControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomControlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomControlsView.heightAnchor.constraint(equalToConstant: 120),
            
            shutterButton.centerXAnchor.constraint(equalTo: bottomControlsView.centerXAnchor),
            shutterButton.topAnchor.constraint(equalTo: bottomControlsView.topAnchor, constant: 20),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),
            
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func createControlButton(imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    private func setupGestures() {
        // Add tap to focus gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func animateGuidanceAppearance() {
        UIView.animate(withDuration: 0.5, delay: 0.5, options: .curveEaseOut) {
            self.guidanceLabelContainer.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseIn) {
                self.guidanceLabelContainer.alpha = 0
            }
        }
    }
    
    @objc private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                      exposureMode: AVCaptureDevice.ExposureMode,
                      at devicePoint: CGPoint?,
                      monitorSubjectAreaChange: Bool) {
        
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                device.focusPointOfInterest = devicePoint ?? CGPoint(x: 0.5, y: 0.5)
                device.focusMode = focusMode
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                device.exposurePointOfInterest = devicePoint ?? CGPoint(x: 0.5, y: 0.5)
                device.exposureMode = exposureMode
            }
            
            device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
            device.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }
    
    private func startCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    @objc private func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        
        // Add haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
        
        // Flash effect
        showCaptureEffect()
        
        // Configure flash
        if let device = AVCaptureDevice.default(for: .video) {
            if isFlashEnabled && device.hasFlash {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
        }
        
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func showCaptureEffect() {
        UIView.animate(withDuration: 0.1) {
            self.captureIndicator.alpha = 0.8
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureIndicator.alpha = 0
            }
        }
    }
    
    @objc private func cancel() {
        delegate?.didCancel()
    }
    
    @objc private func toggleFlash() {
        isFlashEnabled.toggle()
        updateFlashButton()
    }
    
    @objc private func toggleTorch() {
        isTorchEnabled.toggle()
        updateTorchButton()
        setTorchMode(isTorchEnabled)
    }
    
    private func updateFlashButton() {
        let imageName = isFlashEnabled ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
        flashButton.tintColor = isFlashEnabled ? .systemYellow : .white
    }
    
    private func updateTorchButton() {
        let imageName = isTorchEnabled ? "flashlight.on.fill" : "flashlight.off.fill"
        torchButton.setImage(UIImage(systemName: imageName), for: .normal)
        torchButton.tintColor = isTorchEnabled ? .systemYellow : .white
    }
    
    private func setTorchMode(_ isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CustomCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error: Couldn't create UIImage from data")
            return
        }
        
        DispatchQueue.main.async {
            self.delegate?.didCaptureImage(image)
        }
    }
}
extension UILabel {
    private struct AssociatedKeys {
        static var padding = UIEdgeInsets()
    }
    
    var padding: UIEdgeInsets {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.padding) as? UIEdgeInsets ?? UIEdgeInsets.zero
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.padding, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
