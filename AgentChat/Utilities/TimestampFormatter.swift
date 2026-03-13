import Foundation

struct TimestampFormatter {
    /// For chat list rows — relative: "Just now", "2m ago", "Yesterday", "Dec 20", "Dec 20, 2023"
    static func relativeString(from milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        let now = Date()
        let calendar = Calendar.current

        // Get the time interval in seconds
        let secondsAgo = now.timeIntervalSince(date)

        // Less than 60 seconds
        if secondsAgo < 60 {
            return "Just now"
        }

        // Less than 60 minutes
        if secondsAgo < 3600 {
            let minutesAgo = Int(secondsAgo / 60)
            return "\(minutesAgo)m ago"
        }

        // Check if same day
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }

        // Check if yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // Check if same calendar year
        let nowComponents = calendar.dateComponents([.year], from: now)
        let dateComponents = calendar.dateComponents([.year], from: date)

        let formatter = DateFormatter()
        if nowComponents.year == dateComponents.year {
            // Same year: "Dec 20"
            formatter.dateFormat = "MMM d"
        } else {
            // Different year: "Dec 20, 2023"
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }

    /// For message bubble timestamps — absolute: "2:30 PM"
    static func timeString(from milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
