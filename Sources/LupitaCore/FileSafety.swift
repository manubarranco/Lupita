import Foundation

/// A click on a file must never run or install anything.
public enum FileSafety {
    private static let runnableExtensions: Set<String> = [
        "command", "tool", "app", "terminal", "pkg", "mpkg", "dmg", "workflow", "action",
        "scpt", "scptd", "applescript", "jar", "shortcut"]

    /// Whether opening `path` with the default app would run or install it.
    public static func runsWhenOpened(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if runnableExtensions.contains(ext) { return true }
        var isDir: ObjCBool = false
        return ext.isEmpty && FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
            && FileManager.default.isExecutableFile(atPath: path)
    }
}
