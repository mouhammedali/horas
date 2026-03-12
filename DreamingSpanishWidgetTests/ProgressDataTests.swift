//
//  ProgressDataTests.swift
//  DreamingSpanishWidgetTests
//
//  Pure-logic tests — no UI, no network, no async required.
//

import XCTest
@testable import Dreaming_spanis_widget

final class ProgressDataTests: XCTestCase {

    // MARK: - ScrapedProgress.parse — flat JSON

    func test_parse_flatJSON_allKeys() {
        let json: [String: Any] = [
            "totalHours": 51.5,
            "streakDays": 42,
            "dailyGoal": 30,
            "todayMinutes": 20
        ]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 51.5)
        XCTAssertEqual(result?.streakDays, 42)
        XCTAssertEqual(result?.dailyGoalMinutes, 30)
        XCTAssertEqual(result?.todayMinutes, 20)
    }

    func test_parse_totalTime_convertsSecondsToHours() {
        let json: [String: Any] = ["totalTime": 7200.0, "streak": 5, "todayMinutes": 10]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 2.0, accuracy: 0.001)
    }

    func test_parse_totalMinutes_convertsToHours() {
        let json: [String: Any] = ["totalMinutes": 120.0, "streak": 5, "todayMinutes": 10]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 2.0, accuracy: 0.001)
    }

    func test_parse_snakeCaseKeys() {
        let json: [String: Any] = [
            "total_hours": 100.0,
            "streak": 10,
            "daily_goal": 45,
            "today_minutes": 15
        ]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 100.0)
        XCTAssertEqual(result?.dailyGoalMinutes, 45)
        XCTAssertEqual(result?.todayMinutes, 15)
    }

    func test_parse_streakDaysKey() {
        let json: [String: Any] = ["totalHours": 10.0, "streakDays": 99, "todayMinutes": 5]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.streakDays, 99)
    }

    // MARK: - ScrapedProgress.parse — nested JSON

    func test_parse_nestedStatsAndToday() {
        let json: [String: Any] = [
            "stats": ["hours": 200.0, "streak": 30],
            "today": ["minutes": 25]
        ]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 200.0)
        XCTAssertEqual(result?.streakDays, 30)
        XCTAssertEqual(result?.todayMinutes, 25)
    }

    func test_parse_nestedUser() {
        let json: [String: Any] = [
            "user": ["totalHours": 75.0, "streak": 12],
            "today": ["minutes": 8]
        ]
        let result = ScrapedProgress.parse(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 75.0)
        XCTAssertEqual(result?.streakDays, 12)
    }

    // MARK: - ScrapedProgress.parse — invalid inputs

    func test_parse_emptyJSON_returnsNil() {
        XCTAssertNil(ScrapedProgress.parse(from: [:]))
    }

    func test_parse_allZeros_returnsNil() {
        let json: [String: Any] = [
            "totalHours": 0.0,
            "streak": 0,
            "todayMinutes": 0
        ]
        XCTAssertNil(ScrapedProgress.parse(from: json))
    }

    func test_parse_unrelatedJSON_returnsNil() {
        let json: [String: Any] = ["error": "not found", "code": 404]
        XCTAssertNil(ScrapedProgress.parse(from: json))
    }

    // MARK: - ProgressData computed properties

    func test_totalTodayMinutes_sumsDSAndOutside() {
        let data = ProgressData(
            totalHours: 0, todayMinutes: 30, streakDays: 0,
            dailyGoalMinutes: 60, dailyGoalProgress: 0,
            outsideMinutesToday: 15, lastUpdated: Date(), isLoggedIn: true
        )
        XCTAssertEqual(data.totalTodayMinutes, 45)
    }

    func test_totalTodayProgress_clampsAt1() {
        let data = ProgressData(
            totalHours: 0, todayMinutes: 90, streakDays: 0,
            dailyGoalMinutes: 60, dailyGoalProgress: 0,
            outsideMinutesToday: 0, lastUpdated: Date(), isLoggedIn: true
        )
        XCTAssertEqual(data.totalTodayProgress, 1.0)
    }

    func test_totalTodayProgress_zeroWhenGoalIsZero() {
        let data = ProgressData(
            totalHours: 0, todayMinutes: 30, streakDays: 0,
            dailyGoalMinutes: 0, dailyGoalProgress: 0,
            outsideMinutesToday: 0, lastUpdated: Date(), isLoggedIn: true
        )
        XCTAssertEqual(data.totalTodayProgress, 0.0)
    }

    func test_totalTodayProgress_partialProgress() {
        let data = ProgressData(
            totalHours: 0, todayMinutes: 15, streakDays: 0,
            dailyGoalMinutes: 60, dailyGoalProgress: 0,
            outsideMinutesToday: 0, lastUpdated: Date(), isLoggedIn: true
        )
        XCTAssertEqual(data.totalTodayProgress, 0.25, accuracy: 0.001)
    }

    func test_totalTodayProgress_includesOutsideMinutes() {
        let data = ProgressData(
            totalHours: 0, todayMinutes: 10, streakDays: 0,
            dailyGoalMinutes: 40, dailyGoalProgress: 0,
            outsideMinutesToday: 10, lastUpdated: Date(), isLoggedIn: true
        )
        // (10 + 10) / 40 = 0.5
        XCTAssertEqual(data.totalTodayProgress, 0.5, accuracy: 0.001)
    }
}
