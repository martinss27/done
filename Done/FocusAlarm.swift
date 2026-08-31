import ActivityKit
import AlarmKit
import AudioToolbox
import UserNotifications

/// Rings when a round ends. A local notification covers the case that matters —
/// the phone is in your pocket or you are inside the app you unblocked — and a
/// system alert sound covers the app being open, where iOS drops the banner.
/// ponytail: a plain notification sound, not a ringtone that keeps going until
/// dismissed. That needs Apple's critical-alert entitlement.
enum FocusAlarm {
    private static let id = "pomodoro.round"

    /// Shows the notification even with the app open — without this, iOS drops
    /// it silently and a round that ends while you are watching rings nothing.
    private final class Presenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }
    }
    private static let presenter = Presenter()

    static func install() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    static func isOn() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
    }

    @discardableResult
    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func arm(at date: Date, saying body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Round over"
        content.body = body
        content.sound = .default
        let seconds = max(date.timeIntervalSinceNow, 1)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    static func disarm() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Sound plus vibration: on a phone set to silent the sound is dropped and
    /// the buzz is the only thing left.
    static func ring() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
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

/// The real thing, iOS 26 and up: a system alarm that rings through silent mode
/// and Do Not Disturb, with Apple's own alerting screen and its own countdown on
/// the lock screen. Everything above stays as the fallback for iOS 17–25.
@available(iOS 26.0, *)
enum RealAlarm {
    /// One alarm at a time, so a fixed id is enough to cancel or replace it.
    private static let id = UUID(uuidString: "3E9F0A2C-1D4B-4F87-9C0E-7A5D2B6E8F10")!

    static var isAuthorized: Bool { AlarmManager.shared.authorizationState == .authorized }

    @discardableResult
    static func request() async -> Bool {
        ((try? await AlarmManager.shared.requestAuthorization()) ?? .denied) == .authorized
    }

    static func start(seconds: TimeInterval, phase: String, saying body: String) async {
        stop()
        let attributes = AlarmAttributes<FocusMetadata>(
            presentation: AlarmPresentation(
                alert: .init(title: LocalizedStringResource(stringLiteral: body),
                             stopButton: AlarmButton(text: "Stop",
                                                     textColor: .black,
                                                     systemImageName: "stop.fill")),
                countdown: .init(title: LocalizedStringResource(stringLiteral: phase))),
            metadata: FocusMetadata(),
            tintColor: .white)
        _ = try? await AlarmManager.shared.schedule(
            id: id,
            configuration: .timer(duration: seconds, attributes: attributes, sound: .default))
    }

    static func stop() {
        try? AlarmManager.shared.cancel(id: id)
    }
}
