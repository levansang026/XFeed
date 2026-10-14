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
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let month = months[(parts.month ?? 1) - 1]
            let day = parts.day ?? 1
            let sameYear = parts.year == calendar.component(.year, from: now)
            return sameYear ? "\(month) \(day)" : "\(month) \(day), \(parts.year ?? 0)"
        }
    }

    /// X shows English abbreviations, and avoiding `DateFormatter` keeps per-row rendering cheap.
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}
