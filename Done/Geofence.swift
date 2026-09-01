import CoreLocation
import Foundation
import Observation

/// Watches the circles blocks care about. Region monitoring is the only kind of
/// location work iOS wakes a closed app for, so this is where the zone half of
/// the gate is written — the DeviceActivity extensions never see a coordinate.
@Observable
final class Geofence: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var status: CLAuthorizationStatus = .notDetermined
    /// Zones need "Always" to fire while the app is closed.
    var isAuthorized: Bool { status == .authorizedAlways }

    override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
        status = manager.authorizationStatus
    }

    func requestAuthorization() {
        // Two steps: iOS only offers Always after When In Use has been granted.
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { manager.requestAlwaysAuthorization() }
    }

    /// Points the monitor at exactly the zones the current blocks define.
    func sync(_ habits: [Habit]) {
        let wanted = habits.filter { $0.isEnabled && $0.zone != nil }
        let live = Set(wanted.map(\.id.uuidString))

        for region in manager.monitoredRegions where !live.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
        guard isAuthorized else { return }

        var gate = Gate.current
        gate.inZone.formIntersection(Set(wanted.map(\.id)))
        gate.store()

        let already = Set(manager.monitoredRegions.map(\.identifier))
        for habit in wanted where !already.contains(habit.id.uuidString) {
            guard let zone = habit.zone else { continue }
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude),
                radius: max(zone.radius, 50),
                identifier: habit.id.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            // Monitoring only reports crossings, so ask where we are right now.
            manager.requestState(for: region)
        }
    }

    private func set(_ id: UUID, inside: Bool) {
        var gate = Gate.current
        let changed = inside ? gate.inZone.insert(id).inserted : gate.inZone.remove(id) != nil
        guard changed else { return }
        gate.store()
        Shield.apply()
        Diagnostics.log("zone \(inside ? "entered" : "left") \(id.uuidString.prefix(8))")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let id = UUID(uuidString: region.identifier) { set(id, inside: true) }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let id = UUID(uuidString: region.identifier) { set(id, inside: false) }
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState,
                         for region: CLRegion) {
        guard state != .unknown, let id = UUID(uuidString: region.identifier) else { return }
        set(id, inside: state == .inside)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if status == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
    }
}

/// One reading, taken only while the map picker is open, so a new zone starts
/// where you are instead of at a hardcoded coordinate. Nothing is stored.
final class Locator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var handler: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func here(_ handler: @escaping (CLLocationCoordinate2D) -> Void) {
        self.handler = handler
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined, .denied, .restricted: break
        default: manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        handler?(coordinate)
        handler = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        handler = nil
    }
}
