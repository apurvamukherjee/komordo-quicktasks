import KomodoCore
import SwiftUI

/// Sessions (FEATURES §4.15, DESIGN_SYSTEM §13.13): totals and actions over every work session and break in the
/// range, a day at a time, each row with Edit and Delete behind ⋯ and on right-click.
struct SessionsReport: View {
    @Bindable var store: BoardStore
    /// Opens the add or edit sheet; nil entry adds.
    var edit: (SessionLog.Entry?) -> Void

    private static let page = 100
    /// How many of the newest sessions are shown; Load earlier adds a page.
    @State private var shown = Self.page

    var body: some View {
        let log = SessionLog(store.reportData, range: store.reportRange, includesBreaks: store.reports.showsBreaks)
        VStack(alignment: .leading, spacing: 14) {
            toolbar(log)
            table(log)
        }
        // A new range or filter starts from its newest page again.
        .onChange(of: store.reportRange) { shown = Self.page }
    }

    private func toolbar(_ log: SessionLog) -> some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Total")
                Text(DurationFormat.short(log.days.reduce(0) { $0 + $1.work + $1.breaks }))
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(Palette.textPrimary)
                Text("·").foregroundStyle(Palette.textDisabled)
                (Text("\(log.taskCount)").font(.system(size: 15)).foregroundColor(Palette.textPrimary) + Text(" tasks"))
                Text("·").foregroundStyle(Palette.textDisabled)
                (Text("\(log.entryCount)").font(.system(size: 15)).foregroundColor(Palette.textPrimary)
                    + Text(" sessions"))
            }
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Palette.textSecondary)
            Spacer()
            HStack(spacing: Space.s2) {
                Toggle("Breaks", isOn: $store.reports.showsBreaks)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(
                        Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08)))
                Button("Add", systemImage: "plus") { edit(nil) }
                    .buttonStyle(.komodo(.secondary))
                Menu {
                    Button("Export PDF", action: store.exportSessionsPDF)
                        .keyboardShortcut("p", modifiers: .command)
                    Button("Export CSV", action: store.exportSessionsCSV)
                    Divider()
                    Text("Uses the current filters")
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.button)
                .buttonStyle(.komodo(.secondary))
                .fixedSize()
                .disabled(log.entryCount == 0)
            }
        }
        .frame(height: 40)
    }

    private var columns: [ReportTableColumn] {
        [.flexible, .fixed(150), .fixed(44), .fixed(84), .fixed(96), .fixed(96), .fixed(110), .fixed(36)]
    }

    private func table(_ log: SessionLog) -> some View {
        VStack(spacing: 0) {
            ReportTableHeader(columns: columns, titles: ["TASK", "LIST", "#", "DATE", "START", "END", "DURATION", ""])
            LazyVStack(spacing: 0) {
                ForEach(log.latest(shown), id: \.date) { day in
                    dayDivider(day)
                    ForEach(day.entries) { entry in
                        row(entry)
                    }
                }
            }
            if log.entryCount > 0 { footer(log) }
        }
        .padding(.top, 6)
        .padding(.horizontal, Space.s2)
        .padding(.bottom, Space.s1)
        .spotlight(Palette.violet, lifts: false) { CardSurface() }
    }

    /// Reports.dc.html's footer: how many sessions show, and Load earlier while some don't.
    private func footer(_ log: SessionLog) -> some View {
        HStack {
            Text("Showing \(min(shown, log.entryCount)) of \(log.entryCount) sessions")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Palette.textMuted)
            Spacer()
            if shown < log.entryCount {
                Button("Load earlier") { shown += Self.page }
                    .buttonStyle(.komodo(.ghost, size: .small))
            }
        }
        .padding(.horizontal, Space.s4)
        .frame(height: 40)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
        .padding(.top, 4)
    }

    /// "SAT, SEP 26 · TODAY" across a hairline, with the day's totals.
    private func dayDivider(_ day: SessionLog.Day) -> some View {
        let date = day.date.startOfDay(in: store.calendar)
        let label = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()
        return HStack(spacing: 10) {
            Text(day.date == store.today ? "\(label) · TODAY" : label)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textBody)
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            Text(
                "\(DurationFormat.short(day.work)) tasks"
                    + (store.reports.showsBreaks ? " · \(DurationFormat.short(day.breaks)) breaks" : "")
            )
            .font(.system(size: 11.5).monospacedDigit())
            .foregroundStyle(Palette.textMuted)
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, 10)
        .frame(height: 34)
    }

    private func row(_ entry: SessionLog.Entry) -> some View {
        let isLive = entry.end == nil
        return ReportTableRow(columns: columns, tint: entry.isBreak ? Palette.green : .white) {
            titleCell(entry, isLive: isLive)
            listCell(entry)
            Text(number(entry)).foregroundStyle(entry.isBreak ? Palette.textMuted : Palette.textSecondary)
            Text(entry.start.formatted(.dateTime.month(.abbreviated).day())).foregroundStyle(Palette.textSecondary)
            Text(entry.start.formatted(date: .omitted, time: .shortened))
            Text(entry.end?.formatted(date: .omitted, time: .shortened) ?? "Now")
                .foregroundStyle(isLive ? Palette.limeText : Palette.textBody)
            Text(DurationFormat.short(entry.duration(until: store.now)))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
            Menu {
                menuItems(entry)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.icon(.compact))
            .disabled(isLive)
            .help(isLive ? "The running session can't be edited" : "Session actions")
        }
        .frame(height: 38)
        .contextMenu { if !isLive { menuItems(entry) } }
    }

    @ViewBuilder private func titleCell(_ entry: SessionLog.Entry, isLive: Bool) -> some View {
        HStack(spacing: 9) {
            switch entry.kind {
            case .work(_, _, let title, _):
                Text(title).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
            case .breakTime:
                Label("Break", systemImage: "cup.and.saucer")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Palette.greenText)
            }
            if isLive {
                HStack(spacing: 5) {
                    Circle().fill(Palette.lime).frame(width: 5, height: 5)
                    Text("LIVE")
                }
                .font(.system(size: 9.5, weight: .heavy))
                .tracking(0.76)
                .foregroundStyle(Palette.limeText)
                .padding(.horizontal, 7)
                .frame(height: 18)
                .background(Palette.lime.opacity(0.12), in: Capsule())
            }
        }
    }

    @ViewBuilder private func listCell(_ entry: SessionLog.Entry) -> some View {
        if case .work(_, let listID, _, _) = entry.kind {
            ReportListLabel(list: store.allLists.first { $0.id == listID })
        } else {
            Text("—").foregroundStyle(Palette.textMuted)
        }
    }

    private func number(_ entry: SessionLog.Entry) -> String {
        if case .work(_, _, _, let number) = entry.kind { return "\(number)" }
        return "—"
    }

    @ViewBuilder private func menuItems(_ entry: SessionLog.Entry) -> some View {
        Button("Edit session…", systemImage: "pencil") { edit(entry) }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            switch entry.kind {
            case .work(let taskID, _, _, let number): store.deleteSession(number, of: taskID)
            case .breakTime(let breakID): store.deleteBreak(breakID)
            }
        }
    }
}

#Preview("Sessions") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    return ScrollView { SessionsReport(store: store, edit: { _ in }).padding(Space.s6) }
        .frame(width: 1128, height: 900)
        .background(Palette.bg)
}
