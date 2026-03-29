//
//  DreamingWidget.swift
//  DreamingWidget
//
//  Created by Mohamed Ali on 10/03/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Refresh Intent (iOS 17+)

private let sharedGroupID    = AppGroupKeys.appGroupID


// MARK: - Timeline Entry

struct ProgressEntry: TimelineEntry {
    let date: Date
    let data: ProgressData
    var isSyncing: Bool = false
    var syncFailed: Bool = false
}

// MARK: - Timeline Provider

struct ProgressTimelineProvider: TimelineProvider {
    private static let appGroupID = AppGroupKeys.appGroupID
    private static let dataKey = AppGroupKeys.progressData

    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        completion(ProgressEntry(date: Date(), data: load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let data = load() ?? .placeholder

        let syncDate  = defaults?.object(forKey: AppGroupKeys.syncRequested) as? Date
        let isSyncing = syncDate.map { Date().timeIntervalSince($0) < 90 } ?? false
        let syncFailed = defaults?.bool(forKey: AppGroupKeys.syncFailed) ?? false

        let entry = ProgressEntry(date: Date(), data: data, isSyncing: isSyncing, syncFailed: syncFailed)

        let waitMinutes = isSyncing ? 1 : 30
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: waitMinutes, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func load() -> ProgressData? {
        guard
            let defaults = UserDefaults(suiteName: Self.appGroupID),
            let raw = defaults.data(forKey: Self.dataKey),
            let decoded = try? JSONDecoder().decode(ProgressData.self, from: raw)
        else { return nil }
        return decoded
    }
}

// MARK: - Shared Helpers

extension ProgressData {
    var ringColor: Color {
        switch totalTodayProgress {
        case 1...:  return Color(red: 1.0, green: 0.85, blue: 0.2)   // gold
        case 0.66...: return Color(red: 0.2, green: 0.9,  blue: 0.5)  // green
        case 0.33...: return Color(red: 0.3, green: 0.75, blue: 1.0)  // blue
        default:    return Color(red: 0.5, green: 0.65, blue: 1.0)    // soft blue
        }
    }

    var syncedLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(lastUpdated) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: lastUpdated)
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: lastUpdated)
    }
}

