import Charts
import KomodoCore
import SwiftUI

/// Overview (DESIGN_SYSTEM §13.12, Reports.png): four tiles measured against the range before, Daily
/// productivity, and the most productive hour, day and month.
struct OverviewReport: View {
    var store: BoardStore

    var body: some View {
        let data = store.reportData
        let range = store.reportRange
        let overview = ReportOverview(data, range: range)
        let productivity = Productivity(
            data, range: range, firstWeekday: store.settings.weekStart.firstWeekday)
        VStack(spacing: Space.s4) {
            HStack(spacing: Space.s4) {
                ForEach(tiles(data: data, range: range, overview: overview), id: \.label) { ReportTile(tile: $0) }
            }
            DailyProductivity(
                days: overview.days, today: store.today,
                span: ReportsFormat.span(range, calendar: store.calendar), calendar: store.calendar)
            HStack(spacing: Space.s4) {
                ProductiveHourCard(hours: productivity.hours, best: productivity.bestHour, workDays: overview.workDays)
                ProductiveDayCard(
                    weekdays: productivity.weekdays, best: productivity.bestWeekday, calendar: store.calendar)
                ProductiveMonthCard(
                    months: productivity.months, best: productivity.bestMonth, current: range.last.month,
                    calendar: store.calendar)
            }
        }
    }

    // MARK: Tiles

    private func tiles(data: ReportData, range: ReportRange, overview: ReportOverview) -> [ReportTile.Model] {
        let calendar = store.calendar
        let period = store.reports.period
        let compared = range.compared(to: period, calendar: calendar)
        let before = ReportOverview(data, range: compared)
        let versus = ReportsFormat.comparedWith(period, compared, calendar: calendar)
        // Seven ranges back to this one, for each tile's sparkline.
        var ranges = [range]
        while ranges.count < 7 { ranges.insert(ranges[0].previous(calendar: calendar), at: 0) }
        let history = ranges.map { ReportOverview(data, range: $0) }
        let average = overview.averagePerTask ?? 0
        let averageInHours = average >= 100 * 60
        return [
            ReportTile.Model(
                label: "WORK DAYS", symbol: "calendar", tint: Palette.blue, glyph: Palette.blueText,
                value: "\(overview.workDays)", unit: "",
                delta: .count(overview.workDays - before.workDays, versus: versus, higherIsBetter: true),
                spark: history.map { Double($0.workDays) }),
            ReportTile.Model(
                label: "TASKS DONE", symbol: "checkmark.circle", tint: Palette.lime, glyph: Palette.limeText,
                value: "\(overview.tasksDone)", unit: "",
                delta: .count(overview.tasksDone - before.tasksDone, versus: versus, higherIsBetter: true),
                spark: history.map { Double($0.tasksDone) }),
            ReportTile.Model(
                label: "HOURS", symbol: "timer", tint: Palette.violet, glyph: Palette.violetText,
                value: ReportsFormat.hours(overview.hours), unit: "hr",
                delta: .percent(now: overview.hours, before: before.hours, versus: versus),
                spark: history.map(\.hours)),
            ReportTile.Model(
                label: "AVG / TASK", symbol: "waveform.path.ecg", tint: Palette.teal, glyph: Palette.tealText,
                value: averageInHours ? ReportsFormat.hours(average) : "\(Int((average / 60).rounded()))",
                unit: averageInHours ? "hr" : "min",
                delta: .minutes(average - (before.averagePerTask ?? average), versus: versus),
                spark: history.map { $0.averagePerTask ?? 0 }),
        ]
    }
}

// MARK: - Tile

/// A 132 pt stat tile: the icon and label, the value with its unit beside a sparkline, and the comparison chip.
struct ReportTile: View {
    struct Model {
        var label: String
        var symbol: String
        var tint: Color
        var glyph: Color
        var value: String
        var unit: String
        var delta: Delta
        var spark: [Double]
    }

    /// The chip under the value: green when it moved the good way, amber the other, outlined when unchanged.
    enum Delta {
        case same(String)
        case better(String, up: Bool)
        case worse(String, up: Bool)

