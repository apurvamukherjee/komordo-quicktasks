import KomodoCore
import SwiftUI

/// Reports (DESIGN_SYSTEM §13.12–13.13, Reports.png): a 1080 pt column with the title, the list and range filters,
/// four tabs under a lime ink line, and the chosen report. It replaces the Board beside the sidebar.
struct ReportsView: View {
    @Bindable var store: BoardStore

    @State private var isPickingDates = false
    /// The session being added or edited.
    @State private var sessionSheet: SessionSheetRequest?
    @Namespace private var ink

    var body: some View {
        let data = store.reportData
        let range = store.reportRange
        let overview = ReportOverview(data, range: range)
        VStack(alignment: .leading, spacing: 0) {
            header(overview)
            tabs(sessionCount: SessionLog(data, range: range, includesBreaks: store.reports.showsBreaks).entryCount)
            Group {
                if overview.isEmpty {
                    ReportsEmpty { store.showBoard() }
                } else {
                    content
                }
            }
            .padding(.top, 22)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        // The canvas's 36 pt, less the hidden title bar's safe area that Home already leaves above.
        .padding(.top, Space.s2)
        .frame(maxWidth: Layout.reportsMaxWidth)
        .padding(.horizontal, Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { background }
        .sheet(item: $sessionSheet) { request in
            SessionSheet(store: store, entry: request.entry) { sessionSheet = nil }
        }
    }

    @ViewBuilder private var content: some View {
        switch store.reports.tab {
        case .overview:
            ScrollView { OverviewReport(store: store).padding(.bottom, Space.s6) }.scrollIndicators(.never)
        case .punctuality:
            ScrollView { PunctualityReport(store: store).padding(.bottom, Space.s6) }.scrollIndicators(.never)
        case .time:
            ScrollView { TimeSpentReport(store: store).padding(.bottom, Space.s6) }.scrollIndicators(.never)
        case .sessions:
            ScrollView {
                SessionsReport(store: store) { sessionSheet = SessionSheetRequest(entry: $0) }
                    .padding(.bottom, Space.s6)
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: Header

    private func header(_ overview: ReportOverview) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reports")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.9)
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle(workDays: overview.workDays, isEmpty: overview.isEmpty))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                listPicker
                rangePicker
            }
        }
        .frame(height: 60, alignment: .bottom)
    }

    private func subtitle(workDays: Int, isEmpty: Bool) -> String {
        let list = store.reports.listID.flatMap { id in store.lists.first { $0.id == id }?.name } ?? "All lists"
        let days = isEmpty ? "no sessions" : workDays == 1 ? "1 work day" : "\(workDays) work days"
        return
            "\(ReportsFormat.rangeTitle(store.reports.period, store.reportRange, calendar: store.calendar)) · \(list) · \(days)"
    }

    private var listPicker: some View {
        Menu {
            Picker("List", selection: $store.reports.listID) {
                Label("All lists", systemImage: "square.grid.2x2").tag(String?.none)
                ForEach(store.lists) { list in
                    Text(list.name).tag(String?.some(list.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: Space.s2) {
                if let list = store.reports.listID.flatMap({ id in store.lists.first { $0.id == id } }) {
                    ListBadge(letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 20)
                    Text(list.name)
                } else {
                    Image(systemName: "square.grid.2x2")
                    Text("All lists")
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.textMuted)
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .focusEffectDisabled()
        .buttonStyle(.komodo(.secondary))
        .fixedSize()
    }

    private var rangePicker: some View {
        Picker("Range", selection: periodChoice) {
            ForEach(PeriodChoice.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .popover(isPresented: $isPickingDates, arrowEdge: .bottom) {
            CustomRangePicker(store: store)
        }
    }

    /// The segmented control's four choices; Custom keeps its dates and opens the picker.
    private enum PeriodChoice: CaseIterable {
        case today
        case week
        case month
        case custom

        var title: String {
            switch self {
            case .today: "Today"
            case .week: "7 days"
            case .month: "30 days"
            case .custom: "Custom"
            }
        }
    }

    private var periodChoice: Binding<PeriodChoice> {
        Binding {
            switch store.reports.period {
            case .today: .today
            case .week: .week
            case .month: .month
            case .custom: .custom
            }
        } set: { choice in
            switch choice {
            case .today: store.reports.period = .today
            case .week: store.reports.period = .week
            case .month: store.reports.period = .month
            case .custom:
                if case .custom = store.reports.period {
                } else {
                    store.reports.period = .custom(store.reportRange.first, store.reportRange.last)
                }
                isPickingDates = true
            }
        }
    }

    // MARK: Tabs

    private func tabs(sessionCount: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(ReportsState.Tab.allCases, id: \.self) { tab in
                let isOn = store.reports.tab == tab
                Button {
                    withAnimation(Motion.spring) { store.reports.tab = tab }
                } label: {
                    HStack(spacing: 7) {
                        Text(tab.title)
                        if tab == .sessions {
                            Text("\(sessionCount)")
                                .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                                .foregroundStyle(Palette.textBody)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(Color.white.opacity(0.07), in: Capsule())
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.textPrimary : Palette.textSecondary)
                    .padding(.horizontal, Space.s4)
                    .frame(height: 42)
                    .overlay(alignment: .bottom) {
                        if isOn {
                            Capsule()
                                .fill(Palette.lime)
                                .frame(height: 2)
                                .padding(.horizontal, Space.s4)
                                .shadow(color: Palette.lime.opacity(0.75), radius: 6)
                                .matchedGeometryEffect(id: "ink", in: ink)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, -Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
        .padding(.top, 18)
    }

    private var background: some View {
        ZStack {
            Palette.bg
            RadialGradient(
                colors: [Palette.violet.opacity(0.08), .clear], center: UnitPoint(x: 0.88, y: -0.12), startRadius: 0,
                endRadius: 900)
            RadialGradient(
                colors: [Palette.teal.opacity(0.05), .clear], center: UnitPoint(x: 0.08, y: 1.12), startRadius: 0,
                endRadius: 760)
        }
        .ignoresSafeArea()
    }
}

/// Sessions' + Add (no entry) or Edit.
private struct SessionSheetRequest: Identifiable {
    var entry: SessionLog.Entry?
    var id: String { entry?.id ?? "new" }
}

/// Custom's start and end, as native date fields.
private struct CustomRangePicker: View {
    @Bindable var store: BoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            DatePicker("From", selection: bound(\.first), displayedComponents: .date)
            DatePicker("To", selection: bound(\.last), displayedComponents: .date)
        }
        .datePickerStyle(.field)
        .padding(Space.s4)
        .frame(width: 240)
    }

    private func bound(_ end: WritableKeyPath<ReportRange, LocalDate>) -> Binding<Date> {
        Binding {
            store.reportRange[keyPath: end].startOfDay(in: store.calendar)
        } set: { date in
            var range = store.reportRange
            range[keyPath: end] = LocalDate(date, calendar: store.calendar)
            let ordered = ReportRange(first: range.first, last: range.last)
            store.reports.period = .custom(ordered.first, ordered.last)
        }
    }
}

/// DESIGN_SYSTEM §13.12's empty state.
private struct ReportsEmpty: View {
    var startTask: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(colors: [Palette.cardTop, Palette.panel], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.09))
                )
                .shadow(color: Palette.violet.opacity(0.6), radius: 20, y: 18)
            Text("No sessions in this range yet.")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text("Start a task to see your stats.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, -6)
            Button("Start a task", systemImage: "play.fill", action: startTask)
                .buttonStyle(.komodo(.primary))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 560)
        .background(
            RadialGradient(
                colors: [Palette.violet.opacity(0.07), .clear], center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0,
                endRadius: 360),
            in: shape
        )
        .overlay(shape.strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

#Preview("Reports") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    store.showReports()
    return ReportsView(store: store).frame(width: 1192, height: 1000)
}
