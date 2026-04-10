// WatchProgressStore.swift
// Receives ProgressData from the iPhone via WatchConnectivity and persists it locally.

import Foundation
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchProgressStore: NSObject, ObservableObject {
    @Published var data: WatchProgressData = .placeholder

    private let defaults = UserDefaults(suiteName: WatchProgressData.groupID) ?? .standard

    override init() {
        super.init()
        load()
        activateSession()
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func load() {
        guard
            let raw = defaults.data(forKey: WatchProgressData.localDefaultsKey),
            let decoded = try? JSONDecoder().decode(WatchProgressData.self, from: raw)
        else { return }
        data = decoded
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: WatchProgressData.localDefaultsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleReceived(_ payload: [String: Any]) {
        guard
            let raw = payload["watchProgressData"] as? Data,
            let decoded = try? JSONDecoder().decode(WatchProgressData.self, from: raw)
        else { return }
        Task { @MainActor in
            self.data = decoded
            self.save()
        }
    }
}

extension WatchProgressStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // On activation, read the latest application context in case data arrived while inactive
        if activationState == .activated {
            let ctx = session.receivedApplicationContext
            if !ctx.isEmpty {
                Task { @MainActor in self.handleReceived(ctx) }
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.handleReceived(applicationContext) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in self.handleReceived(message) }
    }
}
