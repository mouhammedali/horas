// DreamingWatchWidget.swift
// WidgetKit complications for watchOS — circular, rectangular, inline, and corner.

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WatchEntry: TimelineEntry {
    let date: Date
    let data: WatchProgressData
}

// MARK: - Timeline Provider

struct WatchProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: Date(), data: loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = WatchEntry(date: Date(), data: loadData())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadData() -> WatchProgressData {
        let defaults = UserDefaults(suiteName: WatchProgressData.groupID) ?? .standard
        guard
            let raw = defaults.data(forKey: WatchProgressData.localDefaultsKey),
            let decoded = try? JSONDecoder().decode(WatchProgressData.self, from: raw)
        else { return .placeholder }
        return decoded
    }
}

// MARK: - Entry View

struct WatchWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WatchEntry

    private let blue = Color(red: 0.29, green: 0.50, blue: 0.96)
    private let gold = Color(red: 1.0,  green: 0.85, blue: 0.2)
    private var ringColor: Color { entry.data.goalReached ? gold : blue }
    private var progress: Double { entry.data.totalTodayProgress }
    private var minutes: Int { entry.data.totalTodayMinutes }
    private var goal: Int { entry.data.dailyGoalMinutes }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    // Circular — filled ring with minutes in center
    private var circularView: some View {
        ProgressView(value: progress) {
            Text("\(minutes)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
        }
        .progressViewStyle(.circular)
    }

    // Rectangular — DS label + progress bar + stats
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Dreaming Spanish")
                .font(.system(.caption2, weight: .semibold))
                .widgetAccentable()
            Gauge(value: progress) {
            } currentValueLabel: {
                Text("\(minutes)/\(goal) min")
                    .font(.system(.caption2, design: .rounded))
            }
            .gaugeStyle(.accessoryLinearCapacity)
            Text("\(entry.data.streakDays)wk streak · \(String(format: "%.0f", entry.data.totalHours))h total")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // Inline — single-line with DS prefix
    private var inlineView: some View {
        Text("DS \(minutes)/\(goal) min · \(entry.data.streakDays)wk")
    }

    // Corner — minutes number with progress arc
    private var cornerView: some View {
        Text("\(minutes)")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .widgetCurvesContent()
            .widgetLabel {
                Gauge(value: progress) {
                    Text("DS min")
                }
                .gaugeStyle(.accessoryLinearCapacity)
            }
    }
}

// MARK: - Widget Definition

struct DreamingWatchWidget: Widget {
    let kind = "DreamingWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProgressProvider()) { entry in
            WatchWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("DS Progress")
        .description("Track your Dreaming Spanish daily goal.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    DreamingWatchWidget()
} timeline: {
    WatchEntry(date: Date(), data: WatchProgressData(
        totalHours: 538, todayMinutes: 68, streakDays: 78,
        dailyGoalMinutes: 120, outsideMinutesToday: 0,
        hoursThisMonth: 51.3, lastUpdated: Date(), isLoggedIn: true
    ))
}

#Preview(as: .accessoryRectangular) {
    DreamingWatchWidget()
} timeline: {
    WatchEntry(date: Date(), data: WatchProgressData(
        totalHours: 538, todayMinutes: 68, streakDays: 78,
        dailyGoalMinutes: 120, outsideMinutesToday: 0,
        hoursThisMonth: 51.3, lastUpdated: Date(), isLoggedIn: true
    ))
}
