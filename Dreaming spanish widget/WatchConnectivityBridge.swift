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
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("[WCBridge] Session not activated yet, skipping send")
            return
        }

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
        guard let encoded = try? JSONEncoder().encode(watch) else { return }
        let payload: [String: Any] = ["watchProgressData": encoded]

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
}

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
