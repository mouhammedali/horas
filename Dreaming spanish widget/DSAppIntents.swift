//
//  DSAppIntents.swift
//  Dreaming spanis widget
//
//  App Shortcuts — surfaces "Add Hours" in the Shortcuts app so it can be
//  assigned to the iPhone Action Button (Settings → Action Button → Shortcut).
//

import AppIntents

extension Notification.Name {
    static let openAddHours = Notification.Name("DSOpenAddHours")
}

// MARK: - Add Hours Intent

struct AddHoursIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Hours"
    static let description = IntentDescription("Open Dreaming Spanish to log immersion hours")

    // Opens the app before perform() runs
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Notification: instant delivery when app is already running / in foreground
        NotificationCenter.default.post(name: .openAddHours, object: nil)
        // UserDefaults flag: fallback for cold launch where UI may not be ready yet
        UserDefaults(suiteName: AppGroupKeys.appGroupID)?
            .set(true, forKey: AppGroupKeys.openAddHoursOnLaunch)
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct DSAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddHoursIntent(),
            phrases: [
                "Add hours to \(.applicationName)",
                "Log \(.applicationName) hours",
                "Open \(.applicationName) tracker"
            ],
            shortTitle: "Add Hours",
            systemImageName: "play.circle.fill"
        )
    }
}
