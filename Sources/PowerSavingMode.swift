import Foundation

enum PowerSavingMode: String, CaseIterable {
    case never
    case always
    case battery

    var label: String {
        switch self {
        case .never:   return String(localized: "power_saving_mode.never")
        case .always:  return String(localized: "power_saving_mode.always")
        case .battery: return String(localized: "power_saving_mode.battery")
        }
    }

    static let storageKey = "powerSavingMode"

    static var saved: PowerSavingMode {
        PowerSavingMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .never
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    /// Returns true if playback should be paused given the current power source state.
    func shouldPause(isOnBattery: Bool) -> Bool {
        switch self {
        case .never:   return false
        case .always:  return true
        case .battery: return isOnBattery
        }
    }
}
