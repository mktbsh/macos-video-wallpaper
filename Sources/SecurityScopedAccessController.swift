import Foundation
import os.log

@MainActor
protocol SecurityScopedAccessHandle: AnyObject {
    func stop()
}

@MainActor
protocol SecurityScopedAccessController {
    func startAccessing(_ url: URL) -> SecurityScopedAccessHandle?
}

@MainActor
private final class URLSecurityScopedAccessHandle: SecurityScopedAccessHandle {
    private let url: URL
    private var isStopped = false

    init(url: URL) {
        self.url = url
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        url.stopAccessingSecurityScopedResource()
        Log.security.debug("Stopped security-scoped access for \(self.url.lastPathComponent, privacy: .public)")
    }
}

@MainActor
struct URLSecurityScopedAccessController: SecurityScopedAccessController {
    func startAccessing(_ url: URL) -> SecurityScopedAccessHandle? {
        guard url.startAccessingSecurityScopedResource() else {
            Log.security.error(
                "Failed to start security-scoped access for \(url.lastPathComponent, privacy: .public)"
            )
            return nil
        }
        return URLSecurityScopedAccessHandle(url: url)
    }
}
