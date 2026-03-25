import Foundation

enum DimLevel: String, CaseIterable {
    case none   = "none"
    case slight = "slight"
    case dark   = "dark"

    var label: String {
        switch self {
        case .none:   return "なし"
        case .slight: return "少し暗く"
        case .dark:   return "暗く"
        }
    }

    var opacity: CGFloat {
        switch self {
        case .none:   return 0.0
        case .slight: return 0.3
        case .dark:   return 0.6
        }
    }

    static var saved: DimLevel {
        DimLevel(rawValue: UserDefaults.standard.string(forKey: "wallpaperDimLevel") ?? "") ?? .none
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "wallpaperDimLevel")
    }
}
