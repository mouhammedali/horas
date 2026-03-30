//
//  ContentView.swift
//  Dreaming spanis widget
//
//  Created by Mohamed Ali on 10/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var store = ProgressStore()
    @State private var showWebView = false
    @State private var backgroundAfterSync = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            if store.data.isLoggedIn {
                DashboardView(store: store, showWebView: $showWebView)
            } else {
                LoginPromptView(showWebView: $showWebView)
            }
        }
        // Cold-start: app launched directly by the widget intent
        .onAppear {
            triggerSyncIfRequested()
            autoSyncIfStale()
            checkAddHoursFlag()
        }
        // Foreground transition: app was already running in background
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                triggerSyncIfRequested()
                autoSyncIfStale()
                checkAddHoursFlag()
            }
        }
        // Add Hours action button / shortcut — works even when app is already in foreground
        .onReceive(NotificationCenter.default.publisher(for: .openAddHours)) { _ in
            showWebView = true
        }
        // When sync finishes and we were opened via the widget refresh button, go to background
        .onChange(of: store.isSyncing) { _, isSyncing in
            guard !isSyncing, backgroundAfterSync else { return }
            backgroundAfterSync = false
            UIApplication.shared.perform(NSSelectorFromString("suspend"))
        }
        // Handle widget deep links
        .onOpenURL { url in
            guard url.scheme == "dswidget" else { return }
            if url.host == "refresh" {
                store.backgroundSync()
                backgroundAfterSync = true
                // Safety timeout — suspend even if sync never completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [self] in
                    guard backgroundAfterSync else { return }
                    backgroundAfterSync = false
                    UIApplication.shared.perform(NSSelectorFromString("suspend"))
                }
            } else {
                // addhours or any other dswidget:// link → open webview
                showWebView = true
                UserDefaults(suiteName: ProgressStore.appGroupID)?
                    .removeObject(forKey: AppGroupKeys.syncFailed)
            }
        }
        .sheet(isPresented: $showWebView, onDismiss: {
            guard store.data.isLoggedIn else { return }
            store.backgroundSync()
        }) {
            DSWebViewSheet(store: store, isPresented: $showWebView)
        }
    }

    private func checkAddHoursFlag() {
        let defaults = UserDefaults(suiteName: ProgressStore.appGroupID)
        guard defaults?.bool(forKey: AppGroupKeys.openAddHoursOnLaunch) == true else { return }
        defaults?.removeObject(forKey: AppGroupKeys.openAddHoursOnLaunch)
        showWebView = true
    }

    private func autoSyncIfStale() {
        guard store.data.isLoggedIn else { return }
        guard Date().timeIntervalSince(store.data.lastUpdated) > 5 * 60 else { return }
        store.backgroundSync()
    }

    private func triggerSyncIfRequested() {
        guard store.data.isLoggedIn else { return }
        let defaults = UserDefaults(suiteName: ProgressStore.appGroupID)
        // Clear stale syncFailed whenever app is active and user is logged in
        defaults?.removeObject(forKey: AppGroupKeys.syncFailed)
        guard
            let requested = defaults?.object(forKey: AppGroupKeys.syncRequested) as? Date,
            Date().timeIntervalSince(requested) < 120
        else { return }
        defaults?.removeObject(forKey: AppGroupKeys.syncRequested)
        // Silent background scrape — no sheet, no user interaction needed
        store.backgroundSync()
    }
}

// MARK: - WebView sheet wrapper (login + track time)

struct DSWebViewSheet: View {
    let store: ProgressStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            LoginWebView(store: store, isPresented: $isPresented)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Dreaming Spanish")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }
}

// MARK: - Login prompt

