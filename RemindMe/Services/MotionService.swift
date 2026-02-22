import Foundation
import CoreMotion
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "MotionService")

enum DetectedActivity: Equatable {
    case stationary, walking, running, automotive, cycling, unknown
}

@MainActor
final class MotionService: ObservableObject {

    static let shared = MotionService()

    private let activityManager = CMMotionActivityManager()
    private let activityQueue = OperationQueue()  // background queue for CMMotionActivityManager

    @Published var currentActivity: DetectedActivity = .unknown

    /// Fires when the detected activity changes
    var onActivityChanged: ((DetectedActivity) -> Void)?

    private init() {}

    // MARK: - Authorization

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    func startMonitoring() {
        guard isAvailable else {
            logger.warning("Motion activity not available on this device")
            return
        }

        activityManager.startActivityUpdates(to: activityQueue) { @Sendable [weak self] activity in
            guard let activity else { return }
            guard activity.confidence != .low else { return }
            // Compute DetectedActivity (Sendable enum) before hopping to MainActor
            let detected: DetectedActivity
            if activity.automotive      { detected = .automotive }
            else if activity.walking    { detected = .walking }
            else if activity.running    { detected = .running }
            else if activity.cycling    { detected = .cycling }
            else if activity.stationary { detected = .stationary }
            else                        { detected = .unknown }
            Task { @MainActor [weak self] in
                self?.handle(detected: detected)
            }
        }
        logger.info("Motion monitoring started")
    }

    func stopMonitoring() {
        activityManager.stopActivityUpdates()
    }

    // MARK: - Private

    private func handle(detected: DetectedActivity) {
        guard detected != currentActivity else { return }
        let previous = currentActivity
        currentActivity = detected
        logger.info("Activity changed: \(String(describing: previous)) → \(String(describing: detected))")
        onActivityChanged?(detected)
    }
}
