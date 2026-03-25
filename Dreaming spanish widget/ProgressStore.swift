//
//  ProgressStore.swift
//  Dreaming spanis widget
//
//  Created by Mohamed Ali on 10/03/2026.
//
//  Main app target only. Reads/writes progress data to the shared
//  App Group so the widget extension can read it.

import Foundation
import WidgetKit
import WebKit
import UIKit

@MainActor
@Observable
final class ProgressStore {
    static let appGroupID = AppGroupKeys.appGroupID
    private static let dataKey = AppGroupKeys.progressData

    private let defaults: UserDefaults

    var data: ProgressData = .placeholder
    var isSyncing: Bool = false

    private var activeScraper: BackgroundScraper?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        load()
    }

    // MARK: - Persistence

    func load() {
        guard
            let raw = defaults.data(forKey: Self.dataKey),
            let decoded = try? JSONDecoder().decode(ProgressData.self, from: raw)
        else { return }
        data = decoded
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: Self.dataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Updates

    func updateFromScrape(_ scraped: ScrapedProgress) {
        data.totalHours = scraped.totalHours
        data.todayMinutes = scraped.todayMinutes
        data.streakDays = scraped.streakDays
        data.dailyGoalMinutes = scraped.dailyGoalMinutes
        data.dailyGoalProgress = scraped.dailyGoalProgress
        if let l = scraped.currentLevel  { data.currentLevel  = l }
        if let h = scraped.nextLevelHours { data.nextLevelHours = h }
        data.lastUpdated = Date()
        data.isLoggedIn = true
        isSyncing = false
        // Clear any stale failure flag so the widget recovers immediately
        defaults.removeObject(forKey: AppGroupKeys.syncFailed)
        save()
    }

    func addOutsideTime(minutes: Int) {
        guard minutes > 0 else { return }
        if !Calendar.current.isDateInToday(data.lastUpdated) {
            data.outsideMinutesToday = 0
        }
        data.outsideMinutesToday += minutes
        data.lastUpdated = Date()
        save()
    }

    func markLoggedOut() {
        data.isLoggedIn = false
        save()
    }

    // MARK: - Background silent sync (no UI shown)

    func backgroundSync() {
        guard !isSyncing else { return }
        isSyncing = true

        let scraper = BackgroundScraper()
        activeScraper = scraper

        scraper.scrape { [weak self] result in
            guard let self else { return }
            if let result {
                self.updateFromScrape(result)
            } else {
                self.isSyncing = false
            }
            self.activeScraper = nil
        }
    }
}

// MARK: - Off-screen WebView Scraper

/// Loads the DS progress page in an invisible WKWebView and runs the DOM scraper.
/// The webView is added to the key window at position (-2000, -2000) so it's never visible.
@MainActor
final class BackgroundScraper: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((ScrapedProgress?) -> Void)?
    private var done = false

    func scrape(completion: @escaping (ScrapedProgress?) -> Void) {
        self.completion = completion

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // reuse existing login session

        let controller = WKUserContentController()
        controller.add(self, name: "progressData")

        let interceptor = WKUserScript(
            source: WebViewCoordinator.fetchInterceptorJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(interceptor)
        config.userContentController = controller

        // Full-size frame so JS layout queries work, but positioned way off-screen
        let wv = WKWebView(
            frame: CGRect(x: -2000, y: -2000, width: 390, height: 844),
            configuration: config
        )
        wv.navigationDelegate = self
        self.webView = wv

        // Must be in a window for WKWebView to process JS correctly
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.addSubview(wv)
        }

        wv.load(URLRequest(url: URL(string: "https://app.dreaming.com/spanish/progress")!))

        // Timeout safety net — give up after 45 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            self?.finish(nil)
        }
    }

    // JS → Swift: received scraped progress data
    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard !done, message.name == "progressData",
              let body = message.body as? [String: Any] else { return }

        let asInt: (Any?) -> Int = { v in
            (v as? Int) ?? (v as? Double).map { Int($0) } ?? 0
        }
        let result = ScrapedProgress(
            totalHours: body["totalHours"] as? Double ?? 0,
            todayMinutes: asInt(body["todayMinutes"]),
            streakDays: asInt(body["streakDays"]),
            dailyGoalMinutes: max(asInt(body["dailyGoalMinutes"]), 1),
            dailyGoalProgress: body["dailyGoalProgress"] as? Double ?? 0,
            currentLevel: body["currentLevel"] as? String,
            nextLevelHours: body["nextLevelHours"] as? Double
        )
        finish(result)
    }

    // Inject DOM scraper once the progress page has loaded
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        guard url.contains("/spanish/progress") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak webView] in
            webView?.evaluateJavaScript(WebViewCoordinator.domScraperJS) { _, _ in }
        }
    }

    private func finish(_ result: ScrapedProgress?) {
        guard !done else { return }
        done = true
        webView?.removeFromSuperview()
        webView = nil
        completion?(result)
        completion = nil
    }
}
