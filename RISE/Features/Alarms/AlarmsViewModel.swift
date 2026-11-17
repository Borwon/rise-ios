import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AlarmsViewModel {
    private(set) var permission: AlarmPermissionState = .notDetermined
    private(set) var schedulerKind: String = ""
    var errorMessage: String?
    var isBusy = false

    private let scheduler = AlarmSchedulerFactory.make()
    private var didRefreshSchedules = false

    var needsPermission: Bool { permission != .authorized }

    func refreshPermission() async {
        schedulerKind = scheduler.kindDescription
        permission = await scheduler.permissionState()
    }

    /// Asks the system for alarm permission, then reports the resulting state.
    @discardableResult
    func requestPermission() async -> AlarmPermissionState {
        permission = await scheduler.requestAuthorization()
        return permission
    }

    @discardableResult
    func save(_ draft: AlarmDraft, existing: Alarm?, context: ModelContext) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil

        let alarm = draft.apply(to: existing, in: context)

        do {
            if alarm.isEnabled {
                try await scheduler.schedule(alarm)
                alarm.lastScheduledAt = .now
                alarm.lastScheduleError = nil
            } else {
                await scheduler.cancel(alarmID: alarm.id)
                alarm.lastScheduledAt = nil
                alarm.lastScheduleError = nil
            }
            try context.save()
            return true
        } catch {
            // Never claim an alarm is active when the system did not confirm it.
            alarm.isEnabled = false
            alarm.lastScheduledAt = nil
            alarm.lastScheduleError = error.localizedDescription
            errorMessage = error.localizedDescription
            try? context.save()
            return false
        }
    }

    func setEnabled(_ enabled: Bool, for alarm: Alarm, context: ModelContext) async {
        errorMessage = nil
        alarm.isEnabled = enabled

        do {
            if enabled {
                try await scheduler.schedule(alarm)
                alarm.lastScheduledAt = .now
                alarm.lastScheduleError = nil
            } else {
                await scheduler.cancel(alarmID: alarm.id)
                alarm.lastScheduledAt = nil
                alarm.lastScheduleError = nil
            }
            try context.save()
        } catch {
            alarm.isEnabled = false
            alarm.lastScheduleError = error.localizedDescription
            errorMessage = error.localizedDescription
            try? context.save()
        }
    }

    func delete(_ alarm: Alarm, context: ModelContext) async {
        await scheduler.cancel(alarmID: alarm.id)
        // The `.cascade` delete rule removes the linked ChallengeConfig.
        context.delete(alarm)
        try? context.save()
    }

    /// Re-schedules every enabled alarm (device restart, iOS upgrade, app update).
    /// Runs at most once per session: repeatedly re-scheduling the same alarm id
    /// would count against AlarmKit's alarm limit.
    func refreshSchedules(for alarms: [Alarm], context: ModelContext) async {
        guard !didRefreshSchedules else { return }
        didRefreshSchedules = true

        await refreshPermission()
        guard permission == .authorized else { return }

        for alarm in alarms where alarm.isEnabled {
            do {
                try await scheduler.schedule(alarm)
                alarm.lastScheduledAt = .now
                alarm.lastScheduleError = nil
            } catch {
                alarm.lastScheduleError = error.localizedDescription
            }
        }
        try? context.save()
    }
}
