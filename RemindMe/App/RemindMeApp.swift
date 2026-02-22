import SwiftUI
import SwiftData
import UserNotifications
import Darwin

@main
struct RemindMeApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(PersistenceService.shared)
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        installCrashHandler()
        FileLogger.shared.log("AppDelegate: didFinishLaunching", category: "Startup")
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        let context = PersistenceService.shared.mainContext
        RuleEvaluationEngine.shared.start(modelContext: context)
        LocationService.shared.setupBackgroundMonitoring()

        Task {
            _ = await NotificationService.shared.requestAuthorization()
            LocationService.shared.requestAlwaysAuthorization()
        }
        FileLogger.shared.log("AppDelegate: ready", category: "Startup")
        return true
    }

    /// Called by iOS on background fetch wakeup — NWPathMonitor will re-evaluate and fire
    /// events if WiFi state changed while the app was suspended (via UserDefaults comparison).
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        FileLogger.shared.log("Background fetch wakeup", category: "Startup")
        // WiFiMonitorService.startMonitoring() runs on init — it will detect any WiFi change
        // against the persisted last-known state and fire onSSIDEvent automatically.
        completionHandler(.newData)
    }
}

// MARK: - Notification Delegate (non-isolated)

// MARK: - Crash Handler

/// Pre-computed crash log path (populated before any crash can occur).
nonisolated(unsafe) private var gCrashLogPath: UnsafeMutablePointer<CChar>? = nil

/// Installs a SIGABRT handler that writes a full backtrace to crash_stack.log
/// before re-raising so the OS can record the crash normally.
private func installCrashHandler() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let path = docs.appendingPathComponent("crash_stack.log").path
    // strdup copies the path into C-heap memory safe to use from signal handler
    gCrashLogPath = strdup(path)

    signal(SIGABRT) { _ in
        let path = gCrashLogPath
        var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
        let count = backtrace(&frames, Int32(frames.count))
        if let path {
            let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
            if fd >= 0 {
                let header = "SIGABRT backtrace:\n"
                header.withCString { ptr in _ = write(fd, ptr, strlen(ptr)) }
                backtrace_symbols_fd(&frames, count, fd)
                close(fd)
            }
        }
        signal(SIGABRT, SIG_DFL)
        raise(SIGABRT)
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationDelegate()
    private override init() {}

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
