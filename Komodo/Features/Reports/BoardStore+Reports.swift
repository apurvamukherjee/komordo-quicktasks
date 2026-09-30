import KomodoCore

/// What Reports shows (DESIGN_SYSTEM §13.12–13.13): the tab, the range and list filters, and Sessions' breaks
/// switch. It survives leaving Reports, so coming back finds it as it was.
struct ReportsState: Equatable {
    enum Tab: String, CaseIterable, Sendable {
        case overview
        case punctuality
        case time
        case sessions

        var title: String {
            switch self {
            case .overview: "Overview"
            case .punctuality: "Punctuality"
            case .time: "Time spent"
            case .sessions: "Sessions"
            }
        }
    }

    var tab = Tab.overview
    var period = ReportPeriod.week
    /// nil is All lists.
    var listID: String?
    var showsBreaks = true
}

extension BoardStore {
    func showReports(_ tab: ReportsState.Tab? = nil) {
        if let tab { reports.tab = tab }
        inspect(nil)
        page = .reports
    }

    var reportRange: ReportRange {
        ReportRange(reports.period, today: today, firstWeekday: settings.weekStart.firstWeekday, calendar: calendar)
    }

    /// The report inputs for the chosen list: tasks on the Board, archived ones and those of archived lists.
    var reportData: ReportData {
        ReportData(tasks: reportTasks, breaks: breaks, listID: reports.listID, now: now, calendar: calendar)
    }
}
