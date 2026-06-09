import AVFoundation

enum VideoGravity: String, CaseIterable {
    case fill
    case fit
    case stretch

    var label: String {
        switch self {
        case .fill:    return String(localized: "video_gravity.cover")
        case .fit:     return String(localized: "video_gravity.contain")
        case .stretch: return String(localized: "video_gravity.fill")
        }
    }

    var avGravity: AVLayerVideoGravity {
        switch self {
        case .fill:    return .resizeAspectFill
        case .fit:     return .resizeAspect
        case .stretch: return .resize
        }
    }

    static let storageKey = "videoGravity"

    static var saved: VideoGravity {
        VideoGravity(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .fill
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }
}
