import AppKit
import CoreGraphics

enum ScreenTarget: String, CaseIterable {
    case all      = "all"
    case builtIn  = "builtin"
    case external = "external"

    var label: String {
        switch self {
        case .all:      return String(localized: "screen_target.all")
        case .builtIn:  return String(localized: "screen_target.builtin")
        case .external: return String(localized: "screen_target.external")
        }
    }

    static var saved: ScreenTarget {
        let key = "screenTarget"
        let savedValue = UserDefaults.standard.string(forKey: key) ?? ""
        return ScreenTarget(rawValue: savedValue) ?? .all
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "screenTarget")
    }

    func filter(_ screens: [NSScreen]) -> [NSScreen] {
        screens.filter { screen in
            guard let id = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else {
                return true
            }
            switch self {
            case .all:      return true
            case .builtIn:  return CGDisplayIsBuiltin(id) != 0
            case .external: return CGDisplayIsBuiltin(id) == 0
            }
        }
    }
}
