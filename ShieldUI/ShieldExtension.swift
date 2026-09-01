import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the screen you hit when you open a blocked app. It runs in its own
/// process and reads the shared state to say which block is holding the door.
final class ShieldExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(appName: application.localizedDisplayName,
             habit: application.token.flatMap(habit(shielding:)))
    }


    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make(appName: application.localizedDisplayName,
             habit: application.token.flatMap(habit(shielding:)))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(appName: webDomain.domain, habit: nil)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make(appName: webDomain.domain, habit: nil)
    }

    /// The block whose list this app is on. More than one can shield the same
    /// app; the first is enough to tell the user what to go do.
    private func habit(shielding token: ApplicationToken) -> Habit? {
        Shield.habits.first { Shield.blocked($0.id).applicationTokens.contains(token) }
    }

    /// The asset is a 1024pt square at 1x, which the shield draws at full size
    /// with hard corners. Redraw it at icon scale, rounded, once per process.
    private static let logo: UIImage? = {
        guard let source = UIImage(named: "IconMark") else { return nil }
        let side: CGFloat = 110
        let rect = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        return UIGraphicsImageRenderer(size: rect.size).image { _ in
            UIBezierPath(roundedRect: rect, cornerRadius: side * 0.23).addClip()
            source.draw(in: rect)
        }
    }()

    private func make(appName: String?, habit: Habit?) -> ShieldConfiguration {
        let name = appName ?? "this app"
        // A focus round closes far more than one block's apps, so naming a
        // habit here would explain the wrong thing.
        if let focus = FocusSession.current {
            let left = focus.minutesLeft
            return shield(
                title: "Finish your focus round first!",
                subtitle: left <= 1 ? "Less than a minute left."
                                    : "\(left) min left. \(name) opens when the round ends.")
        }
        // A banked unlock changes the ask into an offer, and adds the button
        // that spends it — handled by the shield action extension.
        let banked = habit.map { Gate.current.banked.contains($0.id) } ?? false
        let spend = habit?.blockAgainMinutes
        let subtitle: String
        if banked {
            subtitle = spend.map { "You have 1 unlock banked (\($0) min)." }
                ?? "You have 1 unlock banked."
        } else {
            subtitle = habit?.shieldSubtitle ?? "Open Done to earn your unlock."
        }
        return shield(title: "To unlock \(name),\nfinish your habits first!",
                      subtitle: subtitle,
                      spendLabel: banked ? "Use 1 unlock" : nil)
    }

    private func shield(title: String, subtitle: String,
                        spendLabel: String? = nil) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            // ponytail: alpha is the dial here — 1 hides the app behind
            // completely, lower lets more of it through.
            backgroundColor: UIColor(white: 0.13, alpha: 0.7),
            icon: Self.logo,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle,
                                                color: UIColor(white: 0.7, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: spendLabel.map {
                ShieldConfiguration.Label(text: $0, color: .systemGreen)
            })
    }
}
