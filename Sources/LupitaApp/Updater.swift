import AppKit
import LupitaCore
import Security

/// "Check for updates" (D25). The only network calls in Lupita, and only when the user asks:
/// one GET to GitHub's latest-release endpoint and, if the user then clicks Install, the download
/// of that release's Lupita.zip. Nothing is sent but the requests themselves.
///
/// Install in place (D50): the new app replaces this one only if it is signed with the same
/// certificate, so macOS keeps its Accessibility and Screen Recording permissions. Otherwise
/// (an ad-hoc or a dev build, a translocated or read-only copy) Lupita opens the release page.
@MainActor
enum Updater {
    static let releasesPage = URL(string: "https://github.com/manubarranco/lupita/releases/latest")!
    static let helpPage = URL(string: "https://github.com/manubarranco/lupita#readme")!
    private static let api = URL(string: "https://api.github.com/repos/manubarranco/lupita/releases/latest")!

    /// Set once a newer release was found; the menu then offers it until restart.
    static var availableVersion: String?
    private static var availableZip: URL?
    private static var installing = false

    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// What the menu item says once a newer release was found.
    static func menuTitle(_ version: String) -> String {
        installsInPlace ? S.installUpdate(version) : S.downloadUpdate(version)
    }

    private static var installsInPlace: Bool { availableZip != nil && canInstallInPlace }

    static func checkAndReport() async {
        guard let release = await fetchRelease(api) else {
            alert(S.updateCheckFailed, offer: false)
            return
        }
        if Versions.isNewer(release.tag, than: installedVersion) {
            let version = Versions.parse(release.tag).map(String.init).joined(separator: ".")
            availableVersion = version
            availableZip = release.zip
            alert(S.newVersion(version), offer: true)
        } else {
            alert(S.upToDate(installedVersion), offer: false)
        }
    }

    /// The menu item, once a newer release is known.
    static func offerAvailable() {
        if installsInPlace { Task { await install() } }
        else { NSWorkspace.shared.open(releasesPage) }
    }

    private static func fetchRelease(_ url: URL) async -> (tag: String, zip: URL?)? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lupita/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 == 200,
              let tag = Versions.tag(fromReleaseJSON: data) else { return nil }
        return (tag, Versions.zipURL(fromReleaseJSON: data))
    }

    private static func alert(_ text: String, offer: Bool) {
        let alert = NSAlert()
        alert.messageText = text
        let inPlace = offer && installsInPlace
        if inPlace { alert.informativeText = S.permissionsKept }
        if offer {
            alert.addButton(withTitle: inPlace ? S.installAndRestart : S.download)
            alert.addButton(withTitle: S.later)
        } else {
            alert.addButton(withTitle: "OK")
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, offer { offerAvailable() }
    }

    // MARK: - Install in place

    private static var bundleURL: URL { Bundle.main.bundleURL }

    /// This copy can be replaced: it is signed with a certificate (not ad-hoc), it is not running
    /// from a translocated copy (an app opened from Downloads without moving it), and its folder
    /// is writable.
    static var canInstallInPlace: Bool {
        guard let requirement = ownRequirement, !requirement.contains("cdhash") else { return false }
        return !bundleURL.path.contains("/AppTranslocation/")
            && FileManager.default.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
    }

    /// The designated requirement of the running app: its bundle id and its certificate.
    private static var ownRequirement: String? {
        var code: SecCode?, staticCode: SecStaticCode?, req: SecRequirement?, text: CFString?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopyDesignatedRequirement(staticCode, [], &req) == errSecSuccess, let req,
              SecRequirementCopyString(req, [], &text) == errSecSuccess else { return nil }
        return text as String?
    }

    private static func install() async {
        guard !installing, let zip = availableZip else { return }
        installing = true
        defer { installing = false }
        do {
            try await replaceSelf(withZipAt: zip)
            relaunch()
        } catch {
            let alert = NSAlert()
            alert.messageText = S.installFailed
            alert.informativeText = "\(error)"
            alert.addButton(withTitle: S.download)
            alert.addButton(withTitle: S.later)
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(releasesPage) }
        }
    }

    struct UpdateError: Error, CustomStringConvertible { let description: String }

    /// Downloads the zip, unpacks it next to this app (same volume, so the swap is atomic),
    /// checks the new app's signature against this one's and swaps the bundles.
    private static func replaceSelf(withZipAt zip: URL) async throws {
        let fm = FileManager.default
        let (downloaded, response) = try await URLSession.shared.download(from: zip)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateError(description: "download returned \(http.statusCode)")
        }
        let staging = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: bundleURL, create: true)
        defer { try? fm.removeItem(at: staging) }
        try run("/usr/bin/ditto", ["-x", "-k", downloaded.path, staging.path])
        let newApp = staging.appendingPathComponent("Lupita.app")
        guard fm.fileExists(atPath: newApp.path) else { throw UpdateError(description: "no Lupita.app in the zip") }
        try checkSignature(of: newApp)
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])
        _ = try fm.replaceItemAt(bundleURL, withItemAt: newApp)
    }

    /// The new app must be intact and satisfy this app's designated requirement: same bundle id,
    /// same certificate. A tampered or differently signed zip is refused.
    private static func checkSignature(of app: URL) throws {
        var code: SecStaticCode?, req: SecRequirement?
        guard let text = ownRequirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(text as CFString, [], &req) == errSecSuccess, let req else {
            throw UpdateError(description: "could not read the signatures")
        }
        let status = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), req)
        guard status == errSecSuccess else {
            throw UpdateError(description: "the new app is not signed like this one (\(status))")
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError(description: "\(tool) exited with \(process.terminationStatus)")
        }
    }

    /// Opens the new app once this process has quit.
    private static func relaunch() {
        let script = "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done; open -n \"$0\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, bundleURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    /// Development aid: `LupitaApp --update-from <release JSON URL>` runs the install without
    /// alerts against a local file:// release, to test the swap end to end. It does not relaunch.
    static func runUpdateFrom(_ feed: String?) -> Int32 {
        guard let feed, let url = URL(string: feed) else {
            print("usage: LupitaApp --update-from <release JSON URL>")
            return 2
        }
        print("installed \(installedVersion), can install in place: \(canInstallInPlace)")
        Task {
            guard let release = await fetchRelease(url), let zip = release.zip else {
                print("no release with a Lupita.zip at \(feed)"); exit(1)
            }
            do {
                try await replaceSelf(withZipAt: zip)
                print("replaced \(bundleURL.path) with \(release.tag)")
                exit(0)
            } catch {
                print("refused: \(error)"); exit(1)
            }
        }
        RunLoop.main.run()
        return 1
    }
}
