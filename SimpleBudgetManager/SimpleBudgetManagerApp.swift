//
//  SimpleBudgetManagerApp.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 11/30/24.
//

import SwiftUI

@main
struct SimpleBudgetManagerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppDelegate.sharedDeepLinkHandler) // ✅ Inject the shared handler
        }
    }
}
