import AppKit
import ApplicationServices
import LupitaCore

/// Reads the text under the cursor through the Accessibility API (first choice, D14):
/// exact text, no OCR errors, no screen capture.
@MainActor
enum TextUnderCursor {
    struct Hit {
        let line: String
        /// UTF-16 offset of the cursor in `line`.
        let offset: Int
        /// Which strategy produced it: `range`, `marker` or `static`.
        var via = ""
        /// UTF-16 ranges of `line` in a monospaced font: inline code, which counts as backticks (D42).
        var codeRanges: [NSRange] = []
        /// What Accessibility said about the font of the line, for the debug log.
        var fontNote = ""
    }

    struct Outcome {
        var hit: Hit?
        /// Why it failed, for the lookup log: `untrusted`, `no-element`, or the element's role.
        var diagnostic = ""
    }

    private static var enabledPIDs: Set<pid_t> = []

    static func viaAccessibility(at point: CGPoint) -> Outcome {
        guard AXIsProcessTrusted() else { return Outcome(diagnostic: "untrusted") }
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              let element else { return Outcome(diagnostic: "no-element") }
        enableAccessibilityTree(for: element)
        let role: String = attribute(element, kAXRoleAttribute) ?? "?"
        // Electron answers the range query with an empty string: that is a miss, try the next way.
        func usable(_ hit: Hit?) -> Hit? {
            guard let hit, !hit.line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return hit
        }
        if var hit = usable(rangeBased(element, point)) { hit.via = "range"; return Outcome(hit: hit) }
        if var hit = usable(markerBased(element, point)) { hit.via = "marker"; return Outcome(hit: hit) }
        if var hit = usable(staticText(element, point)) { hit.via = "static"; return Outcome(hit: hit, diagnostic: role) }
        dumpChain(element, point)
        return Outcome(diagnostic: role)
    }

