// LocationManager.swift — pide permisos y obtiene una ubicación puntual
import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?, String) -> Void)?
    private var isRequesting = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Solicita una sola lectura de ubicación y llama al callback con coord + nombre de ciudad
    func requestOnce(completion: @escaping (CLLocationCoordinate2D?, String) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isRequesting = true
            manager.requestLocation()
        default:
            completion(nil, "Ubicación no disponible")
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            isRequesting = true
            manager.requestLocation()
        } else if status != .notDetermined {
            completion?(nil, "Ubicación no disponible")
            completion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        let coord = loc.coordinate
        // Reverse geocode
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let name = placemarks?.first.flatMap {
                [$0.locality, $0.administrativeArea].compactMap { $0 }.first
            } ?? "Mi ubicación"
            DispatchQueue.main.async {
                self?.completion?(coord, name)
                self?.completion = nil
                self?.isRequesting = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil, "Ubicación no disponible")
        completion = nil
        isRequesting = false
    }
}
