import Testing
import Foundation
@testable import XFeed

@Suite struct RelativeTimeFormatterTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)   // 2026-09-21 UTC

    func ago(_ seconds: Double) -> String {
        RelativeTimeFormatter.string(from: now.addingTimeInterval(-seconds), now: now, calendar: utc)
    }
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }

    @Test func underAMinuteIsNow() { #expect(ago(5) == "now"); #expect(ago(59) == "now") }
    @Test func minutes() { #expect(ago(60) == "1m"); #expect(ago(59 * 60) == "59m") }
    @Test func hours() { #expect(ago(3600) == "1h"); #expect(ago(23 * 3600) == "23h") }
    @Test func days() { #expect(ago(86_400) == "1d"); #expect(ago(6 * 86_400) == "6d") }
    @Test func olderThanAWeekShowsMonthAndDay() { #expect(ago(10 * 86_400) == "Sep 11") }
    @Test func otherYearIncludesTheYear() { #expect(ago(400 * 86_400) == "Aug 17, 2025") }
    @Test func futureDatesClampToNow() { #expect(ago(-30) == "now") }
}
