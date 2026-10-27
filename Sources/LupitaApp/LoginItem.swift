import Foundation
import ServiceManagement

/// Opens Lupita when the user logs in (D52). Turned on once, the first time this version runs; after that
/// the menu switch decides. macOS shows its own notice when an app adds itself, and the user can also turn
/// it off in System Settings › General › Login Items, which the switch reflects.
@MainActor
enum LoginItem {
    private static let offeredKey = "loginItemOffered"

    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            // Turned off in System Settings: the switch cannot override it, so send the user there.
            if on { SMAppService.openSystemSettingsLoginItems() }
        }
    }

    static func turnOnOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: offeredKey) else { return }
        defaults.set(true, forKey: offeredKey)
        if SMAppService.mainApp.status != .enabled { set(true) }
    }
}
