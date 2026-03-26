import Foundation

enum DimLevel: String, CaseIterable {
    case none
    case slight
    case dark

    var label: String {
        switch self {
        case .none:   return String(localized: "dim_level.none")
        case .slight: return String(localized: "dim_level.slight")
        case .dark:   return String(localized: "dim_level.dark")
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
