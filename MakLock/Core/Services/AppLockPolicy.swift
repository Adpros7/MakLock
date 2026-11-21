import Foundation

enum AppLockEvent {
    case launch
    case activation
}

enum AppLockPolicy {
    static func requiresAuthentication(for event: AppLockEvent, settings: AppSettings) -> Bool {
        switch event {
        case .launch:
            settings.requireAuthOnLaunch
        case .activation:
            settings.requireAuthOnActivate || settings.lockWhenWatchLeavesRange
        }
    }
}
