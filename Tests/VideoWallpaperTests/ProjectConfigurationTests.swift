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

    @Test func project_yml_declares_required_sandbox_entitlement_properties() throws {
        let projectURL = try #require(repositoryRootURL()?.appending(path: "project.yml"))
        let projectContents = try String(contentsOf: projectURL, encoding: .utf8)
        let entitlements = projectYMLEntitlementValues(in: projectContents)

        #expect(entitlements["com.apple.security.app-sandbox"] == true)
        #expect(entitlements["com.apple.security.files.user-selected.read-only"] == true)
        #expect(entitlements["com.apple.security.files.bookmarks.app-scope"] == true)
        #expect(projectContents.contains("ENABLE_APP_SANDBOX") == false)
    }

    @Test func project_configuration_enables_hardened_runtime_and_codesign_entitlements() throws {
        let projectURL = try #require(repositoryRootURL()?.appending(path: "project.yml"))
        let projectContents = try String(contentsOf: projectURL, encoding: .utf8)

        #expect(projectContents.contains("ENABLE_HARDENED_RUNTIME: YES"))
        #expect(projectContents.contains("entitlements:\n      path: Sources/VideoWallpaper.entitlements"))
        #expect(projectContents.contains("CODE_SIGN_ENTITLEMENTS: Sources/VideoWallpaper.entitlements"))
    }

    @Test func all_xcstrings_keys_have_non_empty_english_and_japanese_translations() throws {
        let xcstringsURL = try #require(
            repositoryRootURL()?.appending(path: "Sources/Localizable.xcstrings")
        )
        let data = try Data(contentsOf: xcstringsURL)
        let plist = try #require(
            try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try #require(plist["strings"] as? [String: Any])

        var missingKeys: [String] = []
        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                missingKeys.append("\(key) (no localizations)")
                continue
            }
            let enValue = (localizations["en"] as? [String: Any]).flatMap {
                $0["stringUnit"] as? [String: Any]
            }.flatMap { $0["value"] as? String } ?? ""
            let jaValue = (localizations["ja"] as? [String: Any]).flatMap {
                $0["stringUnit"] as? [String: Any]
            }.flatMap { $0["value"] as? String } ?? ""

            if enValue.isEmpty { missingKeys.append("\(key) (missing en)") }
            if jaValue.isEmpty { missingKeys.append("\(key) (missing ja)") }
        }

        #expect(missingKeys.isEmpty, "Keys with missing translations: \(missingKeys)")
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

private func projectYMLEntitlementValues(in contents: String) -> [String: Bool] {
    var values: [String: Bool] = [:]

    for line in contents.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              parts[0].hasPrefix("com.apple.security.") else { continue }
        values[parts[0]] = parts[1].trimmingCharacters(in: .whitespaces) == "true"
    }

    return values
}
