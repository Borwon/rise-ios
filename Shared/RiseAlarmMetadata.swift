import Foundation
#if canImport(AlarmKit)
import AlarmKit

/// Shared between the app and the alarm widget extension.
///
/// Compiled into both targets, so it lives outside the `RISE/` folder and is
/// listed in both targets of `project.yml`. Guarded because AlarmKit only
/// exists in the iOS 26 SDK.
@available(iOS 26.0, *)
struct RiseAlarmMetadata: AlarmMetadata {
    var alarmID: String
    var label: String
    var challengeType: String
}
#endif
