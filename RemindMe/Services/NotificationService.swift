import Foundation
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.remindme.app", category: "NotificationService")

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification permission granted: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Fire

    /// Immediately fires a local notification for the given rule.
    func fire(rule: Rule) async {
        guard rule.isEnabled else { return }
        guard rule.canFire() else {
            logger.debug("Rule '\(rule.name)' skipped — repeat behavior not satisfied")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = rule.notificationTitle.isEmpty ? rule.name : rule.notificationTitle
        content.body = rule.notificationBody
        content.sound = .default
        content.userInfo = ["ruleId": rule.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "\(rule.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil   // deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            rule.lastFiredAt = Date()
            logger.info("Fired notification for rule '\(rule.name)'")
            FileLogger.shared.log("🔔 FIRED: '\(rule.name)'", category: "Notify")
        } catch {
            logger.error("Failed to deliver notification for rule '\(rule.name)': \(error)")
            FileLogger.shared.log("❌ FAILED: '\(rule.name)' — \(error)", category: "Notify")
        }
    }

    // MARK: - Pending / cleanup

    func removePendingNotifications(for ruleId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ruleId.uuidString])
    }
}
