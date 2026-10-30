import CoreGraphics

/// Which character of a text element is under a point, from the bounds of each character (Accessibility's
/// `AXBoundsForRange`). Pure, so it can be tested without an app.
public enum CharacterHit {
    /// Points of slack around a character: a pointer between two words, or just past the end of a line, still
    /// lands on the nearest character.
    public static let slack: CGFloat = 6

    /// Index of the character under `point`, searching in reading order (line by line, then left to right).
    /// Nil when the element gives no bounds, or when no character of it is near the point: then the element is
    /// not the one under the point. Chromium answers a hit test with the last element it found while the point
    /// is inside that element's box, and the box of an inline code that wraps (`Requirement` / `3`) is the union of
    /// both lines, which covers the words in between (`Task 2.3`).
    public static func index(at point: CGPoint, length: Int, bounds: (Int) -> CGRect?) -> Int? {
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
        // Between two characters: the following one, if it or the one before is right next to the point.
        let following = min(low, length - 1)
        for i in Set([following, max(0, low - 1)]).sorted() {
            if let b = bounds(i), b.insetBy(dx: -slack, dy: -slack / 2).contains(point) { return following }
        }
        return nil
    }
}
