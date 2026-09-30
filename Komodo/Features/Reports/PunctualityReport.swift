import Charts
import KomodoCore
import SwiftUI

/// Punctuality (DESIGN_SYSTEM §13.13): the share finished early or on time, eight weeks of accuracy, and every
/// measured task against its estimate, largest overrun first.
struct PunctualityReport: View {
    var store: BoardStore

    var body: some View {
        let data = store.reportData
        let range = store.reportRange
        let firstWeekday = store.settings.weekStart.firstWeekday
        let punctuality = Punctuality(data, range: range, firstWeekday: firstWeekday)
        let compared = range.compared(to: store.reports.period, calendar: store.calendar)
        let before = Punctuality(data, range: compared, firstWeekday: firstWeekday).summary.onEstimate
        VStack(spacing: Space.s4) {
            HStack(spacing: Space.s4) {
                AccuracyCard(
                    summary: punctuality.summary, before: before,
                    versus: ReportsFormat.comparedWith(store.reports.period, compared, calendar: store.calendar)
                )
                .frame(width: 444)
                WeeklyAccuracy(weeks: punctuality.weeks, calendar: store.calendar)
            }
            EstimateTable(store: store, rows: punctuality.rows, summary: punctuality.summary)
        }
    }
}

// MARK: - Accuracy

private enum Outcome: CaseIterable {
    case early
    case onTime
    case late

    var title: String {
        switch self {
        case .early: "Early"
        case .onTime: "On time"
        case .late: "Late"
        }
    }

    var color: Color {
        switch self {
        case .early: Palette.green
        case .onTime: Palette.blue
        case .late: Palette.amber
        }
    }

    var text: Color {
        switch self {
        case .early: Palette.greenText
        case .onTime: Palette.blueText
        case .late: Palette.amberText
        }
    }

    var chip: Chip.Tint {
        switch self {
        case .early: .green
        case .onTime: .blue
        case .late: .amber
        }
    }

    func count(_ summary: DaySummary) -> Int {
        switch self {
        case .early: summary.early
        case .onTime: summary.onTime
        case .late: summary.late
        }
    }

    /// FEATURES §4.14's ±10% band.
    init(estimate: TimeInterval, actual: TimeInterval) {
        let difference = (actual - estimate) / estimate
        self =
            difference > DaySummary.onTimeTolerance
            ? .late : difference < -DaySummary.onTimeTolerance ? .early : .onTime
    }
}

private struct AccuracyCard: View {
    var summary: DaySummary
    var before: Double?
    var versus: String

    var body: some View {
        let measured = max(summary.measured, 1)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Estimate accuracy").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.textPrimary)
                Spacer()
                trend
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(summary.onEstimate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .font(.system(size: 40, weight: .heavy).monospacedDigit())
                    .tracking(-1.6)
                    .foregroundStyle(Palette.textPrimary)
                Text(
                    "finished early or on time\nacross \(summary.measured == 1 ? "1 task" : "\(summary.measured) tasks")"
                )
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, 14)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Outcome.allCases, id: \.self) { outcome in
                        let share = Double(outcome.count(summary)) / Double(measured)
                        if share > 0 {
                            Rectangle()
                                .fill(outcome.color)
                                .frame(width: max(4, (geo.size.width - 4) * share))
                                .shadow(color: outcome == .early ? Palette.green.opacity(0.7) : .clear, radius: 8)
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            .padding(.top, 22)
            HStack(alignment: .top, spacing: 2) {
                ForEach(Outcome.allCases, id: \.self) { outcome in
                    let count = outcome.count(summary)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle().fill(outcome.color).frame(width: 7, height: 7)
                            Text(outcome.title)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textBody)
                        (Text("\(count) ").font(.system(size: 15, weight: .bold))
                            + Text("· \(Int((Double(count) / Double(measured) * 100).rounded()))%")
                            .font(.system(size: 12, weight: .medium)).foregroundColor(Palette.textMuted))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, Space.s3)
            Spacer(minLength: 0)
            Text("On time means within ±10% of the estimate.")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(height: 252)
        .spotlight(Palette.green) { CardSurface() }
    }

    @ViewBuilder private var trend: some View {
        if let now = summary.onEstimate, let before {
            let points = Int(((now - before) * 100).rounded())
            if points == 0 {
                Chip("Same as \(versus)", tint: .outline, size: .compact)
            } else {
                Chip(
                    "\(points > 0 ? "+" : "−")\(abs(points)) pts vs \(versus)", tint: points > 0 ? .green : .amber,
                    icon: points > 0 ? "arrow.up.right" : "arrow.down.right", size: .compact)
            }
        }
    }
}

/// The last eight weeks' share early or on time as a glowing lime line; hovering a week names it.
private struct WeeklyAccuracy: View {
    var weeks: [Punctuality.Week]
    var calendar: Calendar

