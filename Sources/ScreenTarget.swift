import AppKit
import CoreGraphics

enum ScreenTarget: String, CaseIterable {
    case all      = "all"
    case builtIn  = "builtin"
    case external = "external"

    var label: String {
        switch self {
        case .all:      return "すべての画面"
        case .builtIn:  return "内蔵ディスプレイのみ"
        case .external: return "外部モニターのみ"
        }
    }

    static var saved: ScreenTarget {
        ScreenTarget(rawValue: UserDefaults.standard.string(forKey: "screenTarget") ?? "") ?? .all
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "screenTarget")
    }

    func filter(_ screens: [NSScreen]) -> [NSScreen] {
        screens.filter { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
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
