import SwiftUI

/// A button that slides in at the top right of a hovered card, or an item in its ⋯ menu.
struct CardAction: Identifiable {
    var label: String
    var symbol: String
    /// The bolt: lights up lime because it makes the task live.
    var isGo = false
    var isDestructive = false
    var isEnabled = true
    /// Shown in the menu; the card handles the key itself, because a menu's shortcuts only work while it's open.
    var shortcut: KeyboardShortcut?
    /// Groups separated by dividers. With any, the action opens a menu instead of performing (the ⋯ button,
    /// Move to list).
    var menu: [[CardAction]] = []
    var perform: () -> Void = {}

    var id: String { label }
}

/// The task card (DESIGN_SYSTEM §10.1): badge and title, a chip row, and a progress footer, lit by the
/// column's spotlight. Hovering lifts it and slides in the column's actions.
struct TaskCard: View {
    enum SubtaskDisplay {
        case chip
        /// The 30 pt dial in the corner, used in This week where subtasks are being worked through.
        case ring
    }

    var model: TaskCardModel
    var column: ColumnTone
    var subtaskDisplay: SubtaskDisplay = .chip
    var actions: [CardAction] = []
    var isFocused = false
    var isDragging = false

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            chipRow
            if model.showsProgress && !model.isDone {
                footer
            }
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if isHovered && !actions.isEmpty && !isDragging {
                CardActionRow(actions: actions)
                    .padding(Space.s3)
                    .transition(.opacity.combined(with: .offset(x: 8)))
            }
        }
        .spotlight(model.isOverdue ? SpotlightTint.danger : column.spotlight, lifts: !isDragging) { surface }
        .overlay { if isFocused { FocusRing(radius: Radius.card) } }
        .modifier(DragLift(isActive: isDragging))
        .onHover { hovering in withAnimation(Motion.base) { isHovered = hovering } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            if model.isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 22, height: 22)
                    .background(Palette.green, in: Circle())
                    .accessibilityLabel("Done")
            } else {
                ListBadge(letter: model.listLetter, color: model.listColor)
            }
            Text(model.title)
                .font(Typography.cardTitle)
                .lineSpacing(3)
                .strikethrough(model.isDone)
                .foregroundStyle(model.isDone ? Palette.textMuted : column.titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtasks = model.subtasks, subtaskDisplay == .ring, !model.isDone {
                SubtaskRing(done: subtasks.done, total: subtasks.total, tint: column.accent)
                    .padding(.top, -4)
                    .padding(.trailing, -4)
            } else if let source = model.source {
                SourceBadge(source: source)
            }
        }
    }

    @ViewBuilder private var chipRow: some View {
        if model.isDone {
            if let chip = model.outcomeChip { Chip(chip.text, tint: chip.tint) }
        } else {
            let chips = model.chips(includingSubtasks: subtaskDisplay == .chip)
            if !chips.isEmpty {
                FlowLayout {
                    ForEach(chips) { Chip($0.text, tint: $0.tint, icon: $0.icon) }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            ProgressBar(value: model.progress, fill: column.progressFill)
            Text(model.timeTakenLabel)
                .font(Typography.small.monospacedDigit())
                .foregroundStyle(model.timeTaken > 0 ? Palette.textTertiary : Palette.textMuted)
        }
        .padding(.top, 10)
        .overlay(alignment: .top) { DashedHairline() }
    }

    @ViewBuilder private var surface: some View {
        if model.isOverdue {
            ZStack {
                CardSurface()
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.dangerLine.opacity(0.28), lineWidth: 1)
            }
        } else if model.isDone {
            CardSurface(fill: Palette.panel)
        } else if isDragging {
            CardSurface(fill: Palette.raised)
        } else {
            CardSurface()
        }
    }
}

/// The actions over a hovered card, fading in over the title so they never collide with it.
struct CardActionRow: View {
    var actions: [CardAction]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(actions) { action in
                if action.menu.isEmpty {
                    Button(action.label, systemImage: action.symbol, action: action.perform)
                        .buttonStyle(CardActionButtonStyle(isGo: action.isGo))
                        .help(action.label)
                } else {
                    Menu {
                        CardMenuItems(sections: action.menu)
                    } label: {
                        Label(action.label, systemImage: action.symbol)
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .buttonStyle(CardActionButtonStyle(isGo: false))
                    .fixedSize()
                    .help(action.label)
                }
            }
        }
        .padding(.leading, 24)
        .background(
            LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: Palette.cardTop, location: 0.35)],
                startPoint: .leading, endPoint: .trailing)
        )
    }
}

/// The card menu's rows (BoardStates artboard, ⑨): groups split by dividers, submenus for nested actions. Used by
/// the ⋯ button and the right-click menu, so both list the same things.
struct CardMenuItems: View {
    var sections: [[CardAction]]

    var body: some View {
        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
            if index > 0 { Divider() }
            ForEach(section) { action in
                if action.menu.isEmpty {
                    Button(
                        action.label, systemImage: action.symbol, role: action.isDestructive ? .destructive : nil,
                        action: action.perform
                    )
                    .keyboardShortcut(action.shortcut)
                    .disabled(!action.isEnabled)
                } else {
                    Menu(action.label, systemImage: action.symbol) { CardMenuItems(sections: action.menu) }
                }
            }
        }
    }
}

/// Keyboard focus: a 2 pt teal ring separated from the card by a 2 pt black gap (DESIGN_SYSTEM §10.1).
struct FocusRing: View {
    var radius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                .strokeBorder(Color.black, lineWidth: 2)
                .padding(-2)
            RoundedRectangle(cornerRadius: radius + 4, style: .continuous)
                .strokeBorder(Palette.teal, lineWidth: 2)
                .padding(-4)
        }
        .allowsHitTesting(false)
    }
}

private struct DragLift: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.shadowDrag()
        } else {
            content
        }
    }
}

struct DashedHairline: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0.5))
            path.addLine(to: CGPoint(x: size.width, y: 0.5))
            context.stroke(path, with: .color(.white.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

#Preview("Task cards") {
    let backlogActions = [
        CardAction(label: "Schedule", symbol: "calendar.badge.clock") {},
        CardAction(label: "Move to This week", symbol: "arrow.right") {},
        CardAction(label: "More", symbol: "ellipsis") {},
    ]
    let weekActions = [
        CardAction(label: "Mark done", symbol: "checkmark") {},
        CardAction(label: "Move to Today", symbol: "arrow.right") {},
        CardAction(label: "More", symbol: "ellipsis") {},
    ]
    HStack(alignment: .top, spacing: Space.columnGutter) {
        VStack(spacing: Space.s3) {
            TaskCard(model: TaskCardSamples.roadmap, column: .backlog, actions: backlogActions)
            TaskCard(model: TaskCardSamples.weeklyReview, column: .backlog, actions: backlogActions)
        }
        VStack(spacing: Space.s3) {
            TaskCard(model: TaskCardSamples.wireframes, column: .week, subtaskDisplay: .ring, actions: weekActions)
            TaskCard(model: TaskCardSamples.visa, column: .week, actions: weekActions)
        }
        VStack(spacing: 18) {
            TaskCard(model: TaskCardSamples.reviewAccounts, column: .today, isFocused: true)
            TaskCard(model: TaskCardSamples.reviewAccounts, column: .today, isDragging: true)
            TaskCard(model: TaskCardSamples.doneEarly, column: .today)
            TaskCard(model: TaskCardSamples.overdue, column: .today)
        }
    }
    .frame(width: 980)
    .padding(Space.s8)
    .background(Palette.bg)
}
