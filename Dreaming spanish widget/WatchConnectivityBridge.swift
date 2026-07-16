// WatchConnectivityBridge.swift
// Sends ProgressData to the paired Apple Watch whenever the iOS app saves new data.

import Foundation
import WatchConnectivity

final class WatchConnectivityBridge: NSObject {
    static let shared = WatchConnectivityBridge()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call this every time ProgressData is saved on the iPhone.
    func sendToWatch(_ data: ProgressData) {
        guard WCSession.isSupported(), let payload = Self.payload(for: data) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("[WCBridge] Session not activated yet, skipping send")
            return
        }

        // updateApplicationContext persists and delivers even when watch is not reachable
        do {
            try session.updateApplicationContext(payload)
            print("[WCBridge] Sent applicationContext to watch")
        } catch {
            print("[WCBridge] updateApplicationContext failed: \(error)")
        }

        // If watch is reachable right now, also push immediately
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("[WCBridge] sendMessage failed: \(error)")
            }
        }
    }

    /// Builds the WatchConnectivity payload for a given ProgressData.
    static func payload(for data: ProgressData) -> [String: Any]? {
        let watch = WatchProgressData(
            totalHours: data.totalHours,
            todayMinutes: data.todayMinutes,
            streakDays: data.streakDays,
            dailyGoalMinutes: data.dailyGoalMinutes,
            outsideMinutesToday: data.outsideMinutesToday,
            hoursThisMonth: data.hoursThisMonth,
            lastUpdated: data.lastUpdated,
            isLoggedIn: data.isLoggedIn
        )
        guard let encoded = try? JSONEncoder().encode(watch) else { return nil }
        return ["watchProgressData": encoded]
    }

    /// Latest saved data from the App Group, as a payload.
    private func currentPayload() -> [String: Any]? {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let raw = defaults.data(forKey: AppGroupKeys.progressData),
            let data = try? JSONDecoder().decode(ProgressData.self, from: raw)
        else { return nil }
        return Self.payload(for: data)
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Push the latest saved data as soon as the session is ready — covers
        // saves that were skipped while the session was still activating.
        if activationState == .activated, let payload = currentPayload() {
            try? session.updateApplicationContext(payload)
            print("[WCBridge] Re-sent applicationContext on activation")
        }
    }

    // Watch-initiated pull: reply with the latest saved data. This wakes the
    // iPhone app in the background, so it works even if the app isn't open.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message["request"] as? String == "sync" {
            replyHandler(currentPayload() ?? [:])
        } else {
            replyHandler([:])
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
