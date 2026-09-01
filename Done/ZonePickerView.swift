import CoreLocation
import MapKit
import SwiftUI

/// Pick the circle a block cares about: drop a pin, size the radius, and say
/// whether being inside it locks the apps or is the one place they open.
struct ZonePickerView: View {
    @Binding var zone: Zone?
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Zone
    @State private var camera: MapCameraPosition
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var locator = Locator()
    /// A zone that was never placed follows the phone until you pick something.
    @State private var following: Bool

    init(zone: Binding<Zone?>) {
        _zone = zone
        // The fallback only shows if location is unavailable — see `follow()`.
        let start = zone.wrappedValue
            ?? Zone(name: "", latitude: -9.6658, longitude: -35.7353)
        _following = State(initialValue: zone.wrappedValue == nil)
        _draft = State(initialValue: start)
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude),
            latitudinalMeters: 600, longitudinalMeters: 600)))
    }

    private var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: draft.latitude, longitude: draft.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            map.overlay(alignment: .top) { search }
            controls
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var bar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.white.opacity(0.08), in: Capsule())
            Spacer()
            Text("Blocked zone").font(.title3.weight(.semibold))
            Spacer()
            Button("Save") { zone = draft; dismiss() }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.white.opacity(0.08), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                Marker(draft.name.isEmpty ? "Zone" : draft.name, coordinate: center)
                MapCircle(center: center, radius: draft.radius)
                    .foregroundStyle(.green.opacity(0.25))
                    .stroke(.green, lineWidth: 2)
            }
            .mapControls { MapUserLocationButton() }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                following = false
                draft.latitude = coordinate.latitude
                draft.longitude = coordinate.longitude
            }
            .onAppear(perform: follow)
        }
    }

    private var search: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search a place", text: $query)
                    .submitLabel(.search)
                    .onSubmit { Task { await lookUp() } }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            ForEach(results.prefix(4), id: \.self) { item in
                Button { pick(item) } label: {
                    HStack {
                        Text(item.name ?? "Place").lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(16)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            TextField("Name this place", text: $draft.name)
                .padding(16)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 12) {
                Text("Radius").font(.subheadline.weight(.semibold))
                // 50 m is CoreLocation's practical floor for a reliable crossing.
                Slider(value: $draft.radius, in: 50...1000, step: 10)
                Text("\(Int(draft.radius))m")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.green)
            }

            HStack(spacing: 4) {
                modeTab("Block apps here", on: draft.blockInside)
                modeTab("Unlock apps here", on: !draft.blockInside)
            }
            .padding(4)
            .background(.white.opacity(0.07), in: Capsule())

            Text(draft.blockInside ? "Apps lock automatically inside the circle"
                 : "Apps stay locked everywhere except inside the circle")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func modeTab(_ title: String, on: Bool) -> some View {
        Button { draft.blockInside = title.hasPrefix("Block") } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(on ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: Capsule())
                .foregroundStyle(on ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    /// Drops the pin where the phone is. Only for a zone you have not placed yet.
    private func follow() {
        guard following else { return }
        locator.here { coordinate in
            guard following else { return }
            draft.latitude = coordinate.latitude
            draft.longitude = coordinate.longitude
            camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600,
                                                longitudinalMeters: 600))
        }
    }

    private func lookUp() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 20_000,
                                            longitudinalMeters: 20_000)
        results = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
    }

    private func pick(_ item: MKMapItem) {
        following = false
        let coordinate = item.placemark.coordinate
        draft.latitude = coordinate.latitude
        draft.longitude = coordinate.longitude
        if draft.name.isEmpty { draft.name = item.name ?? "" }
        camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600,
                                            longitudinalMeters: 600))
        results = []
        query = ""
    }
}