private let bgColor = Color(red: 0.07, green: 0.09, blue: 0.14)
private let surfaceColor = Color(red: 0.12, green: 0.14, blue: 0.22)

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    let size: CGFloat
    let todayMinutes: Int
    let goalMinutes: Int

    // DS brand colors — bright enough to contrast on dark bg
    // coral #E86247 (vivid salmon) → bright blue #4B80F5
    private var gradientColors: [Color] {
        let coral = Color(red: 0.91, green: 0.38, blue: 0.28)  // vivid DS coral
        let blue  = Color(red: 0.29, green: 0.50, blue: 0.96)  // bright DS blue
        if progress >= 1 {
            return [
                Color(red: 1.0, green: 0.80, blue: 0.15),      // gold shimmer
                coral,
                blue,
            ]
        } else {
            return [coral, blue]
        }
    }

    var body: some View {
        ZStack {
            // Track with subtle glow
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            // Glowing shadow under the arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color.opacity(0.25),
                    style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
            // Main gradient arc
            Circle()
                .trim(from: 0, to: max(progress, 0.01))
                .stroke(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            // Center label
            VStack(spacing: 1) {
                Text("\(todayMinutes)")
                    .font(.system(size: size * 0.27, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text("/ \(goalMinutes)m")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Spanish Flag Badge

struct SpanishFlagBadge: View {
    let size: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Color(red: 0.75, green: 0.09, blue: 0.13)   // Spanish red
                .frame(height: size * 0.25)
            Color(red: 0.96, green: 0.76, blue: 0.17)   // Spanish yellow
                .frame(height: size * 0.50)
            Color(red: 0.75, green: 0.09, blue: 0.13)
                .frame(height: size * 0.25)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Entry View Router

struct WidgetEntryView: View {
    let entry: ProgressEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium: MediumWidgetView(data: entry.data, isSyncing: entry.isSyncing, syncFailed: entry.syncFailed)
            case .systemLarge:  LargeWidgetView(data: entry.data, isSyncing: entry.isSyncing, syncFailed: entry.syncFailed)
            default:            SmallWidgetView(data: entry.data, isSyncing: entry.isSyncing, syncFailed: entry.syncFailed)
            }
        }
        // Drive contentTransition(.numericText()) animations on every timeline entry swap
        .animation(.spring(duration: 0.5), value: entry.data.totalTodayMinutes)
        .animation(.spring(duration: 0.5), value: entry.data.streakDays)
        .animation(.spring(duration: 0.5), value: entry.data.totalHours)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let data: ProgressData
    var isSyncing: Bool = false
    var syncFailed: Bool = false

    var body: some View {
        if syncFailed && !isSyncing {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2).foregroundStyle(.orange)
                Text("Session expired\nOpen app to re-login")
                    .font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) { bgColor }
            .widgetURL(URL(string: "dswidget://relogin"))
        } else if !data.isLoggedIn {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.title2).foregroundStyle(.orange)
                Text("Open app\nto log in")
                    .font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) { bgColor }
            .widgetURL(URL(string: "dswidget://login"))
        } else {
            ZStack(alignment: .bottom) {
                // Ring centered in the upper portion — clear of the bottom strip
                ProgressRing(
                    progress: data.totalTodayProgress,
                    lineWidth: 8, color: data.ringColor, size: 76,
                    todayMinutes: data.totalTodayMinutes,
                    goalMinutes: data.dailyGoalMinutes
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 52)
                .padding(.top, 24)// reserve space so ring never overlaps strip

                // Bottom strip — absolutely pinned to the bottom edge
                HStack {
                    Text(isSyncing ? "Syncing…" : data.syncedLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer()
                    Link(destination: URL(string: "dswidget://refresh")!) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(data.ringColor)
                    }
                    Link(destination: URL(string: "dswidget://addhours")!) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(data.ringColor)
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isSyncing ? 0.7 : 1.0)
            .overlay(alignment: .topLeading) {
                SpanishFlagBadge(size: 20)
                    .padding(.top, 6)
                    .padding(.leading, -4)
            }
            .containerBackground(for: .widget) { bgColor }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let data: ProgressData
    var isSyncing: Bool = false
    var syncFailed: Bool = false

    var body: some View {
        if syncFailed && !isSyncing {
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session expired").font(.headline).foregroundStyle(.white)
                    Text("Open app to re-login")
                        .font(.caption).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding()
            .containerBackground(for: .widget) { bgColor }
            .widgetURL(URL(string: "dswidget://relogin"))
        } else if !data.isLoggedIn {
            HStack(spacing: 16) {
                Image(systemName: "safari.fill").font(.largeTitle).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dreaming Spanish").font(.headline).foregroundStyle(.white)
                    Text("Open app to connect your account")
                        .font(.caption).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding()
            .containerBackground(for: .widget) { bgColor }
            .widgetURL(URL(string: "dswidget://login"))
        } else {
            HStack(spacing: 14) {
                ProgressRing(
                    progress: data.totalTodayProgress,
                    lineWidth: 11, color: data.ringColor, size: 106,
                    todayMinutes: data.totalTodayMinutes,
                    goalMinutes: data.dailyGoalMinutes
                )

                VStack(alignment: .leading, spacing: 0) {
                    // Top row: goal status + refresh
                    HStack(alignment: .center) {
                        if data.totalTodayProgress >= 1 {
                            Label("Goal reached!", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.yellow)
                        } else {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(Int(data.totalTodayProgress * 100))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(data.ringColor)
                                    .contentTransition(.numericText())
                                Text("of daily goal")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                        Spacer()
                        Link(destination: URL(string: "dswidget://refresh")!) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(data.ringColor.opacity(0.85))
                        }
                        Link(destination: URL(string: "dswidget://addhours")!) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(data.ringColor.opacity(0.85))
                        }
                    }

                    Spacer(minLength: 6)

                    // Stats
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 14) {
                            StatPill(icon: "flame.fill",  color: .orange, value: "\(data.streakDays)", unit: "wks")
                            StatPill(icon: "clock.fill",  color: Color(red: 0.29, green: 0.50, blue: 0.96),
                                     value: String(format: "%.0f", data.totalHours), unit: "hrs total")
                        }
                        if data.outsideMinutesToday > 0 {
                            StatPill(icon: "plus.circle.fill", color: data.ringColor,
                                     value: "+\(data.outsideMinutesToday)", unit: "min outside DS")
                        }
                    }

                    Spacer(minLength: 6)

                    // Last synced
                    HStack(spacing: 3) {
                        Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "clock.arrow.circlepath")
                            .font(.system(size: 9))
                        Text(isSyncing ? "Syncing…" : "Synced \(data.syncedLabel)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(isSyncing ? .white.opacity(0.5) : .white.opacity(0.35))
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 14)
            .opacity(isSyncing ? 0.75 : 1.0)
            .overlay(alignment: .topLeading) {
                SpanishFlagBadge(size: 18)
                    .padding(.top, 4)
            }
            .containerBackground(for: .widget) { bgColor }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let data: ProgressData
    var isSyncing: Bool = false
    var syncFailed: Bool = false

    private var remainingMinutes: Int {
        max(data.dailyGoalMinutes - data.totalTodayMinutes, 0)
    }

    var body: some View {
        if syncFailed && !isSyncing {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48)).foregroundStyle(.orange)
                Text("Session expired").font(.title2.bold()).foregroundStyle(.white)
                Text("Open the app to re-login to Dreaming Spanish")
                    .font(.callout).foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .containerBackground(for: .widget) { bgColor }
            .widgetURL(URL(string: "dswidget://relogin"))
        } else if !data.isLoggedIn {
            VStack(spacing: 12) {
                Image(systemName: "safari.fill").font(.system(size: 48)).foregroundStyle(.green)
                Text("Dreaming Spanish").font(.title2.bold()).foregroundStyle(.white)
                Text("Open the app to connect your account")
                    .font(.callout).foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .containerBackground(for: .widget) { bgColor }
            .widgetURL(URL(string: "dswidget://login"))
        } else {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if data.totalTodayProgress >= 1 {
                            Label("Goal reached!", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.yellow)
                        } else {
                            Text("Daily Goal")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Link(destination: URL(string: "dswidget://refresh")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Sync")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(data.ringColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(data.ringColor.opacity(0.1), in: Capsule())
                        }
                        Link(destination: URL(string: "dswidget://addhours")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Add Hours")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(data.ringColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(data.ringColor.opacity(0.1), in: Capsule())
                        }
                    }
                }

                // Large ring
                ProgressRing(
                    progress: data.totalTodayProgress,
                    lineWidth: 14, color: data.ringColor, size: 160,
                    todayMinutes: data.totalTodayMinutes,
                    goalMinutes: data.dailyGoalMinutes
                )

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatCard(icon: "flame.fill",      color: .orange,     value: "\(data.streakDays) wks",            label: "Streak")
                    StatCard(icon: "clock.fill",       color: .blue,       value: String(format: "%.0f hrs", data.totalHours), label: "Total hours")
                    StatCard(icon: "timer",            color: data.ringColor,
                             value: remainingMinutes == 0 ? "Done!" : "\(remainingMinutes) min",
                             label: remainingMinutes == 0 ? "Completed" : "Remaining")
                    if data.outsideMinutesToday > 0 {
                        StatCard(icon: "plus.circle.fill", color: .teal, value: "+\(data.outsideMinutesToday) min", label: "Outside DS")
                    } else {
                        StatCard(icon: "target", color: .purple,
                                 value: "\(Int(data.totalTodayProgress * 100))%",
                                 label: "Progress")
                    }
                }

                // Last synced footer
                HStack(spacing: 4) {
                    Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "clock.arrow.circlepath")
                        .font(.system(size: 10))
                    Text(isSyncing ? "Syncing…" : "Last synced: \(data.syncedLabel)")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .overlay(alignment: .topLeading) {
                SpanishFlagBadge(size: 18)
                    .padding(.top, 4)
            }
            .containerBackground(for: .widget) { bgColor }
        }
    }
}

// MARK: - Stat Card (Large widget)

struct StatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(surfaceColor, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Lock Screen Widget Views

struct LockScreenCircularView: View {
    let entry: ProgressEntry

    var body: some View {
        let data     = entry.data
        let progress = min(data.totalTodayProgress, 1.0)
        let isGoal   = data.totalTodayProgress >= 1

        ZStack {
            // Track — dimmed full circle (like Fitness inactive ring)
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: 8)

            // Progress arc — closed ring starting at 12 o'clock, Fitness style
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isGoal
                        ? Color(red: 1.0, green: 0.85, blue: 0.2)
                        : Color(red: 0.29, green: 0.50, blue: 0.96),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()

            // Center label — minutes + unit, same layout as Fitness (e.g. "523 CAL")
            if data.isLoggedIn {
                VStack(spacing: -1) {
                    Text("🇪🇸")
                        .font(.system(size: 8))
                    Text("\(data.totalTodayMinutes)")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text("MIN")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "figure.walk")
                    .font(.callout)
                    .widgetAccentable()
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "dswidget://addhours"))
    }
}

struct LockScreenRectangularView: View {
    let entry: ProgressEntry

    var body: some View {
        let data     = entry.data
        let progress = min(data.totalTodayProgress, 1.0)
        let isGoal   = data.totalTodayProgress >= 1
        let tint     = isGoal
            ? Color(red: 1.0, green: 0.85, blue: 0.2)
            : Color(red: 0.29, green: 0.50, blue: 0.96)

        if !data.isLoggedIn {
            Label("Open app to connect", systemImage: "figure.walk")
                .font(.caption)
                .widgetAccentable()
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "dswidget://login"))
        } else {
            // Fitness rectangular style: small ring left, primary metric + secondary stats right
            HStack(spacing: 10) {
                // Closed ring — same style as circular widget, scaled down
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.25), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()
                    Text(isGoal ? "✓" : "\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .widgetAccentable()
                        .minimumScaleFactor(0.5)
                }
                .frame(width: 44, height: 44)

                // Right: primary + secondary rows (Fitness layout)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("🇪🇸")
                            .font(.system(size: 11))
                        Text("\(data.totalTodayMinutes)")
                            .font(.system(.callout, design: .rounded, weight: .bold))
                            .widgetAccentable()
                        Text("/ \(data.dailyGoalMinutes) MIN")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Label("\(data.streakDays)wk", systemImage: "flame.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Label("\(Int(data.totalHours))h", systemImage: "clock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "dswidget://addhours"))
        }
    }
}

