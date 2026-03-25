import Foundation

enum PowerSavingMode: String, CaseIterable {
    case never   = "never"
    case always  = "always"
    case battery = "battery"

    var label: String {
        switch self {
        case .never:   return "しない"
        case .always:  return "常に"
        case .battery: return "バッテリー使用時のみ"
        }
    }

    static var saved: PowerSavingMode {
        PowerSavingMode(rawValue: UserDefaults.standard.string(forKey: "powerSavingMode") ?? "") ?? .never
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "powerSavingMode")
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
