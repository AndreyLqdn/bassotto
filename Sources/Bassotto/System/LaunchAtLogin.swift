import ServiceManagement

/// "Open at login" via the system login items (System Settings → General → Login Items).
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns the resulting state, which may differ if the user must approve it in Settings.
    @MainActor
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Bassotto: login item change failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
