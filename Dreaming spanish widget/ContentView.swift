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
        }
        // Foreground transition: app was already running in background
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                triggerSyncIfRequested()
                autoSyncIfStale()
            }
        }
        // Handle widget deep links
        .onOpenURL { url in
            guard url.scheme == "dswidget" else { return }
            if url.host == "refresh" {
                // Trigger sync then return to home screen automatically
                store.backgroundSync()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                    .padding(.horizontal, 32)
            }
            Button {
                showWebView = true
            } label: {
                Label("Log In to Dreaming Spanish", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            Spacer()
        }
        .navigationTitle("DS Progress Widget")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    let store: ProgressStore
    @Binding var showWebView: Bool

    private var data: ProgressData { store.data }

    // DS brand colors shared with widget
    private let coral = Color(red: 0.91, green: 0.38, blue: 0.28)
    private let blue  = Color(red: 0.29, green: 0.50, blue: 0.96)
    private let gold  = Color(red: 1.0,  green: 0.85, blue: 0.2)

    private var ringColor: Color {
        data.totalTodayProgress >= 1 ? gold : blue
    }

    private var remainingMinutes: Int {
        max(data.dailyGoalMinutes - data.totalTodayMinutes, 0)
    }

    // Confetti: stored as Double so @AppStorage can persist it
    @AppStorage("confettiShownDate") private var confettiShownDateInterval: Double = 0
    @State private var showConfetti = false

    private func triggerConfettiIfNeeded() {
        guard data.totalTodayProgress >= 1 else { return }
        let lastShown = Date(timeIntervalSince1970: confettiShownDateInterval)
        guard !Calendar.current.isDateInToday(lastShown) else { return }
        confettiShownDateInterval = Date().timeIntervalSince1970
        // Haptic feedback
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        showConfetti = true
        // Hide only after all particles have fallen off screen (max delay 2.0 + max fall 3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            showConfetti = false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // ── Progress ring (hero) ──────────────────────────────
                DailyGoalCard(data: data)

                // ── Stats grid ────────────────────────────────────────
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AppStatCard(
                        icon: "clock.fill", color: .blue,
                        value: String(format: "%.0f", data.totalHours), unit: "hrs total"
                    )
                    AppStatCard(
                        icon: "flame.fill", color: .orange,
                        value: "\(data.streakDays)", unit: "wks streak"
                    )
                    AppStatCard(
                        icon: "timer", color: ringColor,
                        value: remainingMinutes == 0 ? "Done!" : "\(remainingMinutes)",
                        unit: remainingMinutes == 0 ? "" : "min left"
                    )
                    AppStatCard(
                        icon: "target", color: .purple,
                        value: "\(data.dailyGoalMinutes)", unit: "min goal"
                    )
                }
                .padding(.horizontal)

                // ── Action buttons ────────────────────────────────────
                VStack(spacing: 12) {
                    Button {
                        showWebView = true
                    } label: {
                        Label("Add Hours", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        store.backgroundSync()
                    } label: {
                        Label(store.isSyncing ? "Syncing…" : "Sync Now", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(store.isSyncing)
                }
                .padding(.horizontal)

                Text("Updated \(data.lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("DS Progress")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear { triggerConfettiIfNeeded() }
        .onChange(of: data.totalTodayProgress) { triggerConfettiIfNeeded() }
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
    private let ringSize: CGFloat = 210
    private let lineWidth: CGFloat = 18

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
                    .trim(from: 0, to: max(data.totalTodayProgress, 0.01))
                    .stroke(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 6)
                    .opacity(0.35)

                // Main arc
                Circle()
                    .trim(from: 0, to: max(data.totalTodayProgress, 0.01))
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
