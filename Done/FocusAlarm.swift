import ActivityKit
import AudioToolbox
import UserNotifications

/// Rings when a round ends. A local notification covers the case that matters —
/// the phone is in your pocket or you are inside the app you unblocked — and a
/// system alert sound covers the app being open, where iOS drops the banner.
/// ponytail: a plain notification sound, not a ringtone that keeps going until
/// dismissed. That needs Apple's critical-alert entitlement.
enum FocusAlarm {
    private static let id = "pomodoro.round"

    static func arm(at date: Date, saying body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Round over"
            content.body = body
            content.sound = .default
            let seconds = max(date.timeIntervalSinceNow, 1)
            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
            center.add(request)
        }
    }

    static func disarm() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    static func ring() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }
}

/// The round on the lock screen and in the Dynamic Island.
enum FocusLive {
    static func start(phase: String, from: Date, to: Date) {
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = FocusAttributes.ContentState(startedAt: from, endsAt: to, phase: phase)
        _ = try? Activity.request(attributes: FocusAttributes(),
                                  content: .init(state: state, staleDate: to),
                                  pushType: nil)
    }

    static func end() {
        for activity in Activity<FocusAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
