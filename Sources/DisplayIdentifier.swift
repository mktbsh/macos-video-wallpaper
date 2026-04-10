import AppKit
import CoreGraphics

struct DisplayIdentifier: Hashable, CustomStringConvertible {
    let vendor: UInt32
    let model: UInt32
    let serial: UInt32

    var description: String { "\(vendor)_\(model)_\(serial)" }

    init(vendor: UInt32, model: UInt32, serial: UInt32) {
        self.vendor = vendor
        self.model = model
        self.serial = serial
    }

    init(displayID: CGDirectDisplayID) {
        self.vendor = CGDisplayVendorNumber(displayID)
        self.model = CGDisplayModelNumber(displayID)
        self.serial = CGDisplaySerialNumber(displayID)
    }

    func userDefaultsKey(for prefix: String) -> String {
        "\(prefix)_display_\(description)"
    }
}

extension NSScreen {
    var displayIdentifier: DisplayIdentifier? {
        guard let id = deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? CGDirectDisplayID else {
            return nil
        }
        return DisplayIdentifier(displayID: id)
    }
}
