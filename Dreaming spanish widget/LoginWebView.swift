//
//  LoginWebView.swift
//  Dreaming spanis widget
//
//  Created by Mohamed Ali on 10/03/2026.
//
//  Embeds the real Dreaming Spanish website in a WKWebView.
//  The user logs in normally; after the progress page loads,
//  JavaScript is injected to scrape progress data and send it back.

import SwiftUI
import WebKit

// MARK: - Coordinator (JS → Swift bridge)

final class WebViewCoordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

    var onProgressReceived: ((ScrapedProgress) -> Void)?
    var onLoginDetected: (() -> Void)?

    // Called when JS posts to window.webkit.messageHandlers.progressData
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }

        if message.name == "progressData" {
            let scraped = ScrapedProgress(
                totalHours: body["totalHours"] as? Double ?? 0,
                todayMinutes: body["todayMinutes"] as? Int ?? (body["todayMinutes"] as? Double).map { Int($0) } ?? 0,
                streakDays: body["streakDays"] as? Int ?? (body["streakDays"] as? Double).map { Int($0) } ?? 0,
                dailyGoalMinutes: body["dailyGoalMinutes"] as? Int ?? (body["dailyGoalMinutes"] as? Double).map { Int($0) } ?? 30,
                dailyGoalProgress: body["dailyGoalProgress"] as? Double ?? 0
            )
            DispatchQueue.main.async { self.onProgressReceived?(scraped) }
        }

        if message.name == "apiData" {
            guard let jsonString = message.body as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let wrapper = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let body = wrapper["body"] as? [String: Any]
            else { return }

            // Only persist URL if this response body actually contains progress data.
            // This ensures we store the right endpoint and not some analytics/config call.
            if ScrapedProgress.parse(from: body) != nil,
               let urlStr = wrapper["url"] as? String, !urlStr.isEmpty {
                let defaults = UserDefaults(suiteName: ProgressStore.appGroupID)
                defaults?.set(urlStr, forKey: AppGroupKeys.apiURL)
                if let headers = wrapper["headers"] as? [String: String], !headers.isEmpty {
                    defaults?.set(headers, forKey: AppGroupKeys.apiHeaders)
                }
            }
            parseAPIResponse(body)
        }
    }

    private func parseAPIResponse(_ json: [String: Any]) {
        // DS API response shape is unknown until you observe real calls.
        // Common patterns — adjust once you see the actual response:
        // { "totalTime": 3060, "streak": 42, "dailyGoal": 30, "todayTime": 15 }
        // { "stats": { "hours": 51.0, "streak": 42 }, "today": { "minutes": 15 } }

        var totalHours: Double = 0
        var todayMinutes: Int = 0
        var streakDays: Int = 0
        var dailyGoalMinutes: Int = 30

        // Try flat structure
        if let t = json["totalTime"] as? Double { totalHours = t / 3600 }
        if let t = json["totalMinutes"] as? Double { totalHours = t / 60 }
        if let h = json["totalHours"] as? Double { totalHours = h }
        if let s = json["streak"] as? Int { streakDays = s }
        if let g = json["dailyGoal"] as? Int { dailyGoalMinutes = g }
        if let m = json["todayTime"] as? Int { todayMinutes = m / 60 }
        if let m = json["todayMinutes"] as? Int { todayMinutes = m }

        // Try nested structure
        if let stats = json["stats"] as? [String: Any] {
            if let h = stats["hours"] as? Double { totalHours = h }
            if let s = stats["streak"] as? Int { streakDays = s }
        }
        if let today = json["today"] as? [String: Any] {
            if let m = today["minutes"] as? Int { todayMinutes = m }
        }

        guard totalHours > 0 || todayMinutes > 0 || streakDays > 0 else { return }

        let progress = ScrapedProgress(
            totalHours: totalHours,
            todayMinutes: todayMinutes,
            streakDays: streakDays,
            dailyGoalMinutes: dailyGoalMinutes,
            dailyGoalProgress: dailyGoalMinutes > 0 ? min(Double(todayMinutes) / Double(dailyGoalMinutes), 1.0) : 0
        )
        DispatchQueue.main.async { self.onProgressReceived?(progress) }
    }

    // MARK: - Navigation delegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        if url.contains("app.dreaming.com/spanish/progress") ||
           url.contains("dreaming.com/spanish/progress") {
            onLoginDetected?()
            // Wait for React to hydrate before injecting the DOM scraper
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak webView] in
                webView?.evaluateJavaScript(Self.domScraperJS) { _, _ in }
            }
        }
    }

    // MARK: - JavaScript

    // Injected ONCE at document start (before any page script runs).
    // Intercepts ALL JSON responses from both fetch and XHR — the Swift side
    // decides which responses contain useful progress data by running ScrapedProgress.parse().
    static let fetchInterceptorJS = """
    (function() {
        if (window.__dsInterceptorInstalled) return;
        window.__dsInterceptorInstalled = true;

        function postJSON(urlStr, reqHeaders, data) {
            try {
                window.webkit.messageHandlers.apiData.postMessage(
                    JSON.stringify({ url: urlStr, headers: reqHeaders, body: data })
                );
            } catch(e) {}
        }

        // ── fetch interceptor ────────────────────────────────────────────────
        const _origFetch = window.fetch;
        window.fetch = function(url, opts) {
            return _origFetch.apply(this, arguments).then(function(resp) {
                try {
                    const urlStr = (typeof url === 'string') ? url
                                 : (url && url.url ? url.url : String(url));
                    var reqHeaders = {};
                    if (opts && opts.headers) {
                        try {
                            if (opts.headers instanceof Headers) {
                                opts.headers.forEach(function(v, k) { reqHeaders[k] = v; });
                            } else {
                                reqHeaders = Object.assign({}, opts.headers);
                            }
                        } catch(e) {}
                    }
                    resp.clone().json().then(function(data) {
                        postJSON(urlStr, reqHeaders, data);
                    }).catch(function(){});
                } catch(e) {}
                return resp;
            });
        };

        // ── XMLHttpRequest interceptor ────────────────────────────────────────
        const _origOpen        = XMLHttpRequest.prototype.open;
        const _origSetHeader   = XMLHttpRequest.prototype.setRequestHeader;
        const _origSend        = XMLHttpRequest.prototype.send;

        XMLHttpRequest.prototype.open = function(method, url) {
            this.__xhrUrl     = (typeof url === 'string') ? url : String(url);
            this.__xhrHeaders = {};
            return _origOpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.setRequestHeader = function(k, v) {
            if (this.__xhrHeaders) { this.__xhrHeaders[k] = v; }
            return _origSetHeader.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function() {
            this.addEventListener('load', function() {
                try {
                    const ct = this.getResponseHeader('content-type') || '';
                    if (ct.includes('json') || ct.includes('javascript')) {
                        const data = JSON.parse(this.responseText);
                        postJSON(this.__xhrUrl || '', this.__xhrHeaders || {}, data);
                    }
                } catch(e) {}
            });
            return _origSend.apply(this, arguments);
        };
    })();
    """

    // Injected after React has rendered — scrapes visible DOM elements.
    // Selectors derived from actual DS page class names observed in production.
    static let domScraperJS = """
    (function() {
        function textOf(el) { return el ? (el.innerText || el.textContent || '').trim() : ''; }

        var totalHours = 0;
        var todayMinutes = 0;
        var streakDays = 0;
        var dailyGoalMinutes = 30;
        var dailyGoalProgress = 0;

        // --- Today's minutes + daily goal ---
        // ds-top-navbar-mobile__progress-goal contains e.g. "68/120 min"
        var goalEl = document.querySelector('.ds-top-navbar-mobile__progress-goal');
        if (goalEl) {
            var m = textOf(goalEl).match(/(\\d+)\\/(\\d+)/);
            if (m) {
                todayMinutes = parseInt(m[1]);
                dailyGoalMinutes = parseInt(m[2]);
                dailyGoalProgress = Math.min(todayMinutes / dailyGoalMinutes, 1.0);
            }
        }

        // --- Total hours ---
        // ds-overall-progression-card__info-label elements are:
        //   [0] "Level N"  [1] "<user_hours> hrs"  [2] "level start hrs"  [3] "level end hrs"
        // We pick the first element that contains "hrs" — that's the user's accumulated total.
        var infoLabels = document.querySelectorAll('.ds-overall-progression-card__info-label');
        for (var i = 0; i < infoLabels.length; i++) {
            var t = textOf(infoLabels[i]);
            if (t.includes('hrs') || t.includes('hr')) {
                var n = parseFloat(t.replace(/,/g, '').match(/[\\d.]+/) || ['0'][0]);
                if (n > 0) { totalHours = n; break; }
            }
        }

        // --- Streak (weeks) ---
        // DS shows streak as "X weeks strong" in notification messages.
        // Extract from the first notification that matches the pattern.
        var msgs = document.querySelectorAll('.ds-notifications-menu-item__message');
        for (var j = 0; j < msgs.length; j++) {
            var mt = textOf(msgs[j]);
            var wm = mt.match(/(\\d+)\\s+weeks?\\s+strong/i);
            if (wm) { streakDays = parseInt(wm[1]); break; }
        }

        window.webkit.messageHandlers.progressData.postMessage({
            totalHours: totalHours,
            todayMinutes: todayMinutes,
            streakDays: streakDays,
            dailyGoalMinutes: dailyGoalMinutes,
            dailyGoalProgress: dailyGoalProgress
        });
    })();
    """
}

