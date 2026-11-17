import SwiftUI
import SwiftData
import UIKit

struct AlarmsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Alarm.createdAt) private var alarms: [Alarm]

    @State private var viewModel = AlarmsViewModel()
    @State private var editorTarget: EditorTarget?
    @State private var showsSettings = false
    @State private var alarmPendingDeletion: Alarm?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
                header
                greeting

                if viewModel.needsPermission {
                    permissionCard
                }

                if let error = viewModel.errorMessage {
                    RISEInlineMessage(text: error, kind: .error)
                }

                nextAlarmCard

                HStack(alignment: .firstTextBaseline) {
                    RISESectionHeader(title: "My Alarms")
                    Text("\(alarms.count)")
                        .font(RISETheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(RISETheme.Colors.muted)
                }

                if alarms.isEmpty {
                    RISEEmptyState(
                        icon: "alarm",
                        title: "No alarms yet.",
                        message: "Create your first alarm and build a better morning routine.",
                        actionTitle: "Create Alarm"
                    ) {
                        editorTarget = .new
                    }
                } else {
                    VStack(spacing: RISETheme.Spacing.sm) {
                        ForEach(alarms) { alarm in
                            AlarmCardView(
                                alarm: alarm,
                                isEnabled: Binding(
                                    get: { alarm.isEnabled },
                                    set: { newValue in
                                        Task {
                                            await viewModel.setEnabled(newValue, for: alarm, context: modelContext)
                                        }
                                    }
                                ),
                                onTap: { editorTarget = .edit(alarm) },
                                onDelete: { alarmPendingDeletion = alarm }
                            )
                        }
                    }

                    RISEButton(title: "Add Alarm", icon: "plus") {
                        editorTarget = .new
                    }
                    .padding(.top, RISETheme.Spacing.sm)
                }
            }
            .padding(RISETheme.Layout.screenPadding)
            .padding(.bottom, RISETheme.Spacing.xl)
        }
        .riseScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            SoundLibrary.seedBuiltInsIfNeeded(context: modelContext)
            await viewModel.refreshPermission()
            await viewModel.refreshSchedules(for: alarms, context: modelContext)

            #if DEBUG
            if LaunchOptions.opensAlarmEditor {
                editorTarget = alarms.first.map(EditorTarget.edit) ?? .new
            }
            #endif
        }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .new:
                AlarmEditorView(existing: nil)
            case .edit(let alarm):
                AlarmEditorView(existing: alarm)
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                SettingsView(isPresentedAsSheet: true)
            }
        }
        .confirmationDialog(
            "Delete this alarm?",
            isPresented: Binding(
                get: { alarmPendingDeletion != nil },
                set: { if !$0 { alarmPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: alarmPendingDeletion
        ) { alarm in
            Button("Delete \(alarm.displayName)", role: .destructive) {
                Task { await viewModel.delete(alarm, context: modelContext) }
                alarmPendingDeletion = nil
            }
            Button("Keep Alarm", role: .cancel) { alarmPendingDeletion = nil }
        } message: { alarm in
            Text("\(alarm.timeLabel) · \(alarm.repeatSummary). This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RISE.")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(RISETheme.Colors.primary)
                    .accessibilityLabel("RISE")

                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(RISETheme.Typography.caption)
                    .foregroundStyle(RISETheme.Colors.muted)
            }

            Spacer()

            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(RISETheme.Colors.text)
                    .frame(width: RISETheme.Layout.minimumTouchTarget, height: RISETheme.Layout.minimumTouchTarget)
                    .background(RISETheme.Colors.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var greeting: some View {
        Text(greetingText)
            .font(RISETheme.Typography.screenTitle)
            .foregroundStyle(RISETheme.Colors.text)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.sm) {
            RISEInlineMessage(
                text: viewModel.permission == .denied
                    ? "Alarm permission is off. Open iOS Settings → RISE. → Alarms to turn it back on."
                    : "RISE. needs alarm permission so your alarms ring on time.",
                kind: viewModel.permission == .denied ? .error : .info
            )

            if viewModel.permission == .notDetermined {
                RISEButton(title: "Allow Alarms", style: .secondary) {
                    Task { await viewModel.requestPermission() }
                }
            } else if viewModel.permission == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                RISEButton(title: "Open iOS Settings", style: .secondary) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    @ViewBuilder
    private var nextAlarmCard: some View {
        if let next = nextAlarm {
            VStack(alignment: .leading, spacing: RISETheme.Spacing.sm) {
                Text("Next Alarm")
                    .font(RISETheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(RISETheme.Colors.muted)

                Text(next.alarm.timeLabel)
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(RISETheme.Colors.text)

                HStack(spacing: RISETheme.Spacing.sm) {
                    Text(next.alarm.displayName)
                    Text("·")
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(countdownLabel(to: next.date, from: context.date))
                    }
                }
                .font(RISETheme.Typography.body)
                .foregroundStyle(RISETheme.Colors.muted)

                Button {
                    appState.beginChallenge(for: next.alarm.id, isPreview: true)
                } label: {
                    Label("Preview challenge", systemImage: "play.circle")
                        .font(RISETheme.Typography.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(RISETheme.Colors.primary)
                .padding(.top, RISETheme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RISETheme.Spacing.lg)
            .background(RISETheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.large, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next alarm \(next.alarm.timeLabel), \(next.alarm.displayName)")
        } else if !alarms.isEmpty {
            RISEInlineMessage(text: "No enabled alarms. Turn one on to see your next wake-up here.", kind: .info)
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning."
        case 12..<17: "Good afternoon."
        case 17..<22: "Good evening."
        default: "Good night."
        }
    }

    private var nextAlarm: (alarm: Alarm, date: Date)? {
        alarms
            .filter(\.isEnabled)
            .compactMap { alarm in
                alarm.nextFireDate().map { (alarm, $0) }
            }
            .min { $0.1 < $1.1 }
    }

    private func countdownLabel(to date: Date, from now: Date) -> String {
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(minutes)m"
    }
}

private enum EditorTarget: Identifiable {
    case new
    case edit(Alarm)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let alarm): alarm.id.uuidString
        }
    }
}
