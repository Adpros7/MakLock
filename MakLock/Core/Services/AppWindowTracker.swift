import AppKit
import ApplicationServices

/// Reads the frontmost protected app window through the user-approved Accessibility API.
final class AppWindowTracker {
    static let shared = AppWindowTracker()

    private init() {}

    func frame(for bundleIdentifier: String) -> NSRect? {
        guard AXIsProcessTrusted() else {
            requestAccess()
            return nil
        }
        guard
            let runningApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleIdentifier
            })
        else { return nil }

        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedWindowAttribute as CFString,
                &focusedWindow
            ) == .success,
            let focusedWindow
        else { return nil }

        let windowElement = unsafeBitCast(focusedWindow, to: AXUIElement.self)
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                windowElement,
                kAXPositionAttribute as CFString,
                &positionValue
            ) == .success,
            AXUIElementCopyAttributeValue(
                windowElement,
                kAXSizeAttribute as CFString,
                &sizeValue
            ) == .success,
            let positionValue,
            let sizeValue
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(
                unsafeBitCast(positionValue, to: AXValue.self),
                .cgPoint,
                &position
            ),
            AXValueGetValue(
                unsafeBitCast(sizeValue, to: AXValue.self),
                .cgSize,
                &size
            )
        else { return nil }

        let desktopTop = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        return NSRect(
            x: position.x,
            y: desktopTop - position.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func requestAccess() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
