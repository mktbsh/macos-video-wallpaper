import AVFoundation

enum VideoGravity: String, CaseIterable {
    case fill
    case fit
    case stretch

    var label: String {
        switch self {
        case .fill:    return "Cover"
        case .fit:     return "Contain"
        case .stretch: return "Fill"
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
