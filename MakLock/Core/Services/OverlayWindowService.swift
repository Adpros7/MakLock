import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService {
  static let shared = OverlayWindowService()

  private var overlayWindows: [LockOverlayWindow] = []
  private var timeoutTimer: Timer?
  private var currentApp: ProtectedApp?

  /// Callback when overlay is dismissed after successful authentication.
  /// Passes the name of the unlocked app.
  var onUnlocked: ((String) -> Void)?

  private init() {
    // Observe screen configuration changes (connect/disconnect monitors)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screensDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  /// Show a compact authentication panel after a protected app is reopened.
  func show(for app: ProtectedApp) {
    guard overlayWindows.isEmpty else { return }

    currentApp = app
    lock(app)
    createOverlayWindows(for: app)
    startTimeoutTimer()

    NSLog("[MakLock] Lock panel shown for: %@", app.name)
  }

  /// Hide a protected app without presenting any full-screen UI.
  func lock(_ app: ProtectedApp) {
    guard
      let runningApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == app.bundleIdentifier
      })
    else { return }

    runningApp.hide()
    NSLog("[MakLock] Protected app hidden: %@", app.name)
  }

  /// Hide all overlay windows.
  func hide() {
    stopTimeoutTimer()

    // Cancel any in-progress Touch ID evaluation
    AuthenticationService.shared.cancelAuthentication()

    // Mark the app as authenticated so it won't re-lock immediately
    if let app = currentApp {
      AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)
    }

    overlayWindows.forEach { $0.close() }
    overlayWindows.removeAll()

    // Activate the protected app now that overlays are gone.
    // Small delay ensures overlay panels and Touch ID dialog are fully dismissed
    // before attempting to bring the app forward.
    if let bundleID = currentApp?.bundleIdentifier {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
        self?.activateProtectedApp(bundleIdentifier: bundleID)
      }
    }

    currentApp = nil
    NSLog("[MakLock] Overlay dismissed")
  }

  /// Dismiss all overlays (used by panic key).
  func dismissAll() {
    hide()
  }

  /// Whether an overlay is currently displayed.
  var isShowing: Bool {
    !overlayWindows.isEmpty
  }

  /// Bundle identifier of the currently locked app (if any).
  var currentBundleIdentifier: String? {
    currentApp?.bundleIdentifier
  }

  /// Display name of the currently locked app (if any).
  var currentAppName: String? {
    currentApp?.name
  }

  /// During Touch ID: pass through mouse events so system dialog gets interaction.
  /// After auth: restore mouse capture for overlay blocking.
  func setTouchIDMode(_ active: Bool) {
    for window in overlayWindows {
      window.ignoresMouseEvents = active
    }
  }

  /// Enable key window status on overlay windows (needed for password input).
  func enableKeyboardInput() {
    setTouchIDMode(false)
    for window in overlayWindows {
      window.allowKeyStatus = true
      window.makeKeyAndOrderFront(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - Screen Management

  @objc private func screensDidChange(_ notification: Notification) {
    guard let lockWindow = overlayWindows.first,
      let screen = NSScreen.main ?? NSScreen.screens.first
    else { return }

    lockWindow.reposition(to: screen)
  }

  private func createOverlayWindows(for app: ProtectedApp) {
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

    let window = LockOverlayWindow(for: screen)
    let lockView = LockOverlayView(
      appName: app.name,
      bundleIdentifier: app.bundleIdentifier,
      isPrimary: true,
      onDismiss: { [weak self] in
        let name = self?.currentApp?.name ?? "app"
        self?.hide()
        self?.onUnlocked?(name)
      }
    )

    window.contentView = NSHostingView(rootView: lockView)
    window.orderFrontRegardless()
    overlayWindows = [window]
  }

  // MARK: - App Window Management

  /// Bring the protected app to the foreground after successful auth.
  /// Only activates if the app is already running — never launches a closed app.
  private func activateProtectedApp(bundleIdentifier: String) {
    guard
      let app = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == bundleIdentifier
      })
    else {
      NSLog("[MakLock] App not running, skipping activation: %@", bundleIdentifier)
      return
    }
    app.activate()
    NSLog("[MakLock] Activated app: %@", bundleIdentifier)
  }

  // MARK: - Timeout

  private func startTimeoutTimer() {
    let timeout =
      SafetyManager.isDevMode
      ? SafetyManager.devModeTimeout
      : SafetyManager.overlayTimeout

    timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) {
      [weak self] _ in
      NSLog("[MakLock Safety] Overlay timeout reached (%.0fs) — auto-dismissing", timeout)
      self?.hide()
    }
  }

  private func stopTimeoutTimer() {
    timeoutTimer?.invalidate()
    timeoutTimer = nil
  }

}
