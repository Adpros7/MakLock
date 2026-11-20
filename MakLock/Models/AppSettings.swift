import Foundation

/// Persisted user preferences.
struct AppSettings: Codable {
    /// Whether MakLock protection is globally active.
    var isProtectionEnabled: Bool = true

    /// Lock apps when the Mac goes to sleep.
    var lockOnSleep: Bool = true

    /// Lock apps after idle timeout.
    var lockOnIdle: Bool = false

    /// Idle timeout in minutes before auto-lock triggers.
    var idleTimeoutMinutes: Int = 5

    /// Require authentication when a protected app is launched.
    var requireAuthOnLaunch: Bool = true

    /// Require authentication when switching to a protected app.
    var requireAuthOnActivate: Bool = false

    /// Use Apple Watch proximity for auto-unlock.
    var useWatchUnlock: Bool = false

    /// Lock protected apps after a sustained Apple Watch range loss.
    var lockWhenWatchLeavesRange: Bool = false

    /// Watch RSSI threshold for proximity detection.
    /// Default: -70 dBm (~2-3 meters). Higher (less negative) = stricter.
    var watchRssiThreshold: Int = -70

    /// Inactivity timeout (minutes) before auto-closing protected apps that have autoClose enabled.
    var inactiveCloseMinutes: Int = 15

    /// Launch MakLock at login.
    var launchAtLogin: Bool = false

    private enum CodingKeys: String, CodingKey {
        case isProtectionEnabled
        case lockOnSleep
        case lockOnIdle
        case idleTimeoutMinutes
        case requireAuthOnLaunch
        case requireAuthOnActivate
        case useWatchUnlock
        case lockWhenWatchLeavesRange
        case watchRssiThreshold
        case inactiveCloseMinutes
        case launchAtLogin
    }

    init() {}

    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isProtectionEnabled =
            try values.decodeIfPresent(Bool.self, forKey: .isProtectionEnabled)
            ?? isProtectionEnabled
        lockOnSleep = try values.decodeIfPresent(Bool.self, forKey: .lockOnSleep) ?? lockOnSleep
        lockOnIdle = try values.decodeIfPresent(Bool.self, forKey: .lockOnIdle) ?? lockOnIdle
        idleTimeoutMinutes =
            try values.decodeIfPresent(Int.self, forKey: .idleTimeoutMinutes) ?? idleTimeoutMinutes
        requireAuthOnLaunch =
            try values.decodeIfPresent(Bool.self, forKey: .requireAuthOnLaunch)
            ?? requireAuthOnLaunch
        requireAuthOnActivate =
            try values.decodeIfPresent(Bool.self, forKey: .requireAuthOnActivate)
            ?? requireAuthOnActivate
        useWatchUnlock =
            try values.decodeIfPresent(Bool.self, forKey: .useWatchUnlock) ?? useWatchUnlock
        lockWhenWatchLeavesRange =
            try values.decodeIfPresent(Bool.self, forKey: .lockWhenWatchLeavesRange)
            ?? lockWhenWatchLeavesRange
        watchRssiThreshold =
            try values.decodeIfPresent(Int.self, forKey: .watchRssiThreshold) ?? watchRssiThreshold
        inactiveCloseMinutes =
            try values.decodeIfPresent(Int.self, forKey: .inactiveCloseMinutes)
            ?? inactiveCloseMinutes
        launchAtLogin =
            try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
    }
}
