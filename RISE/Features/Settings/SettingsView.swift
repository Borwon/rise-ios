import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    var isPresentedAsSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SoundAsset.createdAt) private var sounds: [SoundAsset]
    @Query private var alarms: [Alarm]
    @Query private var history: [AlarmHistory]

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("defaultSnoozeMinutes") private var defaultSnoozeMinutes = 5
    @AppStorage("defaultSoundName") private var defaultSoundName = SoundLibrary.defaultSoundName
    @AppStorage("defaultSoundID") private var defaultSoundID = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var permission: AlarmPermissionState = .notDetermined
    @State private var showsDeleteConfirmation = false
    @State private var showsOnboarding = false

    private let scheduler = AlarmSchedulerFactory.make()

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Theme")
                    Spacer()
                    Text("Dark Premium")
                        .foregroundStyle(RISETheme.Colors.muted)
                }

                Toggle("Haptics", isOn: $hapticsEnabled)
                    .tint(RISETheme.Colors.primary)

                Picker("Default snooze", selection: $defaultSnoozeMinutes) {
                    ForEach([1, 2, 5, 10, 15, 20, 30], id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }

                NavigationLink {
                    SoundLibraryView(
                        selectedSoundName: $defaultSoundName,
                        selectedSoundID: Binding<UUID?>(
                            get: { UUID(uuidString: defaultSoundID) },
                            set: { defaultSoundID = $0?.uuidString ?? "" }
                        )
                    )
                } label: {
                    HStack {
                        Text("Default alarm sound")
                        Spacer()
                        Text(defaultSoundName)
                            .foregroundStyle(RISETheme.Colors.muted)
                    }
                }
            } header: {
                Text("General")
            } footer: {
                Text("RISE. always uses its dark premium appearance. Language follows iOS.")
            }

            Section {
                HStack {
                    Text("Alarm permission")
                    Spacer()
                    Text(permissionLabel)
                        .foregroundStyle(permission == .authorized ? RISETheme.Colors.success : RISETheme.Colors.muted)
                }

                Text(scheduler.kindDescription)
                    .font(RISETheme.Typography.caption)
                    .foregroundStyle(RISETheme.Colors.muted)

                if permission != .authorized, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open iOS Settings") {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("Alarms")
            } footer: {
                Text("Alarm scheduling depends on iOS. On versions without AlarmKit, RISE. falls back to notifications that may not break through Silent mode or Focus.")
            }

            Section {
                NavigationLink {
                    SoundLibraryView()
                } label: {
                    Label("Manage Sounds", systemImage: "waveform")
                }

                Text("\(sounds.filter { !$0.isBuiltIn }.count) imported · \(sounds.filter(\.isBuiltIn).count) built-in")
                    .font(RISETheme.Typography.caption)
                    .foregroundStyle(RISETheme.Colors.muted)
            } header: {
                Text("Audio")
            }

            Section {
                LabeledContent("Alarms", value: "\(alarms.count)")
                LabeledContent("Wake-up history", value: "\(history.count)")

                Button("Delete All Local Data", role: .destructive) {
                    showsDeleteConfirmation = true
                }

                Button("Show Onboarding Again") {
                    showsOnboarding = true
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("All alarm, sound and history data is stored only on this device. RISE. has no account and no backend.")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            }
        }
        .scrollContentBackground(.hidden)
        .background(RISETheme.Colors.background)
        .listRowBackground(RISETheme.Colors.surface)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedAsSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { permission = await scheduler.permissionState() }
        .confirmationDialog(
            "Delete all local data?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every alarm, imported sound and wake-up record from this device.")
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView { showsOnboarding = false }
        }
    }

    private var permissionLabel: String {
        switch permission {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not asked yet"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func deleteAllData() {
        for alarm in alarms {
            Task { await AlarmSchedulerFactory.make().cancel(alarmID: alarm.id) }
            modelContext.delete(alarm)
        }
        for sound in sounds where !sound.isBuiltIn {
            SoundImporter.deleteFile(for: sound)
            modelContext.delete(sound)
        }
        for entry in history {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}
