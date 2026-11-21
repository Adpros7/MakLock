import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService {
  static let shared = OverlayWindowService()

  private var overlayWindows: [LockOverlayWindow] = []
  private var timeoutTimer: Timer?
  private var trackingTimer: Timer?
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

  /// Shield the active protected app's focused window.
  func show(for app: ProtectedApp) {
    guard overlayWindows.isEmpty else { return }
    guard let frame = AppWindowTracker.shared.frame(for: app.bundleIdentifier) else {
      NSLog("[MakLock] Accessibility frame unavailable for: %@", app.name)
      return
    }

    currentApp = app
    createOverlayWindows(for: app, frame: frame)
    startWindowTracking()
    startTimeoutTimer()

    NSLog("[MakLock] Window shield shown for: %@", app.name)
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

  /// Restore a protected app after successful authentication.
  func hide() {
    stopTimeoutTimer()
    stopWindowTracking()
    AuthenticationService.shared.cancelAuthentication()

    if let app = currentApp {
      AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)
    }

    closeWindows()

    if let bundleID = currentApp?.bundleIdentifier {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
        self?.activateProtectedApp(bundleIdentifier: bundleID)
      }
    }

    currentApp = nil
    NSLog("[MakLock] Window shield dismissed after authentication")
  }

  /// Dismiss a cancelled shield and keep its protected app hidden.
  func cancel() {
    stopTimeoutTimer()
    stopWindowTracking()
    AuthenticationService.shared.cancelAuthentication()

    if let app = currentApp {
      lock(app)
    }

    closeWindows()
    currentApp = nil
    NSLog("[MakLock] Window shield cancelled")
  }

  /// Dismiss the active lock shield without authenticating.
  func dismissAll() {
    cancel()
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

  @objc private func screensDidChange(_ notification: Notification) {
    updateWindowShieldFrame()
  }

  private func createOverlayWindows(for app: ProtectedApp, frame: NSRect) {
    let window = LockOverlayWindow(frame: frame)
    let lockView = LockOverlayView(
      appName: app.name,
      bundleIdentifier: app.bundleIdentifier,
      isPrimary: true,
      onDismiss: { [weak self] in
        let name = self?.currentApp?.name ?? "app"
        self?.hide()
        self?.onUnlocked?(name)
      },
      onCancel: { [weak self] in
        self?.cancel()
      }
    )

    window.contentView = NSHostingView(rootView: lockView)
    window.orderFrontRegardless()
    overlayWindows = [window]
  }

  private func startWindowTracking() {
    trackingTimer?.invalidate()
    trackingTimer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
      self?.updateWindowShieldFrame()
    }
    RunLoop.main.add(trackingTimer!, forMode: .common)
  }

  private func stopWindowTracking() {
    trackingTimer?.invalidate()
    trackingTimer = nil
  }

  private func updateWindowShieldFrame() {
    guard let app = currentApp else { return }
    guard
      NSWorkspace.shared.runningApplications.contains(where: {
        $0.bundleIdentifier == app.bundleIdentifier
      })
    else {
      cancel()
      return
    }
    guard let frame = AppWindowTracker.shared.frame(for: app.bundleIdentifier),
      let window = overlayWindows.first
    else { return }

    window.reposition(to: frame)
  }

  private func closeWindows() {
    overlayWindows.forEach { $0.close() }
    overlayWindows.removeAll()
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
