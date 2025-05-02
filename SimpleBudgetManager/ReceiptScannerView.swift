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

// Add a coordinator to handle data flow between views
class TransactionCoordinator: ObservableObject {
    @Published var scannedAmount: Double?
    @Published var shouldOpenTransactionEntry = false
    
    func setScannedAmount(_ amount: Double) {
        self.scannedAmount = amount
        self.shouldOpenTransactionEntry = true
    }
    
    func resetScannedAmount() {
        self.scannedAmount = nil
        self.shouldOpenTransactionEntry = false
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Receipt Preview Area
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
                    
                    // 3D-themed Processing Indicator
                    if isProcessing {
                        VStack(spacing: 20) {
                            ZStack {
                                // Animated rotating cube effect
                                ForEach(0..<4) { index in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [bluePurpleColor.opacity(0.8), Color.gray.opacity(0.6)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 20, height: 20)
                                        .rotationEffect(.degrees(Double(index) * 90))
                                        .offset(y: -30)
                                        .animation(
                                            Animation.easeInOut(duration: 1.5)
                                                .repeatForever()
                                                .delay(Double(index) * 0.2),
                                            value: animationTrigger
                                        )
                                }
                                
                                // Circular spinner
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [bluePurpleColor.opacity(0.2), bluePurpleColor]),
                                            center: .center
                                        ),
                                        lineWidth: 4
                                    )
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(Angle(degrees: animationTrigger ? 360 : 0))
                                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: animationTrigger)
                            }
                            
                            Text("Processing receipt...")
                                .font(.headline)
                                .foregroundColor(bluePurpleColor)
                        }
                        .padding(.vertical, 20)
                                                    .onAppear {
                            // Ensure animations start when view appears
                            animationTrigger = true
                        }
                    }
                    
                    // Scan Button
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
                        recognizeTextFromImage(image)
                    }
                })
            }
            .sheet(isPresented: $showingResults) {
                ResultsView(
                    recognizedTotal: $recognizedTotal,
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
                    prefilledAmount: coordinator.scannedAmount
                )
            }
        }
    }
    
    private func recognizeTextFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        
        // Create a new Vision text recognition request
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                isProcessing = false
                return
            }
            
            // Process all recognized text
            let recognizedText = observations.compactMap { observation in
                return observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            // Extract the total amount from the recognized text
            self.extractTotal(from: recognizedText)
        }
        
        // Configure the text recognition request
        request.recognitionLevel = .accurate
        
        // Create a request handler and perform the request
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Error performing OCR: \(error)")
            }
        }
    }
    
    private func extractTotal(from text: String) {
        // Common patterns for total amounts on receipts
        let patterns = [
            "(?i)total\\s*[:\\$]?\\s*([0-9]+[.,][0-9]{2})",
            "(?i)amount\\s*[:\\$]?\\s*([0-9]+[.,][0-9]{2})",
            "(?i)subtotal\\s*[:\\$]?\\s*([0-9]+[.,][0-9]{2})",
            "(?i)\\$\\s*([0-9]+[.,][0-9]{2})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsString = text as NSString
                let range = NSRange(location: 0, length: nsString.length)
                
                if let match = regex.firstMatch(in: text, range: range) {
                    let matchRange = match.range(at: 1)
                    if matchRange.location != NSNotFound {
                        let totalString = nsString.substring(with: matchRange)
                        DispatchQueue.main.async {
                            self.recognizedTotal = totalString
                            self.isProcessing = false
                            self.showingResults = true
                        }
                        return
                    }
                }
            }
        }
        
        // If no total is found
        DispatchQueue.main.async {
            self.recognizedTotal = "No total found"
            self.isProcessing = false
            self.showingResults = true
        }
    }
}
struct ResultsView: View {
    @Binding var recognizedTotal: String?
    @ObservedObject var coordinator: TransactionCoordinator
    var onDismiss: () -> Void
    @State private var amount: Double?
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("Receipt Total")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Review and confirm the amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Receipt Total Card
                if let recognizedTotal = recognizedTotal {
                    VStack(alignment: .center, spacing: 10) {
                        Text("Detected Amount")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("$\(recognizedTotal)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(bluePurpleColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(bluePurpleColor.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                }
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adjust if needed")
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
                                } else if let recognizedTotal = self.recognizedTotal,
                                          let numericTotal = Double(recognizedTotal.replacingOccurrences(of: ",", with: ".")) {
                                    return String(format: "%.2f", numericTotal)
                                }
                                return ""
                            },
                            set: { newValue in
                                if let numericValue = Double(newValue) {
                                    self.amount = numericValue
                                }
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
                .padding(.top, 10)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        if let amount = self.amount {
                            coordinator.setScannedAmount(amount)
                        } else if let recognizedTotal = self.recognizedTotal,
                                  let numericTotal = Double(recognizedTotal.replacingOccurrences(of: ",", with: ".")) {
                            coordinator.setScannedAmount(numericTotal)
                        }
                        onDismiss()
                    }) {
                        Text("Use This Amount")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(.white)
                            .background(bluePurpleColor)
                            .cornerRadius(16)
                    }
                    .contentShape(Rectangle())  // Ensure the entire button area is tappable
                    
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
                    .contentShape(Rectangle())  // Ensure the entire button area is tappable
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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
}

