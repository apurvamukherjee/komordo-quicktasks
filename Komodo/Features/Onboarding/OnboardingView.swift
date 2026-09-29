import KomodoCore
import SwiftUI

/// First launch (DESIGN_SYSTEM §13.1, Onboarding.png): a 560 × 520 sheet over Home with three intro screens,
/// notifications and today's tasks. Gmail → Calendar's optional step joins when Google sign-in lands, so the
/// sheet counts five steps for now.
struct OnboardingView: View {
    @Bindable var store: BoardStore

    enum Step: Int, CaseIterable {
        case plan
        case focus
        case win
        case notifications
        case today
    }

    @State private var step: Step
    @State private var text = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: BoardStore, step: Step = .plan) {
        self.store = store
        _step = State(initialValue: step)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Group {
                if step == .today {
                    OnboardingTodayStep(text: $text) { store.finishOnboarding(adding: lines) }
                } else {
                    intro
                }
            }
            .id(step)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 12)))
            Spacer(minLength: 0)
            footer
        }
        .padding(.top, Space.s5)
        .padding(.horizontal, Space.s6)
        .padding(.bottom, 22)
        .frame(width: 560, height: 520)
        .spotlight(Palette.lime, radius: Radius.hero, lifts: false) {
            shape.fill(
                LinearGradient(colors: [Palette.raised, Palette.panel], startPoint: .top, endPoint: .bottom)
            )
            .overlay {
                EllipticalGradient(
                    colors: [Palette.lime.opacity(0.09), .clear], center: UnitPoint(x: 0.5, y: -0.12),
                    startRadiusFraction: 0, endRadiusFraction: 0.62)
            }
            .clipShape(shape)
        }
        .animation(reduceMotion ? nil : Motion.base, value: step)
        .preferredColorScheme(.dark)
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            if step == .plan {
                HStack(spacing: Space.s2) {
                    KomodoMarkShape()
                        .stroke(Palette.onAccent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 12, height: 12)
                        .frame(width: 20, height: 20)
                        .background(
                            LinearGradient(
                                colors: [Palette.teal, Palette.lime], startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text("Welcome to Komodo")
                }
            } else {
                Text("\(step.rawValue + 1) of \(Step.allCases.count)").monospacedDigit()
            }
            Spacer()
            Button("Skip") { store.finishOnboarding(adding: []) }
                .buttonStyle(.komodo(.ghost, size: .small))
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(Palette.textMuted)
        .frame(height: 28)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingStage(step: step)
                .padding(.top, Space.s3)
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
            detail
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 6)
        }
    }

    private var title: String {
        switch step {
        case .plan: "Plan your day in minutes."
        case .focus: "One task at a time, always on screen."
        case .win: "Finish, celebrate, repeat."
        case .notifications, .today: "Allow notifications for reminders and breaks."
        }
    }

    private var detail: Text {
        switch step {
        case .plan: Text("Park ideas in Backlog, line up This week, and pull the best into Today.")
        case .focus: Text("The floating timer stays above every app, even full screen.")
        case .win: Text("Every finish gets a moment. Then the next task goes live.")
        case .notifications, .today:
            Text("Choose ") + Text("Alerts").bold().foregroundColor(Palette.limeText) + Text(" so the buttons show.")
        }
    }

    private var footer: some View {
        HStack(spacing: Space.s2) {
            OnboardingDots(current: step.rawValue, count: Step.allCases.count)
            Spacer()
            Button("Back") { move(-1) }
                .buttonStyle(.komodo(.ghost))
                .disabled(step == .plan)
            switch step {
            case .notifications:
                Button("Not now") { move(1) }
                    .buttonStyle(.komodo(.secondary))
                Button("Allow", systemImage: "bell") {
                    Task { await store.alerts?.requestPermission() }
                    move(1)
                }
                .buttonStyle(.komodo(.primary))
                .keyboardShortcut(.defaultAction)
            case .today:
                Button(lines.isEmpty ? "Skip" : "Continue") { store.finishOnboarding(adding: lines) }
                    .buttonStyle(.komodo(.primary))
                    // Return adds a line in the field, so ⌘Return continues (DESIGN_SYSTEM §13.1).
                    .keyboardShortcut(.return, modifiers: .command)
            default:
                Button("Continue") { move(1) }
                    .buttonStyle(.komodo(.primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(height: 34)
    }

    private var lines: [String] { OnboardingTodayStep.lines(in: text) }

    private func move(_ offset: Int) {
        if let next = Step(rawValue: step.rawValue + offset) { step = next }
    }
}

/// `.ob-dots`: done steps lime at 75%, the current one a 22 pt glowing lime bar.
private struct OnboardingDots: View {
    var current: Int
    var count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(
                        index > current ? Color.white.opacity(0.18) : Palette.lime.opacity(index < current ? 0.75 : 1)
                    )
                    .frame(width: index == current ? 22 : 7, height: 7)
                    .shadow(color: index == current ? Palette.lime.opacity(0.75) : .clear, radius: 5)
            }
        }
        .animation(Motion.spring, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

#Preview("Onboarding") {
    OnboardingView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .padding(Space.s8)
        .background(Palette.bg)
}

#Preview("Onboarding · Today") {
    OnboardingView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment), step: .today)
        .padding(Space.s8)
        .background(Palette.bg)
}
