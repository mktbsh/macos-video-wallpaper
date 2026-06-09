import os.log

enum Log {
    private static let subsystem = "com.local.VideoWallpaper"
    static let playback = Logger(subsystem: subsystem, category: "playback")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let security = Logger(subsystem: subsystem, category: "security")
}
