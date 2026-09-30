import Foundation
import KomodoCore

/// Reports' wording (Reports.dc.html): range titles, day spans and the "vs" phrases on the tiles.
enum ReportsFormat {
    /// "Last 7 days · Sep 21 – 27", "Today · Sat, Sep 26".
    static func rangeTitle(_ period: ReportPeriod, _ range: ReportRange, calendar: Calendar) -> String {
        switch period {
        case .today:
            "Today · "
                + range.first.startOfDay(in: calendar).formatted(
                    .dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week: "Last 7 days · " + span(range, calendar: calendar)
        case .month: "Last 30 days · " + span(range, calendar: calendar)
        case .custom: "Custom · " + span(range, calendar: calendar)
        }
    }

    /// "Sep 21 – 27" within a month and "Aug 28 – Sep 26" across two, in the order the locale writes dates.
    static func span(_ range: ReportRange, calendar: Calendar) -> String {
        let start = range.first.startOfDay(in: calendar)
        if range.first == range.last { return start.formatted(.dateTime.month(.abbreviated).day()) }
        return (start..<range.last.startOfDay(in: calendar)).formatted(.interval.month(.abbreviated).day())
    }

    /// What a tile's chip compares with: "last week", "last Sat", "prior 30 days", or the span itself.
    static func comparedWith(_ period: ReportPeriod, _ compared: ReportRange, calendar: Calendar) -> String {
        switch period {
        case .today: "last " + compared.first.startOfDay(in: calendar).formatted(.dateTime.weekday(.abbreviated))
        case .week: "last week"
        case .month: "prior 30 days"
        case .custom: span(compared, calendar: calendar)
        }
    }

    /// "31.5" for the Hours tile, one decimal under 100 hours.
    static func hours(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        return hours >= 100 ? String(Int(hours.rounded())) : String(format: "%.1f", hours)
    }
}
