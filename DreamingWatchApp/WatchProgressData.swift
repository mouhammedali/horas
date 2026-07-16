// WatchProgressData.swift
// Lightweight data model for Watch targets — no UIKit/WebKit dependencies.

import Foundation

struct WatchProgressData: Codable {
    var totalHours: Double
    var todayMinutes: Int
    var streakDays: Int
    var dailyGoalMinutes: Int
    var outsideMinutesToday: Int
    var hoursThisMonth: Double?
    var lastUpdated: Date
    var isLoggedIn: Bool

    var totalTodayMinutes: Int {
        todayMinutes + outsideMinutesToday
    }
    var totalTodayProgress: Double {
        min(Double(totalTodayMinutes) / max(Double(dailyGoalMinutes), 1), 1.0)
    }
    var remainingMinutes: Int {
        max(dailyGoalMinutes - totalTodayMinutes, 0)
    }
    var goalReached: Bool { totalTodayProgress >= 1.0 }

    static let groupID = "group.com.mohamedali.horas.watch"
    static let localDefaultsKey = "watchProgressData"

    static var placeholder: WatchProgressData {
        WatchProgressData(
            totalHours: 0,
            todayMinutes: 0,
            streakDays: 0,
            dailyGoalMinutes: 30,
            outsideMinutesToday: 0,
            hoursThisMonth: nil,
            lastUpdated: Date(),
            isLoggedIn: false
        )
    }

}