// MARK: - Widget Declarations

struct DreamingWidget: Widget {
    let kind = "DreamingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dreaming Spanish")
        .description("Daily goal progress for your Spanish immersion.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LockScreenEntryView: View {
    let entry: ProgressEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            LockScreenCircularView(entry: entry)
        }
    }
}

struct DreamingLockScreenWidget: Widget {
    let kind = "DreamingLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressTimelineProvider()) { entry in
            LockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("DS Progress")
        .description("Progress ring and stats on your lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    DreamingLockScreenWidget()
} timeline: {
    ProgressEntry(date: Date(), data: ProgressData(
        totalHours: 505, todayMinutes: 68, streakDays: 75,
        dailyGoalMinutes: 120, dailyGoalProgress: 0.57,
        outsideMinutesToday: 0, lastUpdated: Date(), isLoggedIn: true
    ))
}

#Preview(as: .accessoryRectangular) {
    DreamingLockScreenWidget()
} timeline: {
    ProgressEntry(date: Date(), data: ProgressData(
        totalHours: 505, todayMinutes: 68, streakDays: 75,
        dailyGoalMinutes: 120, dailyGoalProgress: 0.57,
        outsideMinutesToday: 0, lastUpdated: Date(), isLoggedIn: true
    ))
}

// Home screen previews

#Preview(as: .systemSmall) {
    DreamingWidget()
} timeline: {
    ProgressEntry(date: Date(), data: ProgressData(
        totalHours: 505, todayMinutes: 68, streakDays: 75,
        dailyGoalMinutes: 120, dailyGoalProgress: 0.57,
        outsideMinutesToday: 15, lastUpdated: Date(), isLoggedIn: true
    ))
}

#Preview(as: .systemMedium) {
    DreamingWidget()
} timeline: {
    ProgressEntry(date: Date(), data: ProgressData(
        totalHours: 505, todayMinutes: 68, streakDays: 75,
        dailyGoalMinutes: 120, dailyGoalProgress: 0.57,
        outsideMinutesToday: 15, lastUpdated: Date(), isLoggedIn: true
    ))
}

#Preview(as: .systemLarge) {
    DreamingWidget()
} timeline: {
    ProgressEntry(date: Date(), data: ProgressData(
        totalHours: 505, todayMinutes: 68, streakDays: 75,
        dailyGoalMinutes: 120, dailyGoalProgress: 0.57,
        outsideMinutesToday: 15, lastUpdated: Date(), isLoggedIn: true
    ))
}