struct LoginPromptView: View {
    @Binding var showWebView: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            VStack(spacing: 8) {
                Text("Dreaming Spanish")
                    .font(.title.bold())
                Text("Connect once to sync your daily progress to the home screen widget.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showWebView = true
            } label: {
                Label("Log In to Dreaming Spanish", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .navigationTitle("DS Progress Widget")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    let store: ProgressStore
    @Binding var showWebView: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var data: ProgressData { store.data }
    private let blue = Color(red: 0.29, green: 0.50, blue: 0.96)
    private let gold = Color(red: 1.0,  green: 0.85, blue: 0.2)
    private var ringColor: Color { data.totalTodayProgress >= 1 ? gold : blue }
    private var remainingMinutes: Int { max(data.dailyGoalMinutes - data.totalTodayMinutes, 0) }
    private var filteredEntries: [RecentEntry] {
        Array(data.recentEntries.filter {
            guard let t = $0.title else { return true }
            return !t.localizedCaseInsensitiveContains("input time prior")
        }.prefix(5))
    }

    @State private var showConfetti = false

    private func triggerGoalReached() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { showConfetti = false }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    if sizeClass == .regular {
                        iPadLayout
                    } else {
                        iPhoneLayout
                    }
                }
                .padding(.vertical, 24)
            }

            // Pinned bottom bar — always visible
            VStack(spacing: 0) {
                Divider()
                actionButtons
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .background(.bar)
        }
        .navigationTitle("DS Progress")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showConfetti {
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .onChange(of: data.totalTodayProgress) { oldValue, newValue in
            // Only fire when crossing the goal threshold, not on app open or incremental additions above 100%
            if oldValue < 1.0, newValue >= 1.0 {
                triggerGoalReached()
            }
        }
    }

    // MARK: iPad — ring left, stats + actions right
    private var iPadLayout: some View {
        HStack(alignment: .top, spacing: 48) {
            DailyGoalCard(data: data, ringSize: 280, lineWidth: 22)
                .frame(maxWidth: 340)

            VStack(spacing: 20) {
                statsGrid
                if !filteredEntries.isEmpty { recentSessionsSection }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity)
    }

    // MARK: iPhone — stacked
    private var iPhoneLayout: some View {
        VStack(spacing: 28) {
            DailyGoalCard(data: data)
            statsGrid.padding(.horizontal)
            if !filteredEntries.isEmpty { recentSessionsSection }
        }
    }

    // MARK: Shared subviews
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AppStatCard(icon: "clock.fill",  color: .blue,
                        value: String(format: "%.0f", data.totalHours), unit: "hrs total")
            AppStatCard(icon: "flame.fill",  color: .orange,
                        value: "\(data.streakDays)", unit: "wks streak")
            AppStatCard(icon: "calendar",    color: .cyan,
                        value: data.hoursThisMonth.map { String(format: "%.0f", $0) } ?? "—",
                        unit: "hrs this month")
            if let hrs = data.hoursToNextLevel {
                AppStatCard(
                    icon: "arrow.up.circle.fill", color: .green,
                    value: String(format: "%.0f", hrs),
                    unit: "hrs to next level"
                )
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button { showWebView = true } label: {
                    Label("Add Hours", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button { store.backgroundSync() } label: {
                    Label(store.isSyncing ? "Syncing…" : "Sync Now", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.isSyncing)
            }
            Text(data.lastUpdated.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var recentSessionsSection: some View {
        let entries = filteredEntries
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ringColor)
                Text("Recent Sessions")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        // Index bubble
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(.quaternary, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            if let title = entry.title {
                                Text(title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                            } else {
                                Text("Manual entry")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(entry.duration)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(ringColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ringColor.opacity(0.12), in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if entry.id != entries.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

}

// MARK: - Daily Goal Card

private let dsGradientCorners: [Color] = [
    Color(red: 0.91, green: 0.38, blue: 0.28),
    Color(red: 0.29, green: 0.50, blue: 0.96)
]
private let dsGradientComplete: [Color] = [
    Color(red: 1.0, green: 0.85, blue: 0.2),
    Color(red: 0.91, green: 0.38, blue: 0.28),
    Color(red: 0.29, green: 0.50, blue: 0.96)
]

struct DailyGoalCard: View {
    let data: ProgressData
    var ringSize: CGFloat = 210
    var lineWidth: CGFloat = 18

    private var gradientColors: [Color] {
        data.totalTodayProgress >= 1 ? dsGradientComplete : dsGradientCorners
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.secondary.opacity(0.1), lineWidth: lineWidth)

                // Glow layer
                Circle()
                    .trim(from: 0, to: data.totalTodayProgress)
                    .stroke(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 6)
                    .opacity(0.35)
                    .animation(.spring(duration: 0.7), value: data.totalTodayProgress)

                // Main arc
                Circle()
                    .trim(from: 0, to: data.totalTodayProgress)
                    .stroke(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.7), value: data.totalTodayProgress)

                // Center label
                VStack(spacing: 2) {
                    Text("\(data.totalTodayMinutes)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(data.totalTodayProgress >= 1
                            ? Color(red: 1.0, green: 0.85, blue: 0.2) : .primary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.5), value: data.totalTodayMinutes)
                    Text("/ \(data.dailyGoalMinutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.5), value: data.dailyGoalMinutes)
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Status label
            if data.totalTodayProgress >= 1 {
                Label("Goal reached!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
            } else {
                let remaining = data.dailyGoalMinutes - data.totalTodayMinutes
                Text("\(remaining) min to go · \(Int(data.totalTodayProgress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.5), value: remaining)
            }
        }
    }
}

// MARK: - Stat card (app)

struct AppStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Confetti

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let xFraction: CGFloat          // 0…1 across width
    let delay: Double
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let startRotation: Double
    let horizontalDrift: CGFloat
    let fallDuration: Double
}

struct ConfettiView: View {
    private static let confettiColors: [Color] = [
        Color(red: 0.91, green: 0.38, blue: 0.28),   // DS coral
        Color(red: 0.29, green: 0.50, blue: 0.96),   // DS blue
        Color(red: 1.0,  green: 0.85, blue: 0.20),   // gold
        .green, .purple, .pink, .cyan
    ]

    @State private var particles: [ConfettiParticle] = Self.makeParticles()
    @State private var animate = false

    private static func makeParticles() -> [ConfettiParticle] {
        (0..<180).map { _ in
            ConfettiParticle(
                xFraction:       CGFloat.random(in: -0.05...1.05),
                delay:           Double.random(in: 0...2.0),
                color:           confettiColors.randomElement()!,
                width:           CGFloat.random(in: 6...14),
                height:          CGFloat.random(in: 4...9),
                startRotation:   Double.random(in: 0...360),
                horizontalDrift: CGFloat.random(in: -100...100),
                fallDuration:    Double.random(in: 2.0...3.0)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(animate ? p.startRotation + 720 : p.startRotation))
                    .position(
                        x: geo.size.width * p.xFraction + (animate ? p.horizontalDrift : 0),
                        y: animate ? geo.size.height + 120 : -20
                    )
                    .animation(
                        .easeIn(duration: p.fallDuration).delay(p.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    ContentView()
}