        static func count(_ change: Int, versus: String, higherIsBetter: Bool) -> Delta {
            guard change != 0 else { return .same("Same as \(versus)") }
            let text = "\(change > 0 ? "+" : "−")\(abs(change)) vs \(versus)"
            return (change > 0) == higherIsBetter ? .better(text, up: change > 0) : .worse(text, up: change > 0)
        }

        static func percent(now: TimeInterval, before: TimeInterval, versus: String) -> Delta {
            guard before > 0 else {
                return now > 0 ? .better("New vs \(versus)", up: true) : .same("Same as \(versus)")
            }
            let change = Int(((now - before) / before * 100).rounded())
            guard change != 0 else { return .same("Same as \(versus)") }
            let text = "\(change > 0 ? "+" : "−")\(abs(change))% vs \(versus)"
            return change > 0 ? .better(text, up: true) : .worse(text, up: false)
        }

        /// Time per task: shorter is better.
        static func minutes(_ change: TimeInterval, versus: String) -> Delta {
            let minutes = Int((change / 60).rounded())
            guard minutes != 0 else { return .same("Same as \(versus)") }
            let text = "\(minutes > 0 ? "+" : "−")\(abs(minutes))min vs \(versus)"
            return minutes < 0 ? .better(text, up: false) : .worse(text, up: true)
        }
    }

    var tile: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReportCardTitle(symbol: tile.symbol, label: tile.label, tint: tile.tint, glyph: tile.glyph)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: Space.s2) {
                (Text(tile.value).font(.system(size: 32, weight: .heavy)).tracking(-1.1)
                    + Text(tile.unit.isEmpty ? "" : " \(tile.unit)").font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textMuted))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Sparkline(values: tile.spark, color: tile.tint)
                    .frame(width: 86, height: 32)
            }
            chip
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 132)
        .spotlight(tile.tint) { CardSurface() }
    }

    @ViewBuilder private var chip: some View {
        switch tile.delta {
        case .same(let text): Chip(text, tint: .outline, size: .compact)
        case .better(let text, let up):
            Chip(text, tint: .green, icon: up ? "arrow.up.right" : "arrow.down.right", size: .compact)
        case .worse(let text, let up):
            Chip(text, tint: .amber, icon: up ? "arrow.up.right" : "arrow.down.right", size: .compact)
        }
    }
}

/// A line over a fading area, ending on a ringed dot, scaled between the values' own low and high.
private struct Sparkline: View {
    var values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let points = self.points(in: geo.size)
            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = points.first, let last = points.last else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    for point in points { path.addLine(to: point) }
                    path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.32), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                Path { path in path.addLines(points) }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let last = points.last {
                    Circle()
                        .fill(color)
                        .overlay(Circle().stroke(Palette.card, lineWidth: 2))
                        .frame(width: 7, height: 7)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let low = values.min(), let high = values.max() else { return [] }
        let span = high - low == 0 ? 1 : high - low
        return values.enumerated().map { index, value in
            CGPoint(
                x: 3 + CGFloat(index) * (size.width - 6) / CGFloat(values.count - 1),
                y: size.height - 4 - CGFloat((value - low) / span) * (size.height - 8))
        }
    }
}

/// `.rp-ico` and the card's label: a 28 pt tinted icon tile beside the uppercase title.
struct ReportCardTitle: View {
    var symbol: String
    var label: String
    var tint: Color
    var glyph: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(label)
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - Daily productivity

/// Task hours, breaks and the total session per day as grouped bars; hovering a day names its numbers.
private struct DailyProductivity: View {
    var days: [ReportOverview.Day]
    var today: LocalDate
    var span: String
    var calendar: Calendar

    @State private var selected: String?

    private enum Series: String, CaseIterable {
        case work = "Task hours"
        case breaks = "Breaks"
        case session = "Total session"

