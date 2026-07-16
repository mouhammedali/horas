# Horas

A privacy-first iOS and watchOS companion app for [Dreaming Spanish](https://www.dreaming.com/spanish) learners. Your daily input goal, streak, and total hours as widgets on the home screen, lock screen, and Apple Watch.

Website: [mouhammedali.github.io/horas](https://mouhammedali.github.io/horas/) · [Support](https://mouhammedali.github.io/horas/support/) · [Privacy](https://mouhammedali.github.io/horas/privacy/)

## Features

- **Home screen widgets** in three sizes: progress ring, streak, total hours, and a stats grid
- **Lock screen widgets**: circular and rectangular, in the style of Fitness rings
- **Apple Watch app** with Smart Stack widgets and watch face complications
- **Live progress ring** with a coral to blue gradient that turns gold when you hit your goal
- **In-widget sync and add hours**: one tap, without opening the app
- **Outside hours logging** for podcasts, conversations, and other listening
- **Optional iCloud sync** between iPhone and iPad through your personal iCloud
- **No servers, no tracking**: your data stays on your devices

## Requirements

- Xcode 16+
- iOS 17+, watchOS 10+
- A [Dreaming Spanish](https://www.dreaming.com/spanish) account

## Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/mouhammedali/horas.git
   ```

2. **Open in Xcode**
   ```
   open "Dreaming spanish widget.xcodeproj"
   ```

3. **Set your own bundle IDs and App Groups**
   - Select the project, then Signing & Capabilities
   - Change the bundle identifiers on all four targets to your own prefix (app, widget, watch app, watch widget)
   - Update the App Group identifiers on all four targets to match
   - Update `AppGroupKeys.appGroupID` in `ProgressData.swift` and `WatchProgressData.groupID` in `WatchProgressData.swift`

4. **Set your Development Team** on all targets

5. **Run on a real device** (widgets do not work reliably in the simulator)

## Architecture

```
iOS app                            Widget extension
  ContentView                        DreamingWidget
    DashboardView                      ProgressTimelineProvider
    DSWebViewSheet                       WidgetEntryView
      LoginWebView (WKWebView)             Small / Medium / Large views
        fetchInterceptorJS                 Lock screen views
        domScraperJS

Watch app                          Watch widget extension
  WatchContentView                   DreamingWatchWidget
  WatchProgressStore                   circular / rectangular /
  (WatchConnectivity)                  inline / corner views

              App Group UserDefaults (per platform)
                progressData / watchProgressData
                dsCookieHeader, dsProgressAPIURL
                syncRequested, syncFailed
```

Data flows from the iOS app to the widgets through the shared App Group, to the watch through WatchConnectivity, and optionally between the user's own devices through iCloud key-value storage.

### How the JS interceptor works

When you open the Dreaming Spanish website in the in-app webview, two scripts are injected:

1. **`fetchInterceptorJS`** (document start) wraps `window.fetch` and `XMLHttpRequest` to capture every JSON response. Any response that `ScrapedProgress.parse()` can decode as progress data causes the API URL and session cookies to be saved to the App Group.

2. **`domScraperJS`** (after page load) scrapes visible DOM elements (progress bar, total hours, streak) as a fallback.

Once the API URL and cookies are saved, the widget extension calls that endpoint directly via `URLSession`. No app launch needed.

### In-widget refresh (iOS 17+)

The refresh button uses an `AppIntent` with `openAppWhenRun = false`. When tapped it:

1. Sets a `syncRequested` timestamp in the App Group
2. Calls `directFetch()`, a direct `URLSession` request using saved cookies
3. On HTTP 401/403 sets `syncFailed`, and the widget shows a "Session expired" banner linking to re-login
4. On success saves the updated `ProgressData` and reloads all widget timelines

### Watch sync

The iPhone pushes progress to the watch on every save via `updateApplicationContext`, and again whenever the session activates. The watch can also pull: opening the watch app sends a `sync` request message that wakes the iPhone app in the background and returns the latest data.

## Debugging

To inspect which API endpoints Dreaming Spanish uses:

1. Run the app on a device or simulator connected to your Mac
2. In Safari, open Develop, then your device, then the webview
3. In the Network tab, navigate to the DS progress page inside the app
4. Look for XHR/fetch calls returning JSON with fields like `totalTime`, `streak`, `dailyGoal`

`fetchInterceptorJS` already captures all JSON, and `ScrapedProgress.parse()` in `ProgressData.swift` handles the response shapes DS returns.

## Disclaimer

Horas is an independent project and is not affiliated with, endorsed by, or sponsored by Dreaming Spanish.

## Contributing

Pull requests welcome. Please keep changes focused and test on a real device.

## License

MIT. See [LICENSE](LICENSE).
