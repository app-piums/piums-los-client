// LocationStore.swift — Singleton observable que mantiene la ubicación del cliente
// en toda la app. Se inicializa una sola vez y se accede via @Environment.
import Foundation
import CoreLocation

@Observable
@MainActor
final class LocationStore {

    static let shared = LocationStore()

    // MARK: - Estado público
    var coordinate: CLLocationCoordinate2D? = nil
    var cityName: String = ""
    var isLocating: Bool = false
    var permissionDenied: Bool = false

    // MARK: - Privado
    private let manager = LocationManager()

    private init() {}

    // MARK: - API pública

    /// Pide la ubicación una vez. Si ya la tenemos (< 5 min de antigüedad) no vuelve a pedir.
    func requestIfNeeded() {
        guard coordinate == nil, !isLocating, !permissionDenied else { return }
        locate()
    }

    /// Fuerza una nueva lectura aunque ya tengamos coordenadas.
    func refresh() {
        locate()
    }

    // MARK: - Privado

    private func locate() {
        isLocating = true
        manager.requestOnce { [weak self] coord, name in
            guard let self else { return }
            self.isLocating = false
            if let coord {
                self.coordinate = coord
                self.cityName   = name
                self.permissionDenied = false
            } else {
                self.permissionDenied = (name == "Ubicación no disponible")
            }
        }
    }
}

// MARK: - EnvironmentKey

import SwiftUI

private struct LocationStoreKey: EnvironmentKey {
    static let defaultValue = LocationStore.shared
}

extension EnvironmentValues {
    var locationStore: LocationStore {
        get { self[LocationStoreKey.self] }
        set { self[LocationStoreKey.self] = newValue }
    }
}
