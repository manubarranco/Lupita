import CoreGraphics
import Foundation

/// Tells from the pixels whether a word sits in an inline-code box (D42): the grey (or tinted) rounded
/// rectangle chat apps and markdown previews draw behind `main`, `origin` or `README.md`, where the
/// backticks are not shown. Such a word counts as if it carried backticks.
public enum CodeBox {
    /// - Parameters:
    ///   - pixels: RGBA, 4 bytes per pixel, row 0 at the top.
    ///   - box: the word's box in pixels, top-left origin.
    /// What lies behind the glyphs (the commonest brightness inside the word's box) must differ from what
    /// lies above and below the line. Plain text has the window's own background in both places; inline code
    /// has its box behind the word and the window's background around it.
    public static func isCodeStyled(pixels: UnsafeBufferPointer<UInt8>, width: Int, height: Int, box: CGRect) -> Bool {
        guard let m = measure(pixels: pixels, width: width, height: height, box: box) else { return false }
        return abs(m.behind - m.around) >= threshold
    }

    /// Brightness difference (0...1) between the inside of the box and the line's surroundings that counts as a box.
    public static let threshold = 0.02

    public struct Measure: Sendable {
        /// Commonest brightness behind the word.
        public let behind: Double
        /// Median brightness above and below the line.
        public let around: Double
        /// Share of the word's pixels near `behind`.
        public let share: Double
    }

    public static func measure(pixels: UnsafeBufferPointer<UInt8>, width: Int, height: Int, box: CGRect) -> Measure? {
        let h = box.height
        guard h >= 6, box.width >= 4, pixels.count >= width * height * 4 else { return nil }

        func luminances(x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat) -> [Double] {
            let x0 = max(Int(x0.rounded()), 0), x1 = min(Int(x1.rounded()), width - 1)
            let y0 = max(Int(y0.rounded()), 0), y1 = min(Int(y1.rounded()), height - 1)
            guard x0 <= x1, y0 <= y1 else { return [] }
            var out: [Double] = []
            out.reserveCapacity((x1 - x0 + 1) * (y1 - y0 + 1))
            for y in y0...y1 {
                for x in x0...x1 {
                    let i = (y * width + x) * 4
                    out.append((0.299 * Double(pixels[i]) + 0.587 * Double(pixels[i + 1]) + 0.114 * Double(pixels[i + 2])) / 255)
                }
            }
            return out
        }

        // Behind the word: the commonest brightness (the glyphs are a minority of the pixels).
        let inside = luminances(x0: box.minX + 1, x1: box.maxX - 1, y0: box.minY + h * 0.1, y1: box.maxY - h * 0.1)
        guard inside.count >= 16 else { return nil }
        var buckets = [Int](repeating: 0, count: 51)
        for v in inside { buckets[Int(v * 50)] += 1 }
        guard let top = buckets.indices.max(by: { buckets[$0] < buckets[$1] }) else { return nil }
        let near = inside.filter { abs(Int($0 * 50) - top) <= 1 }
        let share = Double(near.count) / Double(inside.count)
        guard share >= 0.4 else { return nil }
        let behind = near.reduce(0, +) / Double(near.count)

        let around = luminances(x0: box.minX, x1: box.maxX, y0: box.minY - h * 0.6, y1: box.minY - h * 0.3)
            + luminances(x0: box.minX, x1: box.maxX, y0: box.maxY + h * 0.3, y1: box.maxY + h * 0.6)
        guard around.count >= 16 else { return nil }
        return Measure(behind: behind, around: around.sorted()[around.count / 2], share: share)
    }
}
