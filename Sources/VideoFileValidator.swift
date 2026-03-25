import Foundation

enum VideoFileValidator {

    private static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static func isSupported(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    static func resolveVideoURL(fromPath path: String?) -> URL? {
        guard let path = path else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
