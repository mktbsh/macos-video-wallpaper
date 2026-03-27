import Foundation

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
    }
}

@MainActor
struct URLSecurityScopedAccessController: SecurityScopedAccessController {
    func startAccessing(_ url: URL) -> SecurityScopedAccessHandle? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        return URLSecurityScopedAccessHandle(url: url)
    }
}
