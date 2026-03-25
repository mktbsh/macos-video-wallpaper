import AVFoundation

enum VideoGravity: String, CaseIterable {
    case fill    = "fill"
    case fit     = "fit"
    case stretch = "stretch"

    var label: String {
        switch self {
        case .fill:    return "cover"
        case .fit:     return "contain"
        case .stretch: return "fill"
        }
    }

    var avGravity: AVLayerVideoGravity {
        switch self {
        case .fill:    return .resizeAspectFill
        case .fit:     return .resizeAspect
        case .stretch: return .resize
        }
    }

    static var saved: VideoGravity {
        VideoGravity(rawValue: UserDefaults.standard.string(forKey: "videoGravity") ?? "") ?? .fill
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "videoGravity")
    }
}
