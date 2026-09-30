import AppKit
import KomodoCore
import OSLog
import SwiftUI
import UniformTypeIdentifiers

extension BoardStore {
    /// The Sessions log as Reports shows it, with the current list, range and breaks filters.
    var sessionLog: SessionLog {
        SessionLog(reportData, range: reportRange, includesBreaks: reports.showsBreaks)
    }

    /// Export ▸ Export CSV (FEATURES §4.15).
    func exportSessionsCSV() { saveExport(named: "csv", type: .commaSeparatedText, write: writeSessionsCSV) }

    /// Export ▸ Export PDF.
    func exportSessionsPDF() { saveExport(named: "pdf", type: .pdf, write: writeSessionsPDF) }

    func writeSessionsCSV(to url: URL) throws {
        let csv = sessionLog.csv(
            listNames: Dictionary(allLists.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }),
            now: now, calendar: calendar)
        try Data(csv.utf8).write(to: url)
    }

    /// The log on Letter pages, dark text on white so it prints.
    func writeSessionsPDF(to url: URL) throws {
        var box = CGRect(origin: .zero, size: SessionsPrintout.pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        for page in SessionsPrintout.pages(for: self) {
            let renderer = ImageRenderer(content: page)
            renderer.proposedSize = ProposedViewSize(SessionsPrintout.pageSize)
            context.beginPDFPage(nil)
            renderer.render { _, draw in draw(context) }
            context.endPDFPage()
        }
        context.closePDF()
    }

    private func saveExport(named ext: String, type: UTType, write: (URL) throws -> Void) {
        let panel = NSSavePanel()
        let span = ReportsFormat.span(reportRange, calendar: calendar).replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "Komodo Sessions \(span).\(ext)"
        panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try write(url)
            toasts.show(
                Toast(
                    kind: .success, message: "Sessions exported: \(url.lastPathComponent)",
                    action: .init(title: "Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }))
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "reports").error("Export failed: \(error)")
            toasts.show(Toast(kind: .error, message: "Couldn't export sessions", detail: url.lastPathComponent))
        }
    }
}

/// One printed page of the Sessions log: a title on the first, then rows a day at a time.
struct SessionsPrintout: View {
    static let pageSize = CGSize(width: 612, height: 792)
    static let rowsPerPage = 38

    enum Line: Hashable {
        case day(String, String)
        case entry([String])
    }

    var title: String?
    var lines: [Line]

    @MainActor static func pages(for store: BoardStore) -> [SessionsPrintout] {
        let log = store.sessionLog
        var lines: [Line] = []
        for day in log.days {
            let date = day.date.startOfDay(in: store.calendar)
            lines.append(
                .day(
                    date.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    "\(DurationFormat.short(day.work)) tasks · \(DurationFormat.short(day.breaks)) breaks"))
            for entry in day.entries {
                var cells: [String]
                switch entry.kind {
                case .work(_, let listID, let title, let number):
                    cells = [title, store.allLists.first { $0.id == listID }?.name ?? "", "\(number)"]
                case .breakTime:
                    cells = ["Break", "", ""]
                }
                cells += [
                    entry.start.formatted(date: .omitted, time: .shortened),
                    entry.end?.formatted(date: .omitted, time: .shortened) ?? "Now",
                    DurationFormat.short(entry.duration(until: store.now)),
                ]
                lines.append(.entry(cells))
            }
        }
        let chunks = stride(from: 0, to: max(lines.count, 1), by: rowsPerPage).map {
            Array(lines[$0..<min($0 + rowsPerPage, lines.count)])
        }
        let heading =
            "Sessions · \(ReportsFormat.rangeTitle(store.reports.period, store.reportRange, calendar: store.calendar))"
        return chunks.enumerated().map { SessionsPrintout(title: $0.offset == 0 ? heading : nil, lines: $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title).font(.system(size: 16, weight: .bold)).padding(.bottom, 14)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .day(let date, let totals):
                    HStack {
                        Text(date).font(.system(size: 10, weight: .bold))
                        Spacer()
                        Text(totals).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    .frame(height: 18)
                    .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.15)).frame(height: 0.5) }
                case .entry(let cells):
                    HStack(spacing: 8) {
                        Text(cells[0]).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(cells[1]).lineLimit(1).frame(width: 90, alignment: .leading)
                        Text(cells[2]).frame(width: 18, alignment: .leading)
                        Text(cells[3]).frame(width: 58, alignment: .leading)
                        Text(cells[4]).frame(width: 58, alignment: .leading)
                        Text(cells[5]).frame(width: 64, alignment: .trailing)
                    }
                    .font(.system(size: 9.5).monospacedDigit())
                    .frame(height: 16)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.black)
        .padding(40)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .topLeading)
        .background(.white)
    }
}
