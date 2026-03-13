import Foundation
import Testing
@testable import AgentChat

@MainActor
struct TimestampFormatterTests {

    private func ms(secondsAgo: TimeInterval) -> Int64 {
        Int64((Date().timeIntervalSince1970 - secondsAgo) * 1000)
    }

    // MARK: - relativeString Tests

    @Test func thirtySecondsAgoReturnsJustNow() {
        let timestamp = ms(secondsAgo: 30)
        let result = TimestampFormatter.relativeString(from: timestamp)
        #expect(result == "Just now")
    }

    @Test func twoMinutesAgoReturnsTwoMAgo() {
        let timestamp = ms(secondsAgo: 121)
        let result = TimestampFormatter.relativeString(from: timestamp)
        #expect(result == "2m ago")
    }

    @Test func fortyFiveMinutesAgoReturns45MAgo() {
        let timestamp = ms(secondsAgo: 45 * 60)
        let result = TimestampFormatter.relativeString(from: timestamp)
        #expect(result == "45m ago")
    }

    @Test func todayTwoHoursAgoReturnsTimeString() {
        let timestamp = ms(secondsAgo: 2 * 3600)
        let result = TimestampFormatter.relativeString(from: timestamp)
        // Check it matches time format, not "ago", not "Just now", not "Yesterday"
        #expect(!result.contains("ago"))
        #expect(result != "Just now")
        #expect(result != "Yesterday")
        // Check it matches the pattern of "h:mm a" (e.g., "2:30 PM")
        let timePattern = try! NSRegularExpression(pattern: "\\d{1,2}:\\d{2}", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = timePattern.matches(in: result, options: [], range: range)
        #expect(!matches.isEmpty)
    }

    @Test func yesterdayReturnsYesterday() {
        let timestamp = ms(secondsAgo: 25 * 3600)
        let result = TimestampFormatter.relativeString(from: timestamp)
        #expect(result == "Yesterday")
    }

    @Test func thisYearOlderReturnsMonthDay() {
        let timestamp = ms(secondsAgo: 30 * 24 * 3600)
        let result = TimestampFormatter.relativeString(from: timestamp)
        // Should not contain the current year
        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year], from: now)
        let yearString = String(nowComponents.year ?? 0)
        #expect(!result.contains(yearString))
        // Check pattern: "Dec 20" (no year)
        let datePattern = try! NSRegularExpression(pattern: "^[A-Za-z]+ \\d{1,2}$", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = datePattern.matches(in: result, options: [], range: range)
        #expect(!matches.isEmpty)
    }

    @Test func lastYearReturnsMonthDayYear() {
        let timestamp = ms(secondsAgo: 400 * 24 * 3600)
        let result = TimestampFormatter.relativeString(from: timestamp)
        // Should contain a 4-digit year
        let yearPattern = try! NSRegularExpression(pattern: "\\d{4}", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = yearPattern.matches(in: result, options: [], range: range)
        #expect(!matches.isEmpty)
    }

    // MARK: - timeString Tests

    @Test func timeStringReturnsShortTimeFormat() {
        let timestamp = ms(secondsAgo: 3600)
        let result = TimestampFormatter.timeString(from: timestamp)
        // Check it matches regex \d{1,2}:\d{2} (AM|PM)
        let timePattern = try! NSRegularExpression(pattern: "\\d{1,2}:\\d{2}", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = timePattern.matches(in: result, options: [], range: range)
        #expect(!matches.isEmpty)
    }
}
