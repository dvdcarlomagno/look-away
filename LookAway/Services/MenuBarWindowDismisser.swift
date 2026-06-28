import AppKit

enum MenuBarWindowDismisser {
    @MainActor
    static func closeIfOpen() {
        for window in NSApplication.shared.windows where window.isVisible {
            let typeName = String(describing: type(of: window))
            if typeName.contains("MenuBarExtra") {
                window.orderOut(nil)
            }
        }
    }
}
