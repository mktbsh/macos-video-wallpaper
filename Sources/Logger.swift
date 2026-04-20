import os.log

enum Log {
    static let general = Logger(subsystem: "com.local.VideoWallpaper", category: "general")
    static let playback = Logger(subsystem: "com.local.VideoWallpaper", category: "playback")
    static let persistence = Logger(subsystem: "com.local.VideoWallpaper", category: "persistence")
    static let security = Logger(subsystem: "com.local.VideoWallpaper", category: "security")
}
