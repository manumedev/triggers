import Foundation

/// Writes timestamped log lines to Documents/triggers.log.
/// Accessible via Files app → On My iPhone → Triggers → triggers.log
/// Thread-safe: can be called from any queue or actor.
final class FileLogger: @unchecked Sendable {

    static let shared = FileLogger()

    private let queue = DispatchQueue(label: "com.triggers.filelog", qos: .background)
    private let fileURL: URL
    private let dateFormatter: DateFormatter

    private static let mainQueueKey = DispatchSpecificKey<Void>()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("triggers.log")
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        // Tag the main dispatch queue so we can detect it from any thread
        DispatchQueue.main.setSpecific(key: Self.mainQueueKey, value: ())
        rotateIfNeeded()
        log("──── Session started ────")
    }

    func log(_ message: String, category: String = "App") {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(category)] \(message)\n"
        // Synchronous write — ensures log survives even if app crashes immediately after
        queue.sync { [weak self] in
            self?.append(line: line)
        }
    }

    /// Call at the start of any function that MUST run on the main dispatch queue.
    /// Logs a warning (with full call stack) if called from wrong thread OR wrong queue.
    /// Note: Thread.isMainThread can be true while dispatch_assert_queue(main) fails —
    /// this method checks both to catch the exact scenario causing _dispatch_assert_queue_fail.
    func assertMainThread(_ context: String = #function, file: String = #file, line: Int = #line) {
        let onMainThread = Thread.isMainThread
        let onMainQueue  = DispatchQueue.getSpecific(key: Self.mainQueueKey) != nil
        guard onMainThread && onMainQueue else {
            let frames = Thread.callStackSymbols.prefix(16).joined(separator: "\n    ")
            let shortFile = (file as NSString).lastPathComponent
            log("⚠️ QUEUE VIOLATION: \(context) [\(shortFile):\(line)] isMainThread=\(onMainThread) isMainQueue=\(onMainQueue)\n    \(frames)", category: "QueueViolation")
            return
        }
    }

    private func append(line: String) {
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func rotateIfNeeded() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let size = attrs?[.size] as? Int, size > 2_000_000 {
            let archiveURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("triggers-prev.log")
            try? FileManager.default.removeItem(at: archiveURL)
            try? FileManager.default.moveItem(at: fileURL, to: archiveURL)
        }
    }
}