// MARK: - SwiftUI View

struct LoginWebView: UIViewRepresentable {
    let store: ProgressStore
    @Binding var isPresented: Bool

    func makeCoordinator() -> WebViewCoordinator {
        let coord = WebViewCoordinator()
        coord.onProgressReceived = { [store] scraped in
            store.updateFromScrape(scraped)
            // Persist cookies so the widget extension can make auth'd requests directly
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let relevant = cookies.filter { $0.domain.contains("dreaming.com") }
                let header = HTTPCookie.requestHeaderFields(with: relevant)["Cookie"] ?? ""
                UserDefaults(suiteName: ProgressStore.appGroupID)?
                    .set(header, forKey: AppGroupKeys.cookieHeader)
            }
        }
        coord.onLoginDetected = { [self] in
            // Keep sheet open so user can see the page loaded;
            // they can dismiss manually once data is synced
        }
        return coord
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = config.userContentController

        // Register message handlers
        contentController.add(context.coordinator, name: "progressData")
        contentController.add(context.coordinator, name: "apiData")

        // Inject fetch interceptor at document start (runs before any page JS)
        let interceptScript = WKUserScript(
            source: WebViewCoordinator.fetchInterceptorJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(interceptScript)

        // Use persistent data store so DS login session survives app restarts
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        let url = URL(string: "https://app.dreaming.com/spanish/progress")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
