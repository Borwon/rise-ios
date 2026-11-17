import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var alarms: [Alarm]
    @Query private var history: [AlarmHistory]

    var body: some View {
        @Bindable var appState = appState

        TabView {
            NavigationStack {
                AlarmsHomeView()
            }
            .tabItem {
                Label("Alarms", systemImage: "alarm")
            }

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(RISETheme.Colors.primary)
        .fullScreenCover(isPresented: $appState.isPresentingChallenge) {
            if let alarm = pendingAlarm {
                ChallengeFlowView(alarm: alarm, isPreview: appState.pendingChallengeIsPreview) { result in
                    appState.finishChallenge(with: result)
                    appState.dismissChallenge()
                }
                .interactiveDismissDisabled()
            } else {
                // The alarm was deleted between being scheduled and the challenge starting.
                Color.clear.onAppear { appState.dismissChallenge() }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
        .task {
            recordMissedAlarmsIfNeeded()
            openChallengeIfAlarmJustRang()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                openChallengeIfAlarmJustRang()
            }
        }
    }

    private var pendingAlarm: Alarm? {
        guard let id = appState.pendingAlarmID else { return nil }
        return alarms.first { $0.id == id }
    }

    /// AlarmKit cannot force the challenge over the lock screen, so the challenge
    /// starts as soon as the user opens the app within the alarm's window.
    private func openChallengeIfAlarmJustRang() {
        guard hasCompletedOnboarding, appState.pendingAlarmID == nil else { return }

        let now = Date()
        let calendar = Calendar.current

        for alarm in alarms where alarm.isEnabled {
            guard alarm.recentlyFiredDate(relativeTo: now) != nil else { continue }

            let alreadyCompletedToday = history.contains { entry in
                guard entry.alarmID == alarm.id, entry.outcome == .completed else { return false }
                guard let completedAt = entry.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: now)
            }

            if !alreadyCompletedToday {
                appState.beginChallenge(for: alarm.id)
                return
            }
        }
    }

    /// Records alarms whose time passed today without a completed challenge, so
    /// Insights can show missed wake-ups. Runs once per launch.
    private func recordMissedAlarmsIfNeeded() {
        guard hasCompletedOnboarding else { return }

        let now = Date()
        let calendar = Calendar.current
        var didInsert = false

        for alarm in alarms where alarm.isEnabled {
            guard let occurrence = alarm.todayScheduledOccurrence(relativeTo: now) else { continue }
            // Ignore occurrences from before the alarm itself existed.
            guard occurrence > alarm.createdAt else { continue }
            // Only once the wake-up window has closed.
            guard now.timeIntervalSince(occurrence) > 15 * 60 else { continue }

            let alreadyRecorded = history.contains { entry in
                guard entry.alarmID == alarm.id else { return false }
                if calendar.isDate(entry.scheduledFor, inSameDayAs: occurrence) { return true }
                if let completedAt = entry.completedAt,
                   calendar.isDate(completedAt, inSameDayAs: occurrence) {
                    return true
                }
                return false
            }

            if !alreadyRecorded {
                modelContext.insert(
                    AlarmHistory(
                        alarmID: alarm.id,
                        alarmLabel: alarm.displayName,
                        scheduledFor: occurrence,
                        completedAt: nil,
                        outcome: .missed,
                        challengeType: alarm.challengeType
                    )
                )
                didInsert = true
            }
        }

        if didInsert {
            try? modelContext.save()
        }
    }
}
