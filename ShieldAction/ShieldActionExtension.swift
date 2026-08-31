import ManagedSettings

/// Handles the buttons on the shield. The secondary one spends a banked unlock:
/// it drops the shield and starts the clock on the time you just bought.
final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action, application: application))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(action == .primaryButtonPressed ? .close : .none)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(action == .primaryButtonPressed ? .close : .none)
    }

    private func respond(to action: ShieldAction, application: ApplicationToken) -> ShieldActionResponse {
        guard action == .secondaryButtonPressed else { return .close }
        guard let habit = Shield.habits.first(where: {
            Shield.blocked($0.id).applicationTokens.contains(application)
        }) else { return .close }

        var gate = Gate.current
        guard gate.banked.remove(habit.id) != nil else { return .defer }
        gate.open.insert(habit.id)
        gate.store()

        Shield.apply()
        Monitoring.arm(habit, unlocked: true)
        return .none
    }
}
