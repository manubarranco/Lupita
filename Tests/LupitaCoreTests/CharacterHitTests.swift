import CoreGraphics
import Testing
@testable import LupitaCore

/// The frames are the ones the app logged in the Claude app on 2026-10-30 (vocabulary.log, `static-frame`):
/// the inline code `Requirement 3` wraps, so its box is (403, 344, 671, 37), both lines, and it covers
/// `Task 2.3` at (895, 344, 66, 16) on the first line.
struct CharacterHitTests {
    /// `Requirement ` from x 975 on the first line, `3` at the start of the second.
    static func requirement(_ i: Int) -> CGRect? {
        guard i < 13 else { return nil }
        return i < 12 ? CGRect(x: 975 + CGFloat(i) * 8.25, y: 344, width: 8.25, height: 16)
                      : CGRect(x: 403, y: 365, width: 8, height: 16)
    }

    @Test func aPointOnTheWordBeforeAWrappedCodeIsNotInIt() {
        // Where the user pointed at `Task 2.3` and got `Requirement 3` (21:50:37 and 21:50:42).
        #expect(CharacterHit.index(at: CGPoint(x: 933.5, y: 350.6), length: 13, bounds: Self.requirement) == nil)
        #expect(CharacterHit.index(at: CGPoint(x: 945.5, y: 352.2), length: 13, bounds: Self.requirement) == nil)
    }

    @Test func aPointOnTheWrappedCodeIsInIt() {
        // 21:50:40, really on `Requirement`.
        #expect(CharacterHit.index(at: CGPoint(x: 1011.6, y: 352.5), length: 13, bounds: Self.requirement) == 4)
        #expect(CharacterHit.index(at: CGPoint(x: 406, y: 370), length: 13, bounds: Self.requirement) == 12)
        // Just past the end of the first line, in the slack.
        #expect(CharacterHit.index(at: CGPoint(x: 1077, y: 350), length: 13, bounds: Self.requirement) == 12)
    }

    @Test func aPointOnItsOwnCodeIsInIt() {
        let task: (Int) -> CGRect? = { $0 < 8 ? CGRect(x: 895 + CGFloat($0) * 8.25, y: 344, width: 8.25, height: 16) : nil }
        #expect(CharacterHit.index(at: CGPoint(x: 934.3, y: 358.4), length: 8, bounds: task) == 4)
    }
}
