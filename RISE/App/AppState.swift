import Foundation
import SwiftUI

/// Cross-feature UI state that must survive tab changes.
@Observable
@MainActor
final class AppState {
    /// Set when the user should be taken into the wake-up challenge.
    var pendingAlarmID: UUID?

    /// True when the challenge was started from "Preview challenge" and must not
    /// write history or change alarm state.
    var pendingChallengeIsPreview = false

    /// Result of the most recent completed challenge, shown on the success screen.
    var lastResult: ChallengeResult?

    var isPresentingChallenge: Bool {
        get { pendingAlarmID != nil }
        set { if newValue == false { pendingAlarmID = nil } }
    }

    func beginChallenge(for alarmID: UUID, isPreview: Bool = false) {
        guard pendingAlarmID == nil else { return }
        pendingAlarmID = alarmID
        pendingChallengeIsPreview = isPreview
    }

    func finishChallenge(with result: ChallengeResult) {
        lastResult = result
    }

    func dismissChallenge() {
        pendingAlarmID = nil
        pendingChallengeIsPreview = false
    }
}

struct ChallengeResult {
    let alarmID: UUID
    let type: ChallengeType
    let correct: Int
    let total: Int
    let completedAt: Date
    let wakeUpTimeLabel: String
}
