import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "ScreenUnlockService")

@MainActor
final class ScreenUnlockService: ObservableObject {

    static let shared = ScreenUnlockService()

    @Published var hasUnlockedToday: Bool = false

    var onFirstUnlockOfDay: (() -> Void)?

    private var lastUnlockDate: Date? = nil

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataDidBecomeAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }

    @objc private func protectedDataDidBecomeAvailable() {
        FileLogger.shared.assertMainThread()
        let today = Calendar.current.startOfDay(for: Date())
        guard lastUnlockDate == nil || Calendar.current.startOfDay(for: lastUnlockDate!) < today else { return }
        lastUnlockDate = Date()
        hasUnlockedToday = true
        logger.info("First screen unlock of the day")
        onFirstUnlockOfDay?()

        // Reset flag at midnight
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let delay = tomorrow.timeIntervalSinceNow
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.hasUnlockedToday = false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
