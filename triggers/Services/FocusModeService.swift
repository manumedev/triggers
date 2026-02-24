import Foundation
import UIKit
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.triggers.app", category: "FocusModeService")

@MainActor
final class FocusModeService: ObservableObject {

    static let shared = FocusModeService()

    @Published var isFocusActive: Bool = false

    var onFocusEnter: (() -> Void)?
    var onFocusExit: (() -> Void)?

    private init() {
        // Observe changes to notification settings which reflect Focus changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationSettingsChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        checkFocusStatus()
    }

    private func checkFocusStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let newState = settings.notificationCenterSetting == .disabled ||
                           settings.alertSetting == .disabled
            await MainActor.run {
                let changed = newState != self.isFocusActive
                self.isFocusActive = newState
                if changed {
                    if newState {
                        logger.info("Focus mode entered")
                        self.onFocusEnter?()
                    } else {
                        logger.info("Focus mode exited")
                        self.onFocusExit?()
                    }
                }
            }
        }
    }

    @objc private func notificationSettingsChanged() {
        checkFocusStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
