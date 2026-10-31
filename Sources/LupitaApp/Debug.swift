import Foundation

/// Development diagnostics (lookup log, accessibility dumps). Off by default, because the
/// permission prompt promises that nothing is stored. Turn on with
/// `defaults write com.manubarranco.lupita debugLog -bool true`.
enum Debug {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "debugLog") }
    /// The batch of ID forms this build carries; every line of the lookup log says it, so a log tells which version was running (L044).
    static let batch = "batch=5b underline-everything"
}

/// Debug log of the git vocabulary's decisions (D42), only with `Debug.isOn`: one line per lookup in
/// ~/Library/Logs/Lupita/vocabulary.log with the path taken (Accessibility or OCR), the text read, the word,
/// why it did or did not count as git, the font Accessibility reported and what the code-box detector said.
/// It holds the text the user pointed at: it stays on the Mac and the user deletes it when done.
enum VocabularyLog {
    static func append(_ fields: [String]) {
        guard Debug.isOn else { return }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Lupita")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("vocabulary.log")
        let line = ([ISO8601DateFormatter().string(from: Date())] + fields).joined(separator: "\t") + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
