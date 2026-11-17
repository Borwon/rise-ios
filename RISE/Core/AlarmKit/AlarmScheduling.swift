import Foundation
import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

enum AlarmPermissionState: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

enum AlarmSchedulingError: LocalizedError {
    case notAuthorized
    case unavailable
    case missingUsageDescription

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Alarm permission is off. Enable it in iOS Settings to schedule alarms."
        case .unavailable:
            "Alarm scheduling is not available on this iOS version."
        case .missingUsageDescription:
            "The alarm usage description is missing from the app configuration."
        }
    }
}

/// AlarmKit and `UNUserNotificationCenter` are main-actor bound, so the whole
/// abstraction is too. Every call site is a SwiftUI view or view model.
@MainActor
protocol AlarmSchedulingService {
    var kindDescription: String { get }
    func permissionState() async -> AlarmPermissionState
    func requestAuthorization() async -> AlarmPermissionState
    func schedule(_ alarm: Alarm) async throws
    func cancel(alarmID: UUID) async
}

/// Picks the best scheduler the running OS supports.
enum AlarmSchedulerFactory {
    @MainActor
    static func make() -> any AlarmSchedulingService {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), AlarmKitScheduler.isSupported {
            return AlarmKitScheduler()
        }
        #endif
        return NotificationAlarmScheduler()
    }
}

// MARK: - AlarmKit (iOS 26+)

#if canImport(AlarmKit)
@MainActor
@available(iOS 26.0, *)
struct AlarmKitScheduler: AlarmSchedulingService {
    /// AlarmKit requires the usage description; without it scheduling fails at runtime.
    static var isSupported: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSAlarmKitUsageDescription") != nil
    }

    let kindDescription = "System alarm (AlarmKit)"

    func permissionState() async -> AlarmPermissionState {
        switch AlarmManager.shared.authorizationState {
        case .authorized: .authorized
        case .denied: .denied
        default: .notDetermined
        }
    }

    func requestAuthorization() async -> AlarmPermissionState {
        if AlarmManager.shared.authorizationState == .authorized { return .authorized }
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            switch state {
            case .authorized: return .authorized
            case .denied: return .denied
            default: return .notDetermined
            }
        } catch {
            return .denied
        }
    }

    func schedule(_ alarm: Alarm) async throws {
        guard Self.isSupported else { throw AlarmSchedulingError.missingUsageDescription }

        let state = await requestAuthorization()
        guard state == .authorized else { throw AlarmSchedulingError.notAuthorized }

        // iOS 26.0 requires `stopButton`; the shorter initialiser arrived in 26.1.
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.displayName),
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill"
            ),
            secondaryButton: AlarmButton(
                text: "Snooze",
                textColor: .white,
                systemImageName: "zzz"
            ),
            secondaryButtonBehavior: .countdown
        )

        let countdownTitle = LocalizedStringResource(stringLiteral: "Snoozing")
        let countdown = AlarmPresentation.Countdown(
            title: countdownTitle,
            pauseButton: nil
        )

        let presentation = AlarmPresentation(alert: alert, countdown: countdown)
        let metadata = RiseAlarmMetadata(
            alarmID: alarm.id.uuidString,
            label: alarm.displayName,
            challengeType: alarm.challengeType.rawValue
        )
        let attributes = AlarmAttributes<RiseAlarmMetadata>(
            presentation: presentation,
            metadata: metadata,
            tintColor: RISETheme.Colors.primary
        )

        let schedule: AlarmKit.Alarm.Schedule = alarm.weekdays.isEmpty
            ? .relative(.init(
                time: .init(hour: alarm.hour, minute: alarm.minute),
                repeats: .never
            ))
            : .relative(.init(
                time: .init(hour: alarm.hour, minute: alarm.minute),
                repeats: .weekly(Self.localeWeekdays(from: alarm.weekdays))
            ))

        let configuration = AlarmManager.AlarmConfiguration<RiseAlarmMetadata>(
            countdownDuration: AlarmKit.Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(alarm.snoozeMinutes * 60)
            ),
            schedule: schedule,
            attributes: attributes,
            sound: .default
        )

        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(alarmID: UUID) async {
        try? AlarmManager.shared.cancel(id: alarmID)
    }

    /// Calendar weekday (1 = Sunday) → `Locale.Weekday`.
    static func localeWeekdays(from weekdays: [Int]) -> [Locale.Weekday] {
        weekdays.compactMap { day in
            switch day {
            case 1: .sunday
            case 2: .monday
            case 3: .tuesday
            case 4: .wednesday
            case 5: .thursday
            case 6: .friday
            case 7: .saturday
            default: nil
            }
        }
    }
}
#endif

// MARK: - Notification fallback (iOS 18–25)

@MainActor
struct NotificationAlarmScheduler: AlarmSchedulingService {
    let kindDescription = "Notification reminder (no AlarmKit)"

    private let center = UNUserNotificationCenter.current()

    func permissionState() async -> AlarmPermissionState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async -> AlarmPermissionState {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func schedule(_ alarm: Alarm) async throws {
        let state = await requestAuthorization()
        guard state == .authorized else { throw AlarmSchedulingError.notAuthorized }

        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: alarm.id))

        let content = UNMutableNotificationContent()
        content.title = alarm.displayName
        content.body = "Time for your \(alarm.challengeType.title.lowercased())."
        content.sound = .default

        let days = alarm.weekdays.isEmpty ? [Calendar.current.component(.weekday, from: alarm.nextFireDate() ?? .now)] : alarm.weekdays

        if alarm.weekdays.isEmpty {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await add(id: identifiers(for: alarm.id).first!, content: content, trigger: trigger)
            return
        }

        for day in days {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.weekday = day
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try await add(
                id: "\(alarm.id.uuidString)-\(day)",
                content: content,
                trigger: trigger
            )
        }
    }

    func cancel(alarmID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: alarmID))
    }

    private func identifiers(for alarmID: UUID) -> [String] {
        (1...7).map { "\(alarmID.uuidString)-\($0)" } + [alarmID.uuidString]
    }

    private func add(id: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger) async throws {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(request)
    }
}
