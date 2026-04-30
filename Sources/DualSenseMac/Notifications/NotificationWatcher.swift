import Foundation
import SQLite3

/// Polls the macOS Notification Center SQLite database to detect newly
/// delivered notifications from any app, and fires a callback for each batch.
///
/// macOS does not expose a public API for observing system-wide notifications.
/// The Notification Center daemon (`usernotificationsd` /  the older
/// `notificationcenterui`) writes every delivered notification to a SQLite
/// file at:
///
/// ```
/// ~/Library/Group Containers/group.com.apple.usernoted/db2/db
/// ```
///
/// That file lives behind the Full Disk Access TCC gate. Our app must be
/// added to System Settings → Privacy & Security → Full Disk Access for
/// reads to succeed. `hasFullDiskAccess()` returns `true` iff we can open
/// the DB.
///
/// We poll once per second, query for `delivered_date > lastSeen`, and call
/// the callback if the count is nonzero. Polling at 1 Hz is the minimum
/// useful resolution for a "vibrate on notification" UX — sub-second
/// resolution would only matter for true real-time use cases.
@MainActor
final class NotificationWatcher {
    /// Path to the macOS Notification Center DB. Stable across macOS 11–26.
    static let dbPath: String = {
        let home = NSHomeDirectory()
        return "\(home)/Library/Group Containers/group.com.apple.usernoted/db2/db"
    }()

    private var db: OpaquePointer?
    private var stmt: OpaquePointer?
    private var timer: Timer?
    private var lastSeen: Double = Date().timeIntervalSinceReferenceDate
    private(set) var isRunning = false

    /// Fires once for each batch of new notifications detected. The Int is
    /// the number of new records since the last poll.
    var onNewNotifications: ((Int) -> Void)?

    deinit {
        // Synchronous teardown of SQLite handles — actor-isolated stop()
        // can't be called from deinit, so finalize directly.
        if let stmt = stmt { sqlite3_finalize(stmt) }
        if let db = db { sqlite3_close(db) }
    }

    /// Returns true iff the Notification Center DB is currently readable
    /// from this process. False usually means our app has not been granted
    /// Full Disk Access in System Settings.
    static func hasFullDiskAccess() -> Bool {
        var probe: OpaquePointer?
        let result = sqlite3_open_v2(dbPath, &probe, SQLITE_OPEN_READONLY, nil)
        if let probe = probe { sqlite3_close(probe) }
        return result == SQLITE_OK
    }

    func start() {
        guard !isRunning else { return }
        guard openDB() else {
            NSLog("NotificationWatcher: failed to open NC DB — needs Full Disk Access")
            return
        }
        isRunning = true
        // Set baseline to "now" so we don't fire for notifications that
        // arrived before we started watching.
        lastSeen = Date().timeIntervalSinceReferenceDate
        NSLog("NotificationWatcher: started; baseline=%.0f", lastSeen)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let stmt = stmt { sqlite3_finalize(stmt); self.stmt = nil }
        if let db = db { sqlite3_close(db); self.db = nil }
        isRunning = false
        NSLog("NotificationWatcher: stopped")
    }

    // MARK: - Private

    private func openDB() -> Bool {
        var handle: OpaquePointer?
        let openResult = sqlite3_open_v2(Self.dbPath, &handle, SQLITE_OPEN_READONLY, nil)
        guard openResult == SQLITE_OK, let handle = handle else {
            if let handle = handle { sqlite3_close(handle) }
            return false
        }
        self.db = handle

        // Prepare a statement we'll reuse on every poll. The query asks for
        // the count of records with delivered_date strictly greater than
        // our baseline, plus the new max — so we can advance the baseline.
        // Using parameter binding to avoid format-string issues with the
        // double timestamp.
        let sql = "SELECT COUNT(*), COALESCE(MAX(delivered_date), 0) FROM record WHERE delivered_date > ?"
        var prepared: OpaquePointer?
        let prepResult = sqlite3_prepare_v2(handle, sql, -1, &prepared, nil)
        if prepResult != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(handle))
            NSLog("NotificationWatcher: sqlite3_prepare_v2 failed: %@", msg)
            sqlite3_close(handle)
            self.db = nil
            return false
        }
        self.stmt = prepared
        return true
    }

    private func poll() {
        guard let stmt = stmt else { return }
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        sqlite3_bind_double(stmt, 1, lastSeen)

        let stepResult = sqlite3_step(stmt)
        guard stepResult == SQLITE_ROW else {
            if stepResult != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                NSLog("NotificationWatcher.poll: step failed: %@", msg)
            }
            return
        }

        let count = sqlite3_column_int(stmt, 0)
        let maxDate = sqlite3_column_double(stmt, 1)

        if count > 0 {
            NSLog("NotificationWatcher: %d new notification(s) detected", count)
            lastSeen = max(lastSeen, maxDate)
            onNewNotifications?(Int(count))
        }
    }
}
