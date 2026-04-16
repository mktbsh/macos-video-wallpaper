import Foundation
import Testing

struct ProjectConfigurationTests {

    @Test func app_entitlements_enable_app_sandbox_and_user_selected_read_only_access() throws {
        let entitlementsURL = try #require(repositoryRootURL()?.appending(path: "Sources/VideoWallpaper.entitlements"))
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(plist["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(plist["com.apple.security.files.user-selected.read-only"] as? Bool == true)
        #expect(plist["com.apple.security.files.bookmarks.app-scope"] as? Bool == true)
    }

    @Test func project_configuration_enables_hardened_runtime_and_codesign_entitlements() throws {
        let projectURL = try #require(repositoryRootURL()?.appending(path: "project.yml"))
        let projectContents = try String(contentsOf: projectURL, encoding: .utf8)

        #expect(projectContents.contains("ENABLE_HARDENED_RUNTIME: YES"))
        #expect(projectContents.contains("entitlements:\n      path: Sources/VideoWallpaper.entitlements"))
        #expect(projectContents.contains("CODE_SIGN_ENTITLEMENTS: Sources/VideoWallpaper.entitlements"))
    }
}

private func repositoryRootURL(filePath: StaticString = #filePath) -> URL? {
    var url = URL(fileURLWithPath: "\(filePath)", isDirectory: false)
    url.deleteLastPathComponent()

    while url.path != "/" {
        if FileManager.default.fileExists(atPath: url.appending(path: "project.yml").path) {
            return url
        }
        url.deleteLastPathComponent()
    }

    return nil
}
