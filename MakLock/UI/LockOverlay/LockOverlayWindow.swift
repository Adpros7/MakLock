import AppKit

/// Compact lock panel for a protected app.
/// Uses NSPanel with .nonactivatingPanel so the system Touch ID dialog keeps focus.
final class LockOverlayWindow: NSPanel {
    private static let size = NSSize(width: 440, height: 460)

    init(for screen: NSScreen) {
        super.init(
            contentRect: Self.frame(on: screen),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.isMovableByWindowBackground = true
    }

    /// Keep the compact panel centered when displays change.
    func reposition(to screen: NSScreen) {
        setFrame(Self.frame(on: screen), display: true)
    }

    /// Whether the panel should accept key status.
    /// Disabled during Touch ID (system dialog needs focus), enabled for password input.
    var allowKeyStatus = false

    override var canBecomeKey: Bool { allowKeyStatus }
    override var canBecomeMain: Bool { false }

    private static func frame(on screen: NSScreen) -> NSRect {
        NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
