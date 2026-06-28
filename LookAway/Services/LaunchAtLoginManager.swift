import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return true }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered { return true }
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("Launch at login error: \(error.localizedDescription)")
            return false
        }
    }

    static func syncWithConfig(_ shouldEnable: Bool) {
        let currentlyEnabled = isEnabled
        if shouldEnable != currentlyEnabled {
            _ = setEnabled(shouldEnable)
        }
    }
}
