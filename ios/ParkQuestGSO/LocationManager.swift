//
//  LocationManager.swift
//  ParkQuestGSO
//

import CoreLocation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Public state
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // Within this distance (meters) counts as "at" a quest location.
    static let checkInRadius: CLLocationDistance = 100

    // MARK: - Private
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        // Resume updates if we already have permission (app re-launch).
        if isAuthorized { manager.startUpdatingLocation() }
    }

    // MARK: - Public API

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Distance in meters from the current location to `coordinate`, or nil
    /// if location is unavailable.
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let loc = currentLocation else { return nil }
        return loc.distance(from: CLLocation(latitude: coordinate.latitude,
                                             longitude: coordinate.longitude))
    }

    /// True when the user is within `checkInRadius` meters of `coordinate`.
    func isNear(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let d = distance(to: coordinate) else { return false }
        return d <= Self.checkInRadius
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized { manager.startUpdatingLocation() }
    }
}
