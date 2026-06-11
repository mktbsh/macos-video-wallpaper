import AppKit
import CoreGraphics

extension NSScreen {
    /// アクティブな各ディスプレイで一意な実行時 ID。
    /// 壁紙ウィンドウ roster のキーに使う（同型ディスプレイ / serial 0 でも衝突しない）。
    var displayID: CGDirectDisplayID? {
        deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? CGDirectDisplayID
    }
}
