//
//  NotificationManager.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 7/30/25.
//

import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Permission Management
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound] // ✅ Removed .badge
            )
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Transaction Reminder
    func scheduleTransactionReminder(at time: Date, repeatDaily: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = "Track Your Spending"
        content.body = "Don't forget to log your recent transactions in Smartstash!"
        content.sound = .default
        content.badge = nil // ✅ No badge

        content.userInfo = [
            "action": "add_transaction",
            "screen": "add_transaction"
        ]

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeatDaily)

        let request = UNNotificationRequest(identifier: "transaction_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Transaction reminder scheduled for \(time)")
            }
        }
    }

    func scheduleBudgetAlert(category: String, spent: Double, budget: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert!"
        content.body = "You've spent $\(String(format: "%.2f", spent)) of your $\(String(format: "%.2f", budget)) \(category) budget"
        content.sound = .default
        content.badge = nil // ✅ No badge

        content.userInfo = [
            "action": "view_budget",
            "screen": "budget",
            "category": category
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: "budget_alert_\(category)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule budget alert: \(error)")
            } else {
                print("✅ Budget alert scheduled for \(category)")
            }
        }
    }

    // MARK: - Cancel
    func cancelTransactionReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["transaction_reminder"])
        print("✅ Transaction reminder cancelled")
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0 // ✅ Clear badge
        print("✅ All notifications cancelled")
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}

// MARK: - Deep Link Handler

class DeepLinkHandler: ObservableObject {
    @Published var activeTab: Int = 0
    @Published var shouldPresentAddTransaction = false
    @Published var shouldNavigateToBudget = false
    @Published var selectedBudgetCategory: String?
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let action = userInfo["action"] as? String else { return }
        
        DispatchQueue.main.async {
            switch action {
            case "add_transaction":
                self.activeTab = 1 // Assuming tab 1 is for adding transactions
                self.shouldPresentAddTransaction = true
                
            case "view_budget":
                self.activeTab = 0 // Assuming tab 0 is for budget view
                self.shouldNavigateToBudget = true
                if let category = userInfo["category"] as? String {
                    self.selectedBudgetCategory = category
                }
                
            default:
                break
            }
        }
    }
}
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Binding var isPresented: Bool
    @Binding var reminderTime: Date
    @Binding var dailyRemindersEnabled: Bool

    @State private var tempReminderTime: Date
    @State private var tempDailyRemindersEnabled: Bool

    init(isPresented: Binding<Bool>, reminderTime: Binding<Date>, dailyRemindersEnabled: Binding<Bool>) {
        _isPresented = isPresented
        _reminderTime = reminderTime
        _dailyRemindersEnabled = dailyRemindersEnabled
        _tempReminderTime = State(initialValue: reminderTime.wrappedValue)
        _tempDailyRemindersEnabled = State(initialValue: dailyRemindersEnabled.wrappedValue)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminders")) {
                    Toggle(isOn: $tempDailyRemindersEnabled) {
                        Label("Daily Reminders", systemImage: "repeat")
                    }

                    if tempDailyRemindersEnabled {
                        DatePicker("Reminder Time", selection: $tempReminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                if tempDailyRemindersEnabled {
                    Section(header: Text("Preview")) {
                        NotificationPreview(reminderTime: tempReminderTime)
                            .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveSettings() {
        reminderTime = tempReminderTime
        dailyRemindersEnabled = tempDailyRemindersEnabled

        NotificationManager.shared.cancelTransactionReminder()
        if dailyRemindersEnabled {
            NotificationManager.shared.scheduleTransactionReminder(at: reminderTime, repeatDaily: true)
        }

        isPresented = false
    }
}

struct NotificationPreview: View {
    let reminderTime: Date

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your daily reminder will arrive at \(reminderTime, formatter: timeFormatter).")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .foregroundColor(bluePurpleColor)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Smartstash")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Don't forget to log your recent transactions!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var sharedDeepLinkHandler = DeepLinkHandler() // ✅ Shared handler

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.applicationIconBadgeNumber = 0 // ✅ Clear badge on app start
        return true
    }

    // Show notification when app is foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound]) // ✅ Removed .badge
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        AppDelegate.sharedDeepLinkHandler.handleNotificationResponse(response)

        // ✅ Clear badge after opening notification
        UIApplication.shared.applicationIconBadgeNumber = 0

        completionHandler()
    }
}


// MARK: - Scene Delegate (if using Scene-based app)
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    let deepLinkHandler = DeepLinkHandler()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // This method is called when the scene is created
    }
}

