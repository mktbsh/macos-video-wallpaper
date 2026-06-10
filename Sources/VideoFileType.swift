import Foundation
import UniformTypeIdentifiers

/// 対応動画形式（mp4 / mov / m4v）の判定と UTType 一覧。
/// 純粋な値計算であり、永続化や seam を持たない。
enum VideoFileType {

    private static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static let allowedUTTypes: [UTType] = [
        .mpeg4Movie,
        .quickTimeMovie,
        UTType(filenameExtension: "m4v") ?? .movie
    ]

    static func isSupported(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }
}
