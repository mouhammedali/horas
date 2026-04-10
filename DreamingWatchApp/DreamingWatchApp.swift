// DreamingWatchApp.swift
// Apple Watch app entry point.

import SwiftUI

@main
struct DreamingWatchApp: App {
    @StateObject private var store = WatchProgressStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchContentView()
            }
            .environmentObject(store)
        }
    }
}