// Modified Transaction Entry View that accepts a prefilled amount
struct ModifiedAddTransactionView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    var prefilledAmount: Double?

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
    
    init(viewModel: BudgetViewModel, isPresented: Binding<Bool>, prefilledAmount: Double?) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.prefilledAmount = prefilledAmount
        
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
    }

    var body: some View {
        VStack(spacing: 0) {
            TransactionHeaderView(
                title: "Add Transaction",
                onClose: { isPresented = false },
                onDateTap: { isDatePickerPresented.toggle() }
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
                            date: selectedDate
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
    private var isFlashEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
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
        captureSession.sessionPreset = .high
    }
    class PaddedLabel: UILabel {
        var contentInset: UIEdgeInsets = .zero

        override func drawText(in rect: CGRect) {
            let insetRect = rect.inset(by: contentInset)
            super.drawText(in: insetRect)
        }

        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width + contentInset.left + contentInset.right,
                          height: size.height + contentInset.top + contentInset.bottom)
        }
    }
    
    private func setupUI() {
        // Add preview layer
        if let previewLayer = previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }
        
        // Setup receipt overlay guide (semi-transparent rectangle)
        receiptOverlayView = UIView()
        receiptOverlayView.translatesAutoresizingMaskIntoConstraints = false
        receiptOverlayView.layer.borderColor = UIColor.white.cgColor
        receiptOverlayView.layer.borderWidth = 2.0
        receiptOverlayView.layer.cornerRadius = 12
        receiptOverlayView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.addSubview(receiptOverlayView)
        
        let guideLabel = PaddedLabel()
        guideLabel.translatesAutoresizingMaskIntoConstraints = false
        guideLabel.text = "Position receipt within frame"
        guideLabel.textColor = .white
        guideLabel.textAlignment = .center
        guideLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        guideLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        guideLabel.layer.cornerRadius = 8
        guideLabel.clipsToBounds = true
        guideLabel.contentInset = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        view.addSubview(guideLabel)
        
        // Setup shutter button - with container view
        let shutterContainer = UIView()
        shutterContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shutterContainer)
        
        // Create outer circle button
        shutterButton = UIButton(type: .custom)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = getBluePurpleColor()
        shutterButton.layer.cornerRadius = 35
        shutterButton.clipsToBounds = true
        shutterContainer.addSubview(shutterButton)
        
        // Create inner white circle as a subview with smaller constraints
        let innerCircle = UIView()
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30
        innerCircle.isUserInteractionEnabled = false
        shutterContainer.addSubview(innerCircle)
        
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: shutterContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: shutterContainer.centerYAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),
            
            innerCircle.centerXAnchor.constraint(equalTo: shutterContainer.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: shutterContainer.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        
        // Setup cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cancelButton.layer.cornerRadius = 20
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        // Setup flash button
        flashButton = UIButton(type: .system)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flashButton.layer.cornerRadius = 20
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        view.addSubview(flashButton)
        
        // Add constraints
        NSLayoutConstraint.activate([
            // Receipt overlay - centered with appropriate size
            receiptOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            receiptOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            receiptOverlayView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            receiptOverlayView.heightAnchor.constraint(equalTo: receiptOverlayView.widthAnchor, multiplier: 1.4),
            
            // Guide label
            guideLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideLabel.topAnchor.constraint(equalTo: receiptOverlayView.bottomAnchor, constant: 16),
            
            // Shutter container
            shutterContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterContainer.widthAnchor.constraint(equalToConstant: 80),
            shutterContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Cancel button
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Flash button
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func getBluePurpleColor() -> UIColor {
        // Create the bluePurple color to match your theme
        return UIColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1.0)
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
        print("Shutter button tapped - capturing photo")
        
        guard let photoOutput = photoOutput else {
            print("Error: photoOutput is nil")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        
        // Add capture feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
        
        // Visual feedback - animate the shutter
        UIView.animate(withDuration: 0.1, animations: {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.shutterButton.transform = CGAffineTransform.identity
            }
        }
        
        // Configure flash
        if let device = AVCaptureDevice.default(for: .video),
           device.hasTorch {
            do {
                try device.lockForConfiguration()
                if isFlashEnabled {
                    settings.flashMode = .on
                } else {
                    settings.flashMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("Error configuring device: \(error.localizedDescription)")
            }
        }
        
        // Capture the photo
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancel() {
        delegate?.didCancel()
    }
    
    @objc private func toggleFlash() {
        isFlashEnabled.toggle()
        
        if isFlashEnabled {
            flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        } else {
            flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
}

// AVCapturePhotoCaptureDelegate implementation
extension CustomCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("Photo capture completed")
        
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error: Couldn't get image data representation")
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            print("Error: Couldn't create UIImage from data")
            return
        }
        
        print("Successfully created image, notifying delegate")
        
        // Ensure delegate method is called on main thread
        DispatchQueue.main.async {
            self.delegate?.didCaptureImage(image)
        }
    }
}

// Extension to add padding to UILabel
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
