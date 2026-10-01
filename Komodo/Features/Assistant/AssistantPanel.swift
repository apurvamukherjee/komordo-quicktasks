import KomodoCore
import SwiftUI

/// The Assistant's popover (DESIGN_SYSTEM §13.26, Assistant.png): 360 × 520 above the bubble, with the brain in
/// the header, the conversation in the body and the input at the foot.
struct AssistantPanel: View {
    @Bindable var store: BoardStore
    @FocusState private var isInputFocused: Bool

    private var model: AssistantModel { store.assistant }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s3) { content }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            footer
        }
        .frame(width: 360, height: 520)
        .background(
            RadialGradient(
                colors: [Palette.lime.opacity(0.08), .clear], center: UnitPoint(x: 0.5, y: -0.08), startRadius: 0,
                endRadius: 260)
        )
        .popoverSurface(tint: Palette.lime)
        .onAppear { isInputFocused = true }
        .onExitCommand { model.isOpen = false }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 9) {
            AssistantMark(side: 26)
            Text("Assistant").font(.system(size: 14.5, weight: .bold)).foregroundStyle(Palette.textPrimary)
            brainChip
            Spacer()
            Button {
                model.isOpen = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.komodo(.ghost, size: .small))
            .accessibilityLabel("Close")
            .keyboardShortcut(.cancelAction)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 50)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
    }

    @ViewBuilder private var brainChip: some View {
        switch model.brain ?? AssistantBrain.pick(store.settings) {
        case .onDevice: Chip("On this Mac", tint: .green, icon: "checkmark.shield", size: .compact)
        case .claude: Chip("Claude · your key", tint: .amber, size: .compact)
        case nil: EmptyView()
        }
    }

    // MARK: Body

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .empty: welcome
        case .thinking:
            you
            thinking
        case .proposal:
            you
            answer(model.reply)
            proposal
        case .discarded:
            you
            HStack {
                Text("Discarded. Nothing changed.").font(.system(size: 12.5)).foregroundStyle(Palette.textSecondary)
                Spacer()
                Button("Show again") { model.showAgain() }.buttonStyle(.komodo(.secondary, size: .small))
            }
        case .applied:
            you
            appliedCard
            answer(model.reply)
        case .failed(let message):
            if !model.prompt.isEmpty { you }
            HStack(alignment: .top, spacing: Space.s2) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(Palette.dangerText)
                Text(message).foregroundStyle(Palette.textBody)
            }
            .font(.system(size: 12.5))
            if !model.prompt.isEmpty {
                Button("Try again") { model.send(model.prompt, store: store) }
                    .buttonStyle(.komodo(.secondary, size: .small))
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            AssistantMark(side: 50, isTile: true).padding(.top, 14)
            Text(greeting).font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.textPrimary)
            Text("Type or talk. I'll turn it into tasks and show you a preview before anything changes.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("TRY")
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textMuted)
                .padding(.top, Space.s2)
            ForEach(suggestions, id: \.text) { suggestion in
                Button {
                    model.draft = suggestion.text
                    isInputFocused = true
                } label: {
                    Label {
                        Text(suggestion.label)
                    } icon: {
                        Image(systemName: suggestion.symbol)
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.textBody)
                    .padding(.leading, 11)
                    .padding(.trailing, 13)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.045), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// "Good afternoon." by the clock, as on the canvas.
    private var greeting: String {
        switch store.calendar.component(.hour, from: store.now) {
        case 5..<12: "Good morning."
        case 12..<17: "Good afternoon."
        default: "Good evening."
        }
    }

    /// Assistant.png's three, naming real tasks when the board has them.
    private var suggestions: [(label: AttributedString, text: String, symbol: String)] {
        let open = store.tasks.filter { !$0.isDone }
        var items: [(AttributedString, String, String)] = [
            (AttributedString("Brain dump my day"), "", "line.3.horizontal")
        ]
        if let first = open.first {
            items.append(
                (mention("Move ", first.title, " to tomorrow"), "Move @\(first.title) to tomorrow", "arrow.right"))
        }
        if let second = open.dropFirst().first {
            items.append((mention("Log 30min on ", second.title, ""), "Log 30min on @\(second.title)", "clock"))
        }
        return items
    }

    private func mention(_ before: String, _ name: String, _ after: String) -> AttributedString {
        var at = AttributedString("@" + name)
        at.foregroundColor = Palette.limeText
        at.font = .system(size: 12.5, weight: .semibold)
        return AttributedString(before) + at + AttributedString(after)
    }

    private var you: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text("You · " + (model.sentAt ?? store.now).formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
            Text(model.prompt)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(model.phase == .applied ? 1 : nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [Palette.lime.opacity(0.14), Palette.teal.opacity(0.08)], startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 4, topTrailingRadius: 14)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 4, topTrailingRadius: 14
                    )
                    .strokeBorder(Palette.lime.opacity(0.25), lineWidth: 1)
                )
                .frame(maxWidth: 292, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func answer(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !text.isEmpty {
                HStack(alignment: .top, spacing: Space.s2) {
                    AssistantMark(side: 20)
                    Text(text).font(.system(size: 13)).foregroundStyle(Palette.textBody)
                }
            }
            ForEach(model.problems, id: \.self) { problem in
                Label(problem, systemImage: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.amberText)
            }
        }
    }

    private var thinking: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Space.s2) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(Palette.greenText)
                    Text(model.brain == .claude ? "Asking Claude" : "Thinking on this Mac")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.greenText)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(Palette.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(model.brain == .claude ? store.settings.claudeModel : "Apple on-device model")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textTertiary)
            }
            ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
        }
    }

    // MARK: Proposal

    @ViewBuilder private var proposal: some View {
        if model.proposals.isEmpty {
            EmptyView()
        } else {
            HStack {
                Text("PROPOSED (\(model.included.count))")
                    .font(Typography.label)
                    .tracking(Typography.Tracking.label)
                    .foregroundStyle(Palette.limeText)
                Spacer()
                Text("Click to edit · untick to leave out").font(.system(size: 11)).foregroundStyle(Palette.textMuted)
            }
            ForEach(Bindable(model).proposals) { $proposal in
                ProposalRow(store: store, proposal: $proposal)
            }
            HStack {
                Button("Discard") { model.discard() }.buttonStyle(.komodo(.secondary))
                Spacer()
                Text("Undo anytime").font(.system(size: 11.5)).foregroundStyle(Palette.textMuted)
                Spacer()
                Button(addLabel, systemImage: "plus") { model.apply(store: store) }
                    .buttonStyle(.komodo(.primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.included.isEmpty)
            }
            .padding(.top, Space.s1)
        }
    }

    /// "Add 3", or "Apply 2" when every row changes a task that exists.
    private var addLabel: String {
        let count = model.included.count
        let onlyEdits = model.included.allSatisfy { $0.kind != .add }
        return count == 0 ? "Add" : "\(onlyEdits ? "Apply" : "Add") \(count)"
    }

    // MARK: Applied

    private var appliedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 30, height: 30)
                    .background(Palette.green, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(appliedTitle).font(.system(size: 16, weight: .heavy)).foregroundStyle(Palette.limeText)
                    Text(appliedDetail).font(.system(size: 11.5)).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undoApplied() }
                    .buttonStyle(.komodo(.secondary, size: .small))
            }
            FlowLayout(spacing: 6) {
                ForEach(model.applied) { proposal in
                    HStack(spacing: 6) {
                        badge(for: proposal.task)
                        Text(proposal.task.title).fontWeight(.semibold).foregroundStyle(Palette.textPrimary)
                        Text("· " + store.assistantWhen(proposal.task)).foregroundStyle(Palette.limeText)
                    }
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .padding(.leading, 5)
                    .padding(.trailing, 10)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(
                            Color.white.opacity(0.08), lineWidth: 1))
                }
            }
        }
        .padding(14)
        .spotlight(Palette.green, radius: Radius.tile, lifts: false) {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(Palette.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .strokeBorder(Palette.green.opacity(0.3), lineWidth: 1))
        }
    }

    private var appliedTitle: String {
        let added = model.applied.filter { $0.kind == .add }.count
        let changed = model.applied.count - added
        switch (added, changed) {
        case (_, 0): return "Added \(added) task\(added == 1 ? "" : "s")"
        case (0, _): return "Updated \(changed) task\(changed == 1 ? "" : "s")"
        default: return "Added \(added) · updated \(changed)"
        }
    }

    /// "2 to Personal · 1 to Work".
    private var appliedDetail: String {
        var counts: [(String, Int)] = []
        for proposal in model.applied {
            let name = store.lists.first { $0.id == proposal.task.listID }?.name ?? "Komodo"
            if let index = counts.firstIndex(where: { $0.0 == name }) {
                counts[index].1 += 1
            } else {
                counts.append((name, 1))
            }
        }
        return counts.map { "\($0.1) to \($0.0)" }.joined(separator: " · ")
    }

    private func badge(for task: TaskItem) -> some View {
        let list = store.lists.first { $0.id == task.listID }
        return ListBadge(
            letter: list?.letter ?? "?", color: list.flatMap { ListColor(rawValue: $0.color) } ?? .lime, side: 18)
    }

    // MARK: Footer

    private var footer: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 6) {
            TextField("Type or hold mic to talk…", text: Bindable(model).draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .focusEffectDisabled()
                .onSubmit { model.send(store: store) }
                .disabled(model.phase == .thinking)
            if model.phase == .thinking {
                Button {
                    model.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.komodo(.ghost, size: .small))
                .accessibilityLabel("Stop")
            } else {
                Button {
                    model.send(store: store)
                } label: {
                    Image(systemName: "return")
                }
                .buttonStyle(.komodo(.ghost, size: .small))
                .accessibilityLabel("Send")
                .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(minHeight: 42)
        .background(isInputFocused ? Palette.card : Color.white.opacity(0.04), in: shape)
        .overlay(shape.strokeBorder(isInputFocused ? Palette.teal.opacity(0.6) : Palette.border, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .overlay(alignment: .top) { Rectangle().fill(Palette.border).frame(height: 1) }
    }
}

/// One proposal: tick, editable title, and its list, when and estimate as chips.
private struct ProposalRow: View {
    var store: BoardStore
    @Binding var proposal: AssistantProposal

    var body: some View {
        let task = proposal.task
        let list = store.lists.first { $0.id == task.listID }
        HStack(alignment: .top, spacing: 10) {
            Toggle("Include \(task.title)", isOn: $proposal.isIncluded)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                TextField("Title", text: $proposal.task.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(proposal.isIncluded ? Palette.textPrimary : Palette.textSecondary)
                    .strikethrough(!proposal.isIncluded)
                HStack(spacing: 5) {
                    ListBadge(
                        letter: list?.letter ?? "?", color: list.flatMap { ListColor(rawValue: $0.color) } ?? .lime,
                        side: 18)
                    if case .edit = proposal.kind { Chip("Edit", tint: .outline, size: .compact) }
                    Chip(
                        store.assistantWhen(task), tint: task.column(in: store.week) == .today ? .lime : .blue,
                        icon: "calendar", size: .compact)
                    if let estimate = task.estimate {
                        Chip(DurationFormat.compact(estimate), icon: "timer", size: .compact)
                    }
                    if let minutes = proposal.loggedMinutes {
                        Chip("+\(minutes)min logged", tint: .green, icon: "clock", size: .compact)
                    }
                    if task.isDone { Chip("Done", tint: .green, icon: "checkmark", size: .compact) }
                }
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spotlight(Palette.lime, radius: 12, lifts: false) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        }
        .opacity(proposal.isIncluded ? 1 : 0.45)
        .animation(Motion.fast, value: proposal.isIncluded)
    }
}

/// A shimmering placeholder row while the brain thinks; still under Reduce Motion.
private struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            bar(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 8) {
                bar(width: 170, height: 12)
                HStack(spacing: 6) {
                    bar(width: 110, height: 18)
                    bar(width: 44, height: 18)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 2 }
        }
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.09), .clear],
                    startPoint: UnitPoint(x: phase, y: 0.5), endPoint: UnitPoint(x: phase + 0.6, y: 0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .frame(width: width, height: height)
    }
}

/// The Assistant's mark: sparkles on the teal-to-lime gradient, or on a tinted tile for the welcome.
struct AssistantMark: View {
    var side: CGFloat
    var isTile = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: side * 0.48, weight: .bold))
            .foregroundStyle(isTile ? Palette.limeText : Palette.onAccent)
            .frame(width: side, height: side)
            .background {
                let shape = RoundedRectangle(cornerRadius: side * 0.33, style: .continuous)
                if isTile {
                    shape.fill(Palette.lime.opacity(0.12)).overlay(shape.strokeBorder(Palette.lime.opacity(0.3)))
                } else {
                    shape.fill(
                        LinearGradient(
                            colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
    }
}

extension BoardStore {
    /// "Today", "Tomorrow 7:00 AM", "Fri", "Oct 12", or the column for a task without a date.
    func assistantWhen(_ task: TaskItem) -> String {
        guard let date = task.scheduledDate else { return Self.title(for: task.column(in: week)) }
        let day = date.startOfDay(in: calendar)
        let time = task.scheduledMinute.map {
            day.addingTimeInterval(TimeInterval($0 * 60)).formatted(.dateTime.hour().minute())
        }
        let dayText =
            switch date {
            case today: "Today"
            case today.adding(days: 1, calendar: calendar): "Tomorrow"
            case ...week.end: day.formatted(.dateTime.weekday(.abbreviated))
            default: day.formatted(.dateTime.month(.abbreviated).day())
            }
        return [dayText, time].compactMap { $0 }.joined(separator: " ")
    }
}
