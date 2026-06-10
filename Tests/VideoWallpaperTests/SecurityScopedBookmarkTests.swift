import Foundation
import Testing
@testable import VideoWallpaper

struct SecurityScopedBookmarkTests {

    // MARK: - data(for:) / resolve(_:)

    @Test func roundtrip_resolves_existing_file() throws {
        let url = makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try SecurityScopedBookmark.data(for: url)
        let resolution = SecurityScopedBookmark.resolve(data)

        #expect(resolution != nil)
        #expect(resolution?.url.lastPathComponent == url.lastPathComponent)
    }

    @Test func resolve_returns_nil_for_invalid_data() {
        #expect(SecurityScopedBookmark.resolve(Data([0x00, 0x01, 0x02])) == nil)
    }

    @Test func resolve_returns_nil_when_file_no_longer_exists() throws {
        let url = makeTempFile()
        let data = try SecurityScopedBookmark.data(for: url)
        try FileManager.default.removeItem(at: url)

        #expect(SecurityScopedBookmark.resolve(data) == nil)
    }

    @Test func resolve_does_not_report_fresh_bookmark_as_stale() throws {
        let url = makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try SecurityScopedBookmark.data(for: url)
        let resolution = try #require(SecurityScopedBookmark.resolve(data))

        #expect(!resolution.isStale)
    }

    // MARK: - normalizeFileURL(_:)

    @Test func normalize_strips_private_prefix_when_file_exists_at_stripped_path() {
        let url = makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        // temporaryDirectory は /var/folders/... を返し、実体は /private/var/folders/...
        let privateURL = URL(fileURLWithPath: "/private" + url.path)
        let normalized = SecurityScopedBookmark.normalizeFileURL(privateURL)

        #expect(normalized.path == url.path)
    }

    @Test func normalize_keeps_url_without_private_prefix() {
        let url = URL(fileURLWithPath: "/Users/someone/movie.mp4")
        #expect(SecurityScopedBookmark.normalizeFileURL(url) == url)
    }

    @Test func normalize_keeps_private_url_when_stripped_path_missing() {
        let url = URL(fileURLWithPath: "/private/etc/nonexistent_\(UUID().uuidString).mp4")
        #expect(SecurityScopedBookmark.normalizeFileURL(url) == url)
    }

    // MARK: - Helpers

    private func makeTempFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("codec_\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }
}
