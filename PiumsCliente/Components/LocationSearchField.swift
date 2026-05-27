import SwiftUI
import MapKit
import CoreLocation

// MARK: - Completer ViewModel

@Observable
@MainActor
private final class LocationCompleterVM: NSObject, MKLocalSearchCompleterDelegate {
    var suggestions: [MKLocalSearchCompletion] = []
    var isResolving = false

    private let completer = MKLocalSearchCompleter()

    static let guatemalaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 15.4, longitude: -90.5),
        span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 4.5)
    )

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
        completer.region = Self.guatemalaRegion
    }

    func updateQuery(_ q: String) {
        completer.queryFragment = q
    }

    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        isResolving = true
        defer { isResolving = false }
        let request = MKLocalSearch.Request(completion: completion)
        request.region = completer.region
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first?.placemark.location?.coordinate
                ?? response.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in self.suggestions = completer.results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}

// MARK: - LocationSearchField

/// Text field with live autocomplete using MapKit.
/// Uses an internal localText so that external binding changes (geocoder, locationStore)
/// never overwrite what the user is actively typing.
struct LocationSearchField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var coordinate: CLLocationCoordinate2D?
    var onSelect: ((CLLocationCoordinate2D) -> Void)? = nil
    var searchRegion: MKCoordinateRegion? = nil

    @State private var vm = LocationCompleterVM()
    @State private var showSuggestions = false
    // localText es lo que el TextField muestra; text (binding) es la fuente de verdad del padre.
    // Los cambios externos al binding solo actualizan localText cuando el campo no está enfocado.
    @State private var localText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldRow
            if showSuggestions && !vm.suggestions.isEmpty && isFocused {
                suggestionsDropdown
                    .padding(.top, 4)
                    .zIndex(10)
            }
        }
        .onAppear {
            localText = text
            if let r = searchRegion { vm.setRegion(r) }
        }
        // Sincronizar cambios externos → localText SOLO cuando no está enfocado
        .onChange(of: text) { _, newVal in
            guard !isFocused else { return }
            localText = newVal
        }
    }

    // MARK: Field row

    private var fieldRow: some View {
        HStack(spacing: 10) {
            if vm.isResolving {
                ProgressView().scaleEffect(0.75).frame(width: 20)
            } else {
                Image(systemName: coordinate != nil ? "mappin.circle.fill" : "magnifyingglass")
                    .foregroundStyle(coordinate != nil ? Color.piumsOrange : .secondary)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $localText)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textContentType(.none)
                // El usuario escribió algo → sincronizar al binding padre y buscar
                .onChange(of: localText) { _, newVal in
                    text = newVal
                    vm.updateQuery(newVal)
                    showSuggestions = isFocused && !newVal.isEmpty
                    if newVal.isEmpty { coordinate = nil }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        // Al enfocar, mostrar sugerencias si ya hay texto
                        if !localText.isEmpty { showSuggestions = true }
                    } else {
                        // Pequeño delay para que el tap en una sugerencia no se pierda
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showSuggestions = false
                        }
                        // Al salir, sincronizar cualquier cambio externo que llegó mientras estaba enfocado
                        if localText != text { localText = text }
                    }
                }
            if !localText.isEmpty {
                Button {
                    localText = ""
                    text = ""
                    coordinate = nil
                    vm.updateQuery("")
                    showSuggestions = false
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Suggestions dropdown

    private var suggestionsDropdown: some View {
        let capped = Array(vm.suggestions.prefix(5).enumerated())
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(capped, id: \.offset) { idx, suggestion in
                Button {
                    Task {
                        guard let coord = await vm.resolve(suggestion) else { return }
                        let label = suggestion.subtitle.isEmpty
                            ? suggestion.title
                            : "\(suggestion.title), \(suggestion.subtitle)"
                        localText = label
                        text = label
                        coordinate = coord
                        showSuggestions = false
                        isFocused = false
                        onSelect?(coord)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin")
                            .foregroundStyle(Color.piumsOrange)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if idx < capped.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
    }
}
