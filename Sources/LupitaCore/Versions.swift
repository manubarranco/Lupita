import Foundation

/// Dotted-number version comparison (`0.4.0` against `0.3.0`), for "Check for updates".
public enum Versions {
    public static func parse(_ tag: String) -> [Int] {
        let trimmed = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        return trimmed.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    public static func isNewer(_ remote: String, than installed: String) -> Bool {
        let r = parse(remote), i = parse(installed)
        for k in 0..<max(r.count, i.count) {
            let a = k < r.count ? r[k] : 0, b = k < i.count ? i[k] : 0
            if a != b { return a > b }
        }
        return false
    }

    /// The `tag_name` of a GitHub "latest release" response.
    public static func tag(fromReleaseJSON data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["tag_name"] as? String
    }

    /// The download URL of the release's `Lupita.zip` asset, which "Install and restart" fetches.
    public static func zipURL(fromReleaseJSON data: Data) -> URL? {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let assets = json?["assets"] as? [[String: Any]] ?? []
        let zip = assets.first { $0["name"] as? String == "Lupita.zip" }
        return (zip?["browser_download_url"] as? String).flatMap(URL.init(string:))
    }

    /// Only the project's own GitHub release assets are downloaded for the in-place update.
    /// `URL.host` ignores user-info, so `https://github.com@evil.example/...` has host `evil.example`.
    public static func isProjectReleaseAsset(_ url: URL) -> Bool {
        // GitHub writes the repo as it was named (`manubarranco/Lupita`) and treats names without regard to case.
        url.scheme == "https" && url.host?.lowercased() == "github.com"
            && url.path.lowercased().hasPrefix("/manubarranco/lupita/releases/download/")
    }
}