        var color: Color {
            switch self {
            case .work: Palette.violet
            case .breaks: Palette.green
            case .session: Palette.amber
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Daily productivity")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Hours per day · \(span) · hover a day for details")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer()
                HStack(spacing: Space.s4) {
                    ForEach(Series.allCases, id: \.self) { series in
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 3).fill(series.color).frame(width: 10, height: 10)
                            Text(series.rawValue)
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.textBody)
            }
            chart
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, Space.s4)
        .frame(height: 380)
        .spotlight(Palette.violet, lifts: false) { CardSurface() }
    }

    private var chart: some View {
        let barWidth: CGFloat = days.count > 7 ? 5 : 16
        return Chart {
            ForEach(days, id: \.date) { day in
                let label = self.label(day.date)
                ForEach(Series.allCases, id: \.self) { series in
                    BarMark(
                        x: .value("Day", label), y: .value("Hours", value(series, day) / 3600),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(series.color.gradient)
                    .position(by: .value("Series", series.rawValue))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                    .opacity(selected == nil || selected == label ? 1 : 0.45)
                }
                if selected == label {
                    RuleMark(x: .value("Day", label))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tip(for: day)
                        }
                }
            }
        }
        .chartXSelection(value: $selected)
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let hours = value.as(Double.self) { Text("\(Int(hours))h") }
                }
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(Palette.textMuted)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(label.hasSuffix("today") ? Palette.limeText : Palette.textSecondary)
                    }
                }
            }
        }
    }

    private func value(_ series: Series, _ day: ReportOverview.Day) -> TimeInterval {
        switch series {
        case .work: day.work
        case .breaks: day.breaks
        case .session: day.session
        }
    }

    /// "Mon", or "Sat · today"; a month's worth of days use their numbers.
    private func label(_ date: LocalDate) -> String {
        let start = date.startOfDay(in: calendar)
        let text =
            days.count > 7
            ? start.formatted(.dateTime.day()) : start.formatted(.dateTime.weekday(.abbreviated))
        return date == today ? "\(text) · today" : text
    }

    private func tip(for day: ReportOverview.Day) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(
                "\(day.date.startOfDay(in: calendar).formatted(.dateTime.weekday(.abbreviated))) · "
                    + "\(DurationFormat.short(day.work)) tasks · \(DurationFormat.short(day.breaks)) breaks"
            )
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Palette.amber).frame(width: 7, height: 7)
                Text("\(DurationFormat.short(day.session)) total session")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.textBody)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .popoverSurface()
    }
}

// MARK: - Most productive

private struct ProductiveCard<Chart: View>: View {
    var symbol: String
    var label: String
    var tint: Color
    var glyph: Color
    var title: String
    var detail: String
    @ViewBuilder var chart: Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReportCardTitle(symbol: symbol, label: label, tint: tint, glyph: glyph)
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Space.s3)
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .padding(.top, 3)
            Spacer(minLength: 0)
            chart
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 190)
        .spotlight(tint) { CardSurface() }
    }
}

private struct ProductiveHourCard: View {
    var hours: [TimeInterval]
    var best: Int?
    var workDays: Int

    var body: some View {
        let peak = max(hours.max() ?? 0, 1)
        ProductiveCard(
            symbol: "clock", label: "MOST PRODUCTIVE HOUR", tint: Palette.lime, glyph: Palette.limeText,
            title: best.map(Self.span) ?? "—",
            detail: best.map {
                "\(DurationFormat.short(hours[$0])) focused in this hour across \(workDays == 1 ? "1 day" : "\(workDays) days")"
            } ?? "No focus in this range yet"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(hours.indices, id: \.self) { hour in
                        let share = hours[hour] / peak
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                hours[hour] == 0 ? Color.white.opacity(0.06) : Palette.lime.opacity(0.2 + 0.8 * share)
                            )
                            .shadow(color: hour == best ? Palette.lime.opacity(0.8) : .clear, radius: 6)
                    }
                }
                .frame(height: 24)
                HStack(spacing: 0) {
                    ForEach(["12 AM", "6 AM", "12 PM", "6 PM"], id: \.self) {
                        Text($0).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textMuted)
            }
        }
    }

    /// "10–11 AM", "11 AM–12 PM", "12–1 PM".
    static func span(_ hour: Int) -> String {
        func clock(_ hour: Int) -> (Int, String) { (hour % 12 == 0 ? 12 : hour % 12, hour % 24 < 12 ? "AM" : "PM") }
        let (from, fromPeriod) = clock(hour)
        let (to, toPeriod) = clock(hour + 1)
        return fromPeriod == toPeriod ? "\(from)–\(to) \(toPeriod)" : "\(from) \(fromPeriod)–\(to) \(toPeriod)"
    }
}