    /// Dev aid (only with `Debug.isOn`): when every strategy fails, write the element chain and what each node answers
    /// to ~/Library/Logs/Lupita/ax-dump.log (overwritten each time).
    private static func dumpChain(_ element: AXUIElement, _ point: CGPoint) {
        guard Debug.isOn else { return }
        var lines: [String] = []
        // Step-by-step trace of the marker strategy on the leaf.
        var p = point
        let position = AXValueCreate(.cgPoint, &p)!
        var raw: CFTypeRef?
        let leafError = AXUIElementCopyParameterizedAttributeValue(element, "AXTextMarkerForPosition" as CFString, position, &raw)
        lines.append("leaf marker error: \(leafError.rawValue)")
        var webArea: AXUIElement? = element
        var depth = 0
        while let node = webArea, (attribute(node, kAXRoleAttribute) as String?) != "AXWebArea", depth < 80 {
            webArea = attribute(node, kAXParentAttribute); depth += 1
        }
        lines.append("web area at depth \(depth): \(webArea == nil ? "not found" : "found")")
        var webMarker: AnyObject?
        if let webArea {
            var value: CFTypeRef?
            let e = AXUIElementCopyParameterizedAttributeValue(webArea, "AXTextMarkerForPosition" as CFString, position, &value)
            lines.append("web area marker error: \(e.rawValue)")
            webMarker = value
        }
        let marker: AnyObject? = webMarker
        lines.append("marker: \(marker == nil ? "nil" : "ok") point=\(point)")
        if let marker {
            let lineRange: AnyObject? = parameterized(element, "AXLineTextMarkerRangeForTextMarker", marker)
            lines.append("lineRange: \(lineRange == nil ? "nil" : "ok")")
            if let lineRange {
                let line: String? = parameterized(element, "AXStringForTextMarkerRange", lineRange)
                let attributed: NSAttributedString? = parameterized(element, "AXAttributedStringForTextMarkerRange", lineRange)
                lines.append("line string: \(line.map { "“\($0.prefix(80))”" } ?? "nil") · attributed: \(attributed.map { "“\($0.string.prefix(80))”" } ?? "nil")")
            }
            let start: AnyObject? = parameterized(element, "AXPreviousLineStartTextMarkerForTextMarker", marker)
            lines.append("prevLineStart: \(start == nil ? "nil" : "ok")")
            let word: AnyObject? = parameterized(element, "AXRightWordTextMarkerRangeForTextMarker", marker)
            let wordString: String? = word.flatMap { parameterized(element, "AXStringForTextMarkerRange", $0) }
            lines.append("rightWord: \(wordString.map { "“\($0)”" } ?? "nil")")
        }
        var current: AXUIElement? = element
        for depth in 0..<12 {
            guard let node = current else { break }
            let role: String = attribute(node, kAXRoleAttribute) ?? "?"
            let value: String = (attribute(node, kAXValueAttribute) as String?).map { String($0.prefix(60)) } ?? "-"
            var names: CFArray?
            AXUIElementCopyParameterizedAttributeNames(node, &names)
            let params = (names as? [String])?.joined(separator: ",") ?? "-"
            lines.append("\(depth) \(role) value=“\(value)” params=\(params)")
            current = attribute(node, kAXParentAttribute)
        }
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Lupita/ax-dump.log")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// Web content (Chrome, Safari, Electron apps such as Claude, Obsidian, VS Code previews):
    /// no character ranges, only opaque text markers. Ask for the marker under the point, the
    /// line around it, and the text from the line start to the marker (= the offset).
    private static func markerBased(_ element: AXUIElement, _ point: CGPoint) -> Hit? {
        var p = point
        guard let position = AXValueCreate(.cgPoint, &p) else { return nil }
        // The web area answers these, not always the leaf: walk up a few levels.
        var current: AXUIElement? = element
        for _ in 0..<8 {
            guard let node = current else { return nil }
            if let marker: AnyObject = parameterized(node, "AXTextMarkerForPosition", position) {
                // Line + offset. Chromium has no "start of range", so the line start comes from
                // "previous line start", which can overshoot into the line above: cut at the newline.
                if let lineRange: AnyObject = parameterized(node, "AXLineTextMarkerRangeForTextMarker", marker),
                   let line: String = parameterized(node, "AXStringForTextMarkerRange", lineRange),
                   let lineStart: AnyObject = parameterized(node, "AXPreviousLineStartTextMarkerForTextMarker", marker),
                   let prefixRange: AnyObject = parameterized(node, "AXTextMarkerRangeForUnorderedTextMarkers", [lineStart, marker] as CFArray),
                   let prefix: String = parameterized(node, "AXStringForTextMarkerRange", prefixRange) {
                    let tail = prefix.components(separatedBy: .newlines).last ?? prefix
                    var hit = Hit(line: line.trimmingCharacters(in: .newlines), offset: (tail as NSString).length)
                    let attributed: NSAttributedString? = parameterized(node, "AXAttributedStringForTextMarkerRange", lineRange)
                    if let attributed {
                        let skipped = (line as NSString).length - (line.drop { $0.isNewline } as Substring).utf16.count
                        hit.fontNote = fontNote(of: attributed)
                        hit.codeRanges = monospacedRanges(in: attributed).map { NSRange(location: max(0, $0.location - skipped), length: $0.length) }
                    }
                    return hit
                }
                // Fallback: just the word under the marker, no context.
                if let wordRange: AnyObject = parameterized(node, "AXRightWordTextMarkerRangeForTextMarker", marker),
                   let word: String = parameterized(node, "AXStringForTextMarkerRange", wordRange) {
                    return Hit(line: word, offset: 0)
                }
            }
            current = attribute(node, kAXParentAttribute)
        }
        return nil
    }

    /// Attribute names and font names of the line, distinct, for the debug log.
    static func fontNote(of text: NSAttributedString) -> String {
        guard text.length > 0 else { return "empty" }
        var keys = Set<String>(), fonts = Set<String>(), runs = 0
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, _ in
            runs += 1
            for (key, value) in attributes {
                keys.insert(key.rawValue)
                if let font = value as? NSFont { fonts.insert("NSFont:" + font.fontName) }
                else if let dict = value as? [String: Any] {
                    fonts.insert(["AXFontName", "AXFontFamily"].compactMap { dict[$0] as? String }.joined(separator: "/") + "{" + dict.keys.sorted().joined(separator: ",") + "}")
                }
            }
        }
        return "runs=\(runs) keys=\(keys.sorted().joined(separator: ",")) fonts=\(fonts.sorted().joined(separator: "|"))"
    }

