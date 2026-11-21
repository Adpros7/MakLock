import AppKit
import Foundation

@main
enum WatchProximityFeatureTests {
  static func main() throws {
    try preservesExistingSettingsWhenRangeLockSettingIsMissing()
    locksOnlyAfterSustainedWeakSignal()
    ignoresTransientWeakSignal()
    locksAfterContinuousSignalAbsence()
    locksOnSwitchWhenRangeLockIsEnabled()
    usesProtectedAppWindowBounds()
  }

  private static func preservesExistingSettingsWhenRangeLockSettingIsMissing() throws {
    let existingSettings = """
      {
        "isProtectionEnabled": false,
        "lockOnSleep": false,
        "lockOnIdle": true,
        "idleTimeoutMinutes": 10,
        "requireAuthOnLaunch": false,
        "requireAuthOnActivate": true,
        "useWatchUnlock": true,
        "watchRssiThreshold": -63,
        "inactiveCloseMinutes": 25,
        "launchAtLogin": true
      }
      """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: existingSettings)
    expect(settings.useWatchUnlock, "existing watch-unlock preference must survive migration")
    expect(settings.watchRssiThreshold == -63, "existing RSSI threshold must survive migration")
    expect(!settings.lockWhenWatchLeavesRange, "range locking must default off for existing users")
  }

  private static func locksOnlyAfterSustainedWeakSignal() {
    var monitor = WatchRangeMonitor(rssiThreshold: -70, staleInterval: 15)
    let start = Date(timeIntervalSinceReferenceDate: 0)

    expect(monitor.record(rssi: -60, at: start) == .enteredRange, "strong signal must enter range")
    expect(
      monitor.record(rssi: -71, at: start.addingTimeInterval(2)) == nil,
      "first weak reading must not lock")
    expect(
      monitor.record(rssi: -71, at: start.addingTimeInterval(4)) == nil,
      "second weak reading must not lock")
    expect(
      monitor.record(rssi: -71, at: start.addingTimeInterval(6)) == .exitedRange,
      "third weak reading must lock")
  }

  private static func ignoresTransientWeakSignal() {
    var monitor = WatchRangeMonitor(rssiThreshold: -70, staleInterval: 15)
    let start = Date(timeIntervalSinceReferenceDate: 0)

    _ = monitor.record(rssi: -60, at: start)
    _ = monitor.record(rssi: -71, at: start.addingTimeInterval(2))
    _ = monitor.record(rssi: -71, at: start.addingTimeInterval(4))
    expect(
      monitor.record(rssi: -60, at: start.addingTimeInterval(6)) == nil,
      "strong signal must cancel a pending range loss")
    expect(monitor.isInRange, "transient weak readings must preserve in-range state")
  }

  private static func locksAfterContinuousSignalAbsence() {
    var monitor = WatchRangeMonitor(rssiThreshold: -70, staleInterval: 15)
    let start = Date(timeIntervalSinceReferenceDate: 0)

    _ = monitor.record(rssi: -60, at: start)
    expect(
      monitor.evaluateStaleness(at: start.addingTimeInterval(14)) == nil,
      "grace period must not lock")
    expect(
      monitor.evaluateStaleness(at: start.addingTimeInterval(15)) == .exitedRange,
      "sustained signal absence must lock")
    expect(
      monitor.evaluateStaleness(at: start.addingTimeInterval(20)) == nil,
      "range loss must emit once")
  }

  private static func locksOnSwitchWhenRangeLockIsEnabled() {
    var settings = AppSettings()
    settings.requireAuthOnLaunch = false
    settings.requireAuthOnActivate = false
    settings.lockWhenWatchLeavesRange = true

    expect(
      !AppLockPolicy.requiresAuthentication(for: .launch, settings: settings),
      "range lock must not change launch policy")
    expect(
      AppLockPolicy.requiresAuthentication(for: .activation, settings: settings),
      "range lock must require authentication after every app switch")
  }

  private static func usesProtectedAppWindowBounds() {
    let protectedAppFrame = NSRect(x: 100, y: 100, width: 700, height: 500)
    let panel = LockOverlayWindow(frame: protectedAppFrame)

    expect(
      panel.frame.equalTo(protectedAppFrame),
      "the lock shield must match the protected app window")
    expect(
      panel.level.rawValue == NSWindow.Level.normal.rawValue + 1,
      "the lock shield must stay one level above the protected app, not above the desktop")
  }

  private static func expect(_ condition: Bool, _ message: String) {
    precondition(condition, message)
  }
}
