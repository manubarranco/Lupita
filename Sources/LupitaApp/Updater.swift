import AppKit
import LupitaCore

/// "Check for updates" (D25). The only network call in Lupita, and only when the user asks:
/// one GET to GitHub's latest-release endpoint. Nothing is sent but the request itself.
@MainActor
enum Updater {
    static let releasesPage = URL(string: "https://github.com/manubarranco/lupita/releases/latest")!
    static let helpPage = URL(string: "https://github.com/manubarranco/lupita#readme")!
    private static let api = URL(string: "https://api.github.com/repos/manubarranco/lupita/releases/latest")!

    /// Set once a newer release was found; the menu then offers the download until restart.
    static var availableVersion: String?

    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func checkAndReport() async {
        var request = URLRequest(url: api, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lupita/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let tag = Versions.tag(fromReleaseJSON: data) else {
            alert(S.updateCheckFailed, download: false)
            return
        }
        if Versions.isNewer(tag, than: installedVersion) {
            let version = Versions.parse(tag).map(String.init).joined(separator: ".")
            availableVersion = version
            alert(S.newVersion(version), download: true)
        } else {
            alert(S.upToDate(installedVersion), download: false)
        }
    }

    private static func alert(_ text: String, download: Bool) {
        let alert = NSAlert()
        alert.messageText = text
        if download {
            alert.addButton(withTitle: S.download)
            alert.addButton(withTitle: S.later)
        } else {
            alert.addButton(withTitle: "OK")
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, download { NSWorkspace.shared.open(releasesPage) }
    }
}
