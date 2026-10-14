import Foundation

/// X-style timestamps: "now", "5m", "3h", "2d", then "Oct 4" (with the year when it differs).
enum RelativeTimeFormatter {
    static func string(from date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3_600)h"
        case ..<(7 * 86_400): return "\(seconds / 86_400)d"
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}