private struct ProductiveDayCard: View {
    var weekdays: [Productivity.Weekday]
    var best: Productivity.Weekday?
    var calendar: Calendar

    var body: some View {
        let peak = max(weekdays.map(\.tasksDone).max() ?? 0, 1)
        ProductiveCard(
            symbol: "calendar", label: "MOST PRODUCTIVE DAY", tint: Palette.blue, glyph: Palette.blueText,
            title: best.map { calendar.weekdaySymbols[$0.weekday - 1] } ?? "—", detail: detail
        ) {
            HStack(spacing: Space.s1) {
                ForEach(weekdays, id: \.weekday) { day in
                    let isBest = day.weekday == best?.weekday
                    VStack(spacing: 1) {
                        Text(calendar.veryShortWeekdaySymbols[day.weekday - 1])
                            .font(.system(size: 9.5, weight: .bold))
                        Text(day.isAhead || day.tasksDone == 0 ? "–" : "\(day.tasksDone)")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                    }
                    .foregroundStyle(day.tasksDone == 0 ? Palette.textMuted : Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        day.tasksDone == 0
                            ? Color.white.opacity(0.04)
                            : Palette.blue.opacity(0.25 + 0.45 * Double(day.tasksDone) / Double(peak)),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isBest ? Palette.blueText : .clear, lineWidth: 1.5)
                    )
                    .shadow(color: isBest ? Palette.blue.opacity(0.6) : .clear, radius: 8)
                }
            }
        }
    }

    private var detail: String {
        guard let best else { return "Nothing finished in this range yet" }
        let tasks = best.tasksDone == 1 ? "1 task done" : "\(best.tasksDone) tasks done"
        guard let share = best.onEstimate else { return tasks }
        return "\(tasks) · \(Int((share * 100).rounded()))% on estimate"
    }
}

private struct ProductiveMonthCard: View {
    var months: [TimeInterval]
    var best: Int?
    /// The range's month, whose total is still growing.
    var current: Int
    var calendar: Calendar

    var body: some View {
        let peak = max(months.max() ?? 0, 1)
        ProductiveCard(
            symbol: "trophy", label: "MOST PRODUCTIVE MONTH", tint: Palette.violet, glyph: Palette.violetText,
            title: best.map { calendar.standaloneMonthSymbols[$0 - 1] } ?? "—", detail: detail
        ) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(months.indices, id: \.self) { index in
                    let isBest = index + 1 == best
                    VStack(spacing: Space.s1) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isBest ? Palette.violet : Palette.violet.opacity(0.28))
                            .frame(height: max(8, 20 * months[index] / peak))
                            .shadow(color: isBest ? Palette.violet.opacity(0.7) : .clear, radius: 7)
                        Text(calendar.veryShortStandaloneMonthSymbols[index])
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(isBest ? Palette.textPrimary : Palette.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40, alignment: .bottom)
        }
    }

    private var detail: String {
        guard let best else { return "No focus this year yet" }
        let hours = "\(Int((months[best - 1] / 3600).rounded()))hr focused\(best == current ? " so far" : "")"
        guard best > 1, months[best - 2] > 0 else { return hours }
        let change = Int(((months[best - 1] - months[best - 2]) / months[best - 2] * 100).rounded())
        return "\(hours) · \(change >= 0 ? "+" : "−")\(abs(change))% vs \(calendar.standaloneMonthSymbols[best - 2])"
    }
}

#Preview("Overview") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    return OverviewReport(store: store)
        .padding(Space.s6)
        .frame(width: 1128)
        .background(Palette.bg)
}