    @State private var selected: String?

    var body: some View {
        let measured = weeks.filter { $0.accuracy != nil }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Weekly accuracy").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.textPrimary)
                    Text("Share of tasks early or on time · last 8 weeks")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer()
                HStack(spacing: 7) {
                    Capsule().fill(Palette.lime).frame(width: 14, height: 2)
                    Text("Accuracy")
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.textBody)
            }
            Chart {
                ForEach(measured, id: \.start) { week in
                    let label = self.label(week)
                    let percent = (week.accuracy ?? 0) * 100
                    LineMark(x: .value("Week", label), y: .value("Accuracy", percent))
                        .foregroundStyle(Palette.lime)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Week", label), y: .value("Accuracy", percent))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Palette.lime.opacity(0.18), Palette.lime.opacity(0)], startPoint: .top,
                                endPoint: .bottom)
                        )
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Week", label), y: .value("Accuracy", percent))
                        .foregroundStyle(Palette.lime)
                        .symbolSize(selected == label ? 110 : 55)
                        .annotation(position: .top, spacing: 8) {
                            if selected == label { tip(label: label, percent: percent) }
                        }
                }
            }
            .chartXSelection(value: $selected)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [40, 60, 80, 100]) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel { if let percent = value.as(Int.self) { Text("\(percent)%") } }
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .shadow(color: Palette.lime.opacity(0.4), radius: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, Space.s3)
        .frame(maxWidth: .infinity)
        .frame(height: 252)
        .spotlight(Palette.lime) { CardSurface() }
    }

    private func label(_ week: Punctuality.Week) -> String {
        week.start.startOfDay(in: calendar).formatted(.dateTime.month(.abbreviated).day())
    }

    private func tip(label: String, percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Week of \(label)").font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
            Text("\(Int(percent.rounded()))% early or on time")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .popoverSurface()
    }
}

// MARK: - Table

/// Task · List · Est · Actual · Δ, where Δ is a bar growing right for overruns and left for time to spare.
private struct EstimateTable: View {
    var store: BoardStore
    var rows: [Punctuality.Row]
    var summary: DaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Estimate vs actual").font(.system(size: 15, weight: .bold)).foregroundStyle(
                        Palette.textPrimary)
                    Text("Sorted by largest overrun").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Outcome.allCases.reversed(), id: \.self) { outcome in
                        Chip(
                            "\(outcome.count(summary)) \(outcome.title.lowercased())", tint: outcome.chip,
                            size: .compact)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, Space.s3)
            ReportTableHeader(columns: columns, titles: ["TASK", "LIST", "EST", "ACTUAL", "Δ"])
            LazyVStack(spacing: 0) {
                ForEach(rows, id: \.taskID) { row in
                    ReportTableRow(columns: columns) {
                        Text(row.title)
                            .font(.system(size: 13.5, weight: .medium))
                            .lineLimit(1)
                        ReportListLabel(list: store.allLists.first { $0.id == row.listID })
                        Text(DurationFormat.short(row.estimate)).foregroundStyle(Palette.textSecondary)
                        Text(DurationFormat.short(row.actual))
                        DeltaCell(row: row)
                    }
                    .frame(height: 42)
                }
            }
        }
        .padding(.top, 18)
        .padding([.horizontal, .bottom], Space.s2)
        .spotlight(Palette.amber, lifts: false) { CardSurface() }
    }

    private var columns: [ReportTableColumn] { [.flexible, .fixed(150), .fixed(96), .fixed(96), .fixed(210)] }
}

private struct DeltaCell: View {
    var row: Punctuality.Row

    var body: some View {
        let outcome = Outcome(estimate: row.estimate, actual: row.actual)
        let delta = row.delta
        let width = min(40, abs(delta) / (45 * 60) * 40)
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06)).frame(width: 80, height: 6)
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 10).offset(x: 40)
                UnevenRoundedRectangle(
                    topLeadingRadius: delta < 0 ? 3 : 0, bottomLeadingRadius: delta < 0 ? 3 : 0,
                    bottomTrailingRadius: delta < 0 ? 0 : 3, topTrailingRadius: delta < 0 ? 0 : 3
                )
                .fill(outcome.color)
                .frame(width: width, height: 6)
                .offset(x: delta < 0 ? 40 - width : 40)
            }
            .frame(width: 80)
            Text(
                "\(delta > 0 ? "+" : delta < 0 ? "−" : "±")\(DurationFormat.short(abs(delta)))"
                    + (outcome == .onTime ? " · on time" : "")
            )
            .font(.system(size: 13, weight: .bold).monospacedDigit())
            .foregroundStyle(outcome.text)
            .lineLimit(1)
        }
    }
}

#Preview("Punctuality") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    return ScrollView { PunctualityReport(store: store).padding(Space.s6) }
        .frame(width: 1128, height: 900)
        .background(Palette.bg)
}
