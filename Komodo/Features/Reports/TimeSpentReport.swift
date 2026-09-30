import Charts
import KomodoCore
import SwiftUI

/// Time spent (DESIGN_SYSTEM §13.13): a donut of hours by list beside a table of lists that open to show their
/// tasks. Hovering a row or a slice highlights that list in both.
struct TimeSpentReport: View {
    var store: BoardStore

    @State private var highlighted: String?
    @State private var openListID: String?

    var body: some View {
        let spent = TimeSpent(store.reportData, range: store.reportRange)
        HStack(alignment: .top, spacing: Space.s4) {
            donutCard(spent)
                .frame(width: 400)
            table(spent)
        }
    }

    // MARK: Donut

    private func donutCard(_ spent: TimeSpent) -> some View {
        let focus = spent.lists.first { $0.listID == highlighted }
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Hours by list").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.textPrimary)
                Text("\(ReportsFormat.span(store.reportRange, calendar: store.calendar)) · hover a row to highlight")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Palette.textMuted)
            }
            Chart(spent.lists, id: \.listID) { list in
                SectorMark(
                    angle: .value("Hours", list.time), innerRadius: .ratio(highlighted == list.listID ? 0.66 : 0.72),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(color(of: list.listID))
                .opacity(highlighted == nil || highlighted == list.listID ? 1 : 0.35)
            }
            .chartLegend(.hidden)
            .chartBackground { _ in
                VStack(spacing: Space.s1) {
                    Text(focus.map { name(of: $0.listID).uppercased() } ?? totalLabel)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(Typography.Tracking.label)
                        .foregroundStyle(Palette.textMuted)
                    Text(DurationFormat.short(focus?.time ?? spent.total))
                        .font(.system(size: 26, weight: .heavy).monospacedDigit())
                        .tracking(-0.8)
                        .foregroundStyle(Palette.textPrimary)
                    Text(
                        focus.map { "\(percent(spent.share(of: $0.time)))% · \(count($0.tasks.count, "task"))" }
                            ?? "\(count(spent.taskCount, "task")) · \(count(spent.lists.count, "list"))"
                    )
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(width: 240, height: 240)
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .animation(Motion.spring, value: highlighted)
            Spacer(minLength: Space.s5)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: Space.s2) {
                ForEach(spent.lists, id: \.listID) { list in
                    HStack(spacing: Space.s2) {
                        RoundedRectangle(cornerRadius: 3).fill(color(of: list.listID)).frame(width: 10, height: 10)
                        Text(name(of: list.listID)).lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(percent(spent.share(of: list.time)))%").foregroundStyle(Palette.textMuted)
                    }
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Palette.textBody)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(minHeight: 520, alignment: .top)
        .spotlight(highlighted.map(color(of:)) ?? Palette.lime) { CardSurface() }
    }

    // MARK: Table

    private var columns: [ReportTableColumn] { [.flexible, .fixed(120), .fixed(210)] }

    private func table(_ spent: TimeSpent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Time spent").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.textPrimary)
                    Text("Click a list to see its tasks").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                }
                Spacer()
                Chip("\(count(spent.lists.count, "list")) · \(count(spent.taskCount, "task"))", size: .compact)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, Space.s3)
            ReportTableHeader(columns: columns, titles: ["LIST", "HOURS", "%"])
            ForEach(spent.lists, id: \.listID) { list in
                listRow(list, spent: spent)
                if openListID == list.listID {
                    ForEach(list.tasks, id: \.id) { task in
                        ReportTableRow(columns: columns) {
                            Text(task.title).lineLimit(1).padding(.leading, 46)
                            Text(DurationFormat.short(task.time))
                            ShareBar(share: list.time > 0 ? task.time / list.time : 0, color: color(of: list.listID))
                        }
                        .frame(height: 36)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, Space.s2)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .top)
        .spotlight(Palette.lime, lifts: false) { CardSurface() }
    }

    private func listRow(_ list: TimeSpent.List, spent: TimeSpent) -> some View {
        let isOpen = openListID == list.listID
        return Button {
            withAnimation(Motion.spring) { openListID = isOpen ? nil : list.listID }
        } label: {
            ReportTableRow(columns: columns, tint: highlighted == list.listID ? color(of: list.listID) : .white) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.textMuted)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    ReportListLabel(list: store.allLists.first { $0.id == list.listID })
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(count(list.tasks.count, "task")).font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                }
                Text(DurationFormat.short(list.time)).foregroundStyle(Palette.textPrimary)
                ShareBar(share: spent.share(of: list.time), color: color(of: list.listID))
            }
            .frame(height: 46)
        }
        .buttonStyle(.plain)
        .onHover { highlighted = $0 ? list.listID : highlighted == list.listID ? nil : highlighted }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
    }

    // MARK: Helpers

    private var totalLabel: String {
        switch store.reports.period {
        case .today: "TOTAL · TODAY"
        case .week: "TOTAL · 7 DAYS"
        case .month: "TOTAL · 30 DAYS"
        case .custom: "TOTAL"
        }
    }

    private func color(of listID: String) -> Color {
        (store.allLists.first { $0.id == listID }.flatMap { ListColor(rawValue: $0.color) } ?? .lime).fill
    }

    private func name(of listID: String) -> String { store.allLists.first { $0.id == listID }?.name ?? "—" }

    private func percent(_ share: Double) -> Int { Int((share * 100).rounded()) }

    private func count(_ number: Int, _ noun: String) -> String { number == 1 ? "1 \(noun)" : "\(number) \(noun)s" }
}

/// A 120 pt track filled to the share in the list's color, with the percentage beside it.
private struct ShareBar: View {
    var share: Double
    var color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().fill(color).frame(width: 120 * min(1, max(0, share)))
            }
            .frame(width: 120, height: 6)
            Text("\(Int((share * 100).rounded()))%")
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

#Preview("Time spent") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    return ScrollView { TimeSpentReport(store: store).padding(Space.s6) }
        .frame(width: 1128, height: 800)
        .background(Palette.bg)
}
