//
//  LocationProvider.swift
//  Engineering Notebook
//
//  Thin async wrapper around CoreLocation for capturing a one-shot location,
//  plus reverse geocoding to a friendly place name.
//

import Foundation
import CoreLocation

@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var authorizationStatus: CLAuthorizationStatus

    /// A pending one-shot location request, resumed by delegate callbacks.
    private var continuation: CheckedContinuation<CLLocation, Error>?
    /// True when we're waiting on the user's authorization decision before we
    /// can start locating.
    private var awaitingAuthorization = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// Requests the device's current location, prompting for permission if needed.
    func requestCurrentLocation() async throws -> CLLocation {
        // Only one outstanding request at a time.
        if continuation != nil {
            throw CLError(.locationUnknown)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            switch authorizationStatus {
            case .notDetermined:
                awaitingAuthorization = true
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                finish(with: .failure(CLError(.denied)))
            }
        }
    }

    /// Reverse geocodes a location into a short place description, if possible.
    func placeName(for location: CLLocation) async -> String? {
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }
        let parts = [placemark.name, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard awaitingAuthorization else { return }

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            awaitingAuthorization = false
            manager.requestLocation()
        case .denied, .restricted:
            awaitingAuthorization = false
            finish(with: .failure(CLError(.denied)))
        case .notDetermined:
            break // still waiting on the user
        @unknown default:
            awaitingAuthorization = false
            finish(with: .failure(CLError(.denied)))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        finish(with: .success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
