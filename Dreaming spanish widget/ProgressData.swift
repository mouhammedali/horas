//
//  ProgressData.swift
//  Dreaming spanis widget
//
//  Created by Mohamed Ali on 10/03/2026.
//
//  Shared between the main app target and the widget extension target.

import Foundation

// MARK: - Shared UserDefaults keys (App Group)

enum AppGroupKeys {
    static let appGroupID    = "group.com.mali.stories.DreamingWidget"
    static let progressData  = "progressData"
    static let syncRequested = "syncRequested"
    static let syncFailed    = "syncFailed"
    static let cookieHeader  = "dsCookieHeader"
    static let apiURL               = "dsProgressAPIURL"
    static let apiHeaders           = "dsProgressAPIHeaders"
    static let openAddHoursOnLaunch = "openAddHoursOnLaunch"
}

struct ProgressData: Codable {
    // Scraped from Dreaming Spanish
    var totalHours: Double
    var todayMinutes: Int
    var streakDays: Int
    var dailyGoalMinutes: Int
    var dailyGoalProgress: Double

    // Level progression (optional — nil if not yet scraped)
    var currentLevel: String?
    var nextLevelHours: Double?

    // Monthly hours scraped directly from DS
    var hoursThisMonth: Double?

    // Manually logged outside DS
    var outsideMinutesToday: Int

    // Metadata
    var lastUpdated: Date
    var isLoggedIn: Bool

    // Computed
    var totalTodayMinutes: Int {
        todayMinutes + outsideMinutesToday
    }

    var totalTodayProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(Double(totalTodayMinutes) / Double(dailyGoalMinutes), 1.0)
    }

    var hoursToNextLevel: Double? {
        guard let nextLevelHours, nextLevelHours > 0 else { return nil }
        return max(nextLevelHours - totalHours, 0)
    }

    static var placeholder: ProgressData {
        ProgressData(
            totalHours: 0,
            todayMinutes: 0,
            streakDays: 0,
            dailyGoalMinutes: 30,
            dailyGoalProgress: 0,
            currentLevel: nil,
            nextLevelHours: nil,
            hoursThisMonth: nil,
            outsideMinutesToday: 0,
            lastUpdated: Date(),
            isLoggedIn: false
        )
    }
}

// Transfer object from JS scraper → Swift
struct ScrapedProgress {
    var totalHours: Double
    var todayMinutes: Int
    var streakDays: Int
    var dailyGoalMinutes: Int
    var dailyGoalProgress: Double
    var currentLevel: String? = nil
    var nextLevelHours: Double? = nil
    var hoursThisMonth: Double? = nil

    // Parse a DS API JSON response (same logic as LoginWebView.parseAPIResponse
    // but shared so the widget extension can use it without WKWebView)
    static func parse(from json: [String: Any]) -> ScrapedProgress? {
        var totalHours: Double = 0
        var todayMinutes = 0
        var streakDays = 0
        var dailyGoalMinutes = 30

        // Flat structure variants
        if let t = json["totalTime"]    as? Double { totalHours = t / 3600 }
        if let t = json["totalMinutes"] as? Double { totalHours = t / 60 }
        if let h = json["totalHours"]   as? Double { totalHours = h }
        if let h = json["total_hours"]  as? Double { totalHours = h }
        if let s = json["streak"]       as? Int    { streakDays = s }
        if let s = json["streakDays"]   as? Int    { streakDays = s }
        if let g = json["dailyGoal"]    as? Int    { dailyGoalMinutes = g }
        if let g = json["daily_goal"]   as? Int    { dailyGoalMinutes = g }
        if let m = json["todayTime"]    as? Int    { todayMinutes = m / 60 }
        if let m = json["todayMinutes"] as? Int    { todayMinutes = m }
        if let m = json["today_minutes"]as? Int    { todayMinutes = m }

        // Nested structure variants
        if let stats = json["stats"] as? [String: Any] {
            if let h = stats["hours"]   as? Double { totalHours = h }
            if let s = stats["streak"]  as? Int    { streakDays = s }
        }
        if let today = json["today"] as? [String: Any] {
            if let m = today["minutes"] as? Int    { todayMinutes = m }
        }
        if let user = json["user"] as? [String: Any] {
            if let h = user["totalHours"] as? Double { totalHours = h }
            if let s = user["streak"]     as? Int    { streakDays = s }
        }

        guard totalHours > 0 || todayMinutes > 0 || streakDays > 0 else { return nil }

        // Level data (optional — present in some API shapes)
        var currentLevel: String? = nil
        var nextLevelHours: Double? = nil
        if let l = json["currentLevel"] as? String   { currentLevel = l }
        if let l = json["level"]        as? String   { currentLevel = l }
        if let h = json["nextLevelHours"] as? Double { nextLevelHours = h }
        if let h = json["levelEnd"]       as? Double { nextLevelHours = h }
        if let level = json["level"] as? [String: Any] {
            if let name = level["name"] as? String   { currentLevel = name }
            if let end  = level["endHours"] as? Double { nextLevelHours = end }
        }

        let progress = dailyGoalMinutes > 0
            ? min(Double(todayMinutes) / Double(dailyGoalMinutes), 1.0) : 0
        return ScrapedProgress(
            totalHours: totalHours,
            todayMinutes: todayMinutes,
            streakDays: streakDays,
            dailyGoalMinutes: dailyGoalMinutes,
            dailyGoalProgress: progress,
            currentLevel: currentLevel,
            nextLevelHours: nextLevelHours
        )
    }
}
