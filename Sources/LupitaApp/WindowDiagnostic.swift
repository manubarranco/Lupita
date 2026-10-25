import AppKit
import CoreGraphics
import Foundation
import LupitaCore
import ScreenCaptureKit
import Vision

/// Development aid (D42): `LupitaApp --diagnose-window <app name> <out file>` captures the biggest on-screen window of
/// that app once, reads it like the highlight does and writes, for each word the git package treats as ambiguous
/// (`main`, `rama`, …), whether the code-box detector saw a box and the numbers behind that. It never writes the
/// text of the window: only those words and a histogram of the measures. It does not touch the app or its input.
enum WindowDiagnostic {
    static let watched: Set<String> = ["main", "master", "origin", "rama", "ramas", "branch", "push", "pull", "repo", "commit", "tag", "log",
                                       "diff", "head", "merge", "fork", "fetch", "clone", "review", "stage", "reset", "remoto", "historial"]

    static func run(_ args: [String]) -> Int32 {
        guard args.count == 2 else {
            FileHandle.standardError.write(Data("usage: LupitaApp --diagnose-window <app name> <out file>\n".utf8))
            return 1
        }
        _ = NSApplication.shared  // initialises CoreGraphics for the capture
        let (name, out) = (args[0], args[1])
        nonisolated(unsafe) var report = ""
        nonisolated(unsafe) var targets: [(String, Bool, CGPoint)] = []
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            (report, targets) = await capture(appNamed: name)
            done.signal()
        }
        done.wait()
        // The same Accessibility question the shortcut asks on release, for each watched word (read only: nothing is clicked).
        report += "accessibility at each watched word (\(AXIsProcessTrusted() ? "trusted" : "NOT trusted")):\n"
        for round in 1...3 {
          report += "round \(round)\n"
          if round > 1 { Thread.sleep(forTimeInterval: 3) }
          for (key, styled, point) in targets {
            MainActor.assumeIsolated {
                let outcome = TextUnderCursor.viaAccessibility(at: point)
                guard let hit = outcome.hit else { report += "  \(key)\tstyled=\(styled)\tAX: nothing (\(outcome.diagnostic))\n"; return }
                let word = CandidatePicker.word(in: hit.line, cursorOffset: hit.offset) ?? "?"
                report += "  \(key)\tstyled=\(styled)\tAX via \(hit.via): word=\(word) codeRanges=\(hit.codeRanges.count) \(hit.fontNote)\n"
            }
          }
        }
        try? report.write(toFile: out, atomically: true, encoding: .utf8)
        print(report)
        return 0
    }

    static func capture(appNamed name: String) async -> (String, [(String, Bool, CGPoint)]) {
        let none: [(String, Bool, CGPoint)] = []
        guard CGPreflightScreenCaptureAccess() else { return ("no screen recording permission for this process\n", none) }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              let window = content.windows.filter({ $0.owningApplication?.applicationName.lowercased().contains(name.lowercased()) == true && $0.windowLayer == 0 })
                  .max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
        else { return ("no on-screen window for “\(name)”\n", none) }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config),
              let words = try? OCR.recognize(image, in: window.frame) else { return ("capture failed\n", none) }

        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { return ("could not read pixels\n", none) }

        var lines = ["window \(Int(window.frame.width))×\(Int(window.frame.height)) pt, image \(width)×\(height) px, \(words.count) words, threshold \(CodeBox.threshold)"]
        var targets = none
        var histogram = [Int](repeating: 0, count: 11)   // |behind - around| in steps of 0.01, last bucket = 0.10 or more
        var styled = 0
        for word in words {
            let box = CGRect(x: (word.box.minX - window.frame.minX) * scale, y: (word.box.minY - window.frame.minY) * scale,
                             width: word.box.width * scale, height: word.box.height * scale)
            let m = pixels.withUnsafeBufferPointer { CodeBox.measure(pixels: $0, width: width, height: height, box: box) }
            if let m { histogram[min(10, Int(abs(m.behind - m.around) * 100))] += 1 }
            if word.codeStyled { styled += 1 }
            let key = word.text.trimmingCharacters(in: .punctuationCharacters.union(.symbols)).lowercased()
            if watched.contains(key) {
                let numbers = m.map { String(format: "behind %.3f around %.3f diff %.3f share %.2f", $0.behind, $0.around, abs($0.behind - $0.around), $0.share) } ?? "no measure"
                targets.append((key, word.codeStyled, CGPoint(x: word.box.midX, y: word.box.midY)))
                lines.append("  \(key)\tstyled=\(word.codeStyled)\tbox h=\(Int(box.height))px\t\(numbers)")
            }
        }
        lines.append("words flagged as code: \(styled) of \(words.count)")
        lines.append("diff histogram (0.00-0.01 … ≥0.10): \(histogram)")
        return (lines.joined(separator: "\n") + "\n", targets)
    }
}
