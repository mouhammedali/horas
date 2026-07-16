// WatchContentView.swift
// Main Apple Watch UI — progress ring, today's minutes, streak, monthly hours.

import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var store: WatchProgressStore

    private var data: WatchProgressData { store.data }
    private let blue = Color(red: 0.29, green: 0.50, blue: 0.96)
    private let gold = Color(red: 1.0,  green: 0.85, blue: 0.2)
    private var ringColor: Color { data.goalReached ? gold : blue }

    var body: some View {
        TabView {
            progressTab
            statsTab
        }
        .tabViewStyle(.verticalPage)
        .task { store.requestSync() }
    }

    // MARK: Tab 1 — Progress ring
    private var progressTab: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 10)

            // Progress arc
            Circle()
                .trim(from: 0, to: data.totalTodayProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: data.totalTodayProgress)

            VStack(spacing: 2) {
                Text("🇪🇸")
                    .font(.title3)
                Text("\(data.totalTodayMinutes)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ringColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.5), value: data.totalTodayMinutes)
                Text("/ \(data.dailyGoalMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Tab 2 — Stats
    private var statsTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            statRow(icon: "flame.fill",  color: .orange,
                    label: "Streak",  value: "\(data.streakDays) wks")
            Divider()
            statRow(icon: "clock.fill", color: .blue,
                    label: "Total",   value: String(format: "%.0f hrs", data.totalHours))
            if let m = data.hoursThisMonth {
                Divider()
                statRow(icon: "calendar", color: .cyan,
                        label: "Month",  value: String(format: "%.1f hrs", m))
            }
        }
        .padding(.horizontal, 4)
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject({
            let s = WatchProgressStore()
            s.data = WatchProgressData(
                totalHours: 538, todayMinutes: 68, streakDays: 78,
                dailyGoalMinutes: 120, outsideMinutesToday: 0,
                hoursThisMonth: 51.3, lastUpdated: Date(), isLoggedIn: true
            )
            return s
        }())
}