    /// Runs of `text` in a monospaced font. Chromium reports the font as an `AXFont` dictionary, other apps as
    /// an `NSFont`; either way a name such as «SF Mono» or «Menlo» is code. Not checked against the real
    /// apps yet (D42): a miss only means a lone `main` needs another git word, as before.
    static func monospacedRanges(in text: NSAttributedString) -> [NSRange] {
        var out: [NSRange] = []
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            for value in attributes.values {
                var names: [String] = []
                if let font = value as? NSFont {
                    if font.isFixedPitch { names.append("mono") }
                    names.append(font.fontName)
                } else if let dict = value as? [String: Any] {
                    names += ["AXFontName", "AXFontFamily"].compactMap { dict[$0] as? String }
                }
                if names.contains(where: GitVocabulary.isMonospacedFont) { out.append(range); break }
            }
        }
        return out
    }

    /// Text views, terminals, editors: ask which character is under the point.
    private static func rangeBased(_ element: AXUIElement, _ point: CGPoint) -> Hit? {
        var p = point
        guard let position = AXValueCreate(.cgPoint, &p),
              let rangeValue: AXValue = parameterized(element, kAXRangeForPositionParameterizedAttribute, position)
        else { return nil }
        var hitRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &hitRange), hitRange.location != kCFNotFound else { return nil }

        let total: Int = attribute(element, kAXNumberOfCharactersAttribute) ?? (hitRange.location + 200)
        let start = max(0, hitRange.location - 200)
        var window = CFRange(location: start, length: min(400, max(0, total - start)))
        guard let windowValue = AXValueCreate(.cfRange, &window),
              let text: String = parameterized(element, kAXStringForRangeParameterizedAttribute, windowValue)
        else { return nil }
        return line(in: text, offset: hitRange.location - start)
    }

    /// Web content and labels: a static text element, often a whole paragraph that wraps over
    /// several screen lines. The character under the point comes from per-character bounds
    /// (binary search, ~11 queries). Estimating it from the element's width picked the wrong
    /// word in wrapped paragraphs (E9-S13 → E11-S13), so that is only done for one visual line.
    private static func staticText(_ element: AXUIElement, _ point: CGPoint) -> Hit? {
        guard let text: String = attribute(element, kAXValueAttribute) ?? attribute(element, kAXTitleAttribute),
              !text.isEmpty, text.count < 5000,
              let frame = frame(of: element), frame.width > 0
        else { return nil }
        let length = (text as NSString).length
        if let offset = characterIndex(in: element, at: point, length: length) {
            return line(in: text, offset: offset)
        }
        guard !text.contains("\n"), frame.height < 32 else { return nil }  // let OCR read it
        let fraction = min(max((point.x - frame.minX) / frame.width, 0), 1)
        return Hit(line: text, offset: Int(fraction * CGFloat(length)))
    }

    /// Index of the character under `point`, searching in reading order (line by line, then
    /// left to right). Nil when the element does not report character bounds.
    static func characterIndex(in element: AXUIElement, at point: CGPoint, length: Int) -> Int? {
        func bounds(_ i: Int) -> CGRect? {
            var range = CFRange(location: i, length: 1)
            guard let value = AXValueCreate(.cfRange, &range),
                  let result: AXValue = parameterized(element, kAXBoundsForRangeParameterizedAttribute, value)
            else { return nil }
            var rect = CGRect.zero
            guard AXValueGetValue(result, .cgRect, &rect), rect.height > 0 else { return nil }
            return rect
        }
        guard length > 0, bounds(0) != nil else { return nil }
        var low = 0, high = length - 1
        while low <= high {
            let mid = (low + high) / 2
            guard let b = bounds(mid) else { return nil }
            let sameLine = b.minY <= point.y && point.y < b.maxY
            if b.maxY <= point.y || (sameLine && b.maxX <= point.x) {
                low = mid + 1
            } else if b.minY > point.y || (sameLine && b.minX > point.x) {
                high = mid - 1
            } else {
                return mid
            }
        }
        return min(low, length - 1)  // between two characters: the following one
    }

    private static func line(in text: String, offset: Int) -> Hit {
        let ns = text as NSString
        let safe = min(max(offset, 0), max(ns.length - 1, 0))
        let range = ns.lineRange(for: NSRange(location: safe, length: 0))
        let line = ns.substring(with: range).trimmingCharacters(in: .newlines)
        return Hit(line: line, offset: safe - range.location)
    }

    /// Chrome and Electron apps (VS Code, Cursor) only build their accessibility tree when asked.
    private static func enableAccessibilityTree(for element: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, !enabledPIDs.contains(pid) else { return }
        enabledPIDs.insert(pid)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard let posValue: AXValue = attribute(element, kAXPositionAttribute),
              let sizeValue: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private static func parameterized<T>(_ element: AXUIElement, _ name: String, _ parameter: CFTypeRef) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value) == .success
        else { return nil }
        return value as? T
    }
}
