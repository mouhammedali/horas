# Dreaming Spanish Progress Widget

An iOS home screen widget that shows your daily immersion progress from [Dreaming Spanish](https://www.dreaming.com/spanish).

![Small, Medium, and Large widget sizes showing progress ring, stats, and streak]

## Features

- **Three widget sizes** — small (ring + sync), medium (ring + stats), large (ring + full stats grid)
- **Live progress ring** — coral → blue gradient matching the DS brand, gold on goal completion
- **In-widget refresh** — iOS 17+ interactive button refreshes data without opening the app
- **Background sync** — widget fetches your latest progress directly via saved session cookies
- **Auto-sync on return** — progress updates automatically when you return to the app after watching
- **Track Time button** — open the DS website directly from the app to watch content and log time
- **Streak & total hours** — key stats displayed alongside today's progress

## Requirements

- Xcode 16+
- iOS 17+
- A [Dreaming Spanish](https://www.dreaming.com/spanish) account

## Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/your-username/dreaming-spanish-widget.git
   ```

2. **Open in Xcode**
   ```
   open "Dreaming spanis widget.xcodeproj"
   ```

3. **Set your own Bundle ID and App Group**
   - In the project navigator, select the project → Signing & Capabilities
   - Change the bundle identifier for both targets to your own (e.g. `com.yourname.dswidget`)
   - Update the App Group identifier in both targets to match (e.g. `group.com.yourname.dswidget`)
   - Update `ProgressStore.appGroupID` in `ProgressStore.swift` to match your App Group

4. **Set your Development Team**
   - In Build Settings, set `DEVELOPMENT_TEAM` to your Apple Developer team ID

5. **Run on device** (widgets require a real device)

## Architecture

```
Main App Target                    Widget Extension
─────────────────                  ────────────────────────
ContentView                        DreamingWidget
  └─ DashboardView                   └─ ProgressTimelineProvider
  └─ DSWebViewSheet                      └─ WidgetEntryView
       └─ LoginWebView (WKWebView)            └─ SmallWidgetView
            └─ fetchInterceptorJS              └─ MediumWidgetView
            └─ domScraperJS                    └─ LargeWidgetView
                                                    └─ RefreshProgressIntent
              ┌──── App Group UserDefaults ────┐
              │  progressData (ProgressData)   │
              │  dsCookieHeader                │
              │  dsProgressAPIURL              │
              │  syncRequested / syncFailed    │
              └────────────────────────────────┘
```

### How the JS interceptor works

When you open the DS website in the in-app webview, two JavaScript scripts are injected:

1. **`fetchInterceptorJS`** (injected at document start) — wraps both `window.fetch` and `XMLHttpRequest` to capture every JSON response. Any response that `ScrapedProgress.parse()` can decode as progress data causes the API URL and session cookies to be saved to the shared App Group.

2. **`domScraperJS`** (injected after page load) — scrapes visible DOM elements (progress bar, total hours, streak) as a fallback.

Once the API URL and cookies are saved, the widget extension can call that endpoint directly via `URLSession` — no app launch needed.

### In-widget refresh (iOS 17+)

The refresh button uses `AppIntent` with `openAppWhenRun = false`. When tapped:
1. Sets a `syncRequested` timestamp in the App Group
2. Calls `directFetch()` — a direct `URLSession` request using saved cookies
3. On HTTP 401/403, sets `syncFailed = true` → widget shows "Session expired" banner with a link to re-login
4. On success, saves updated `ProgressData` and reloads all widget timelines

## Debugging

To inspect what API endpoints DS uses:

1. Run the app on a simulator or device with your Mac
2. In Safari, open **Develop → [your device] → [the webview]**
3. Go to the Network tab, then navigate to the DS progress page in the app
4. Look for XHR/fetch calls returning JSON with fields like `totalTime`, `streak`, `dailyGoal`

The `fetchInterceptorJS` already captures all JSON — `ScrapedProgress.parse()` in `ProgressData.swift` handles the various response shapes DS might return.

## Contributing

Pull requests welcome. Please keep changes focused and test on a real device (widgets don't work in the simulator).

## License

MIT — see [LICENSE](LICENSE).
