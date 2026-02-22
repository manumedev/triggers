import Foundation
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "LocationService")

/// Maximum number of simultaneous geofence regions iOS allows.
let kMaxGeofenceRegions = 20

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var monitoredRegionCount: Int = 0

    /// Fires with region identifier and whether it was an entry (true) or exit (false)
    var onRegionEvent: ((String, Bool) -> Void)?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 50
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        monitoredRegionCount = manager.monitoredRegions.count
    }

    // MARK: - Authorization

    /// Call on every launch to ensure background monitoring is running.
    func setupBackgroundMonitoring() {
        let status = manager.authorizationStatus
        logger.info("setupBackgroundMonitoring: auth=\(status.rawValue), monitoredRegions=\(self.manager.monitoredRegions.count)")
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startMonitoringSignificantLocationChanges()
            logger.info("startMonitoringSignificantLocationChanges started")
        }
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - CLLocationManagerDelegate (auth change)
    // startMonitoringSignificantLocationChanges called here so it begins as soon as permission granted

    // MARK: - Geofencing

    func startMonitoring(place: SavedPlace) {
        let region = circularRegion(for: place)
        manager.startMonitoring(for: region)
        monitoredRegionCount = manager.monitoredRegions.count
        logger.info("Started monitoring region '\(place.name)' id=\(place.id)")
    }

    func stopMonitoring(place: SavedPlace) {
        let regionId = place.id.uuidString
        for region in manager.monitoredRegions where region.identifier == regionId {
            manager.stopMonitoring(for: region)
        }
        monitoredRegionCount = manager.monitoredRegions.count
        logger.info("Stopped monitoring region '\(place.name)'")
    }

    func stopAllMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        monitoredRegionCount = 0
    }

    var isAtCapacity: Bool { monitoredRegionCount >= kMaxGeofenceRegions }

    // MARK: - Current location

    func requestCurrentLocation() {
        manager.requestLocation()
    }

    // MARK: - Private helpers

    private func circularRegion(for place: SavedPlace) -> CLCircularRegion {
        let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        // iOS minimum reliable geofence is ~100 m; cap at hardware maximum
        let clampedRadius = min(max(place.radius, 100), manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: place.id.uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit  = true
        return region
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        logger.info("didEnterRegion: \(id)")
        Task { @MainActor in
            self.onRegionEvent?(id, true)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let id = region.identifier
        logger.info("didExitRegion: \(id)")
        Task { @MainActor in
            self.onRegionEvent?(id, false)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        logger.info("authorizationStatus changed: \(status.rawValue)")
        FileLogger.shared.assertMainThread("locationManagerDidChangeAuthorization")
        FileLogger.shared.log("Location auth changed: \(status.rawValue), isMain=\(Thread.isMainThread)", category: "Location")
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.manager.startMonitoringSignificantLocationChanges()
                logger.info("startMonitoringSignificantLocationChanges started after auth grant")
                FileLogger.shared.log("startMonitoringSignificantLocationChanges started", category: "Location")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error)")
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        logger.error("Geofence monitoring failed for \(region?.identifier ?? "unknown"): \(error)")
    }
}
