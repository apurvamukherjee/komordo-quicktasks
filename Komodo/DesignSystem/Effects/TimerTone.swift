import SwiftUI

/// The color state of the live task. BeamBorder, FocusDial and the halo all read from it so
/// they switch together (DESIGN_SYSTEM §10.2).
enum TimerTone: CaseIterable, Sendable {
    case live
    case sprint
    case paused
    case timesUp
    case onBreak

    /// The live task's tone from its clock: over the estimate wins, then paused, then sprint or plain live.
    init(elapsed: TimeInterval, estimate: TimeInterval, isRunning: Bool, inSprint: Bool) {
        if elapsed > estimate {
            self = .timesUp
        } else if !isRunning {
            self = .paused
        } else {
            self = inSprint ? .sprint : .live
        }
    }

    var isMoving: Bool { self != .paused }

    /// Dark base, then the two lit stops of the conic beam.
    var beam: (base: Color, lead: Color, tail: Color) {
        switch self {
        case .live: (Palette.beamLiveBase, Palette.teal, Palette.lime)
        case .sprint: (Palette.beamSprintBase, Palette.pink, Palette.lime)
        case .paused: (Palette.beamPausedBase, Palette.textDisabled, Palette.textMuted)
        case .timesUp: (Palette.beamTimesUpBase, Palette.danger, Palette.ember)
        case .onBreak: (Palette.beamBreakBase, Palette.green, Palette.mint)
        }
    }

    /// Outer glow color; paused has none.
    var glow: Color? {
        switch self {
        case .live: Palette.lime
        case .sprint: Palette.pink
        case .paused: nil
        case .timesUp: Palette.danger
        case .onBreak: Palette.green
        }
    }

    /// Lit ticks and the comet's glow.
    var accent: Color {
        switch self {
        case .live: Palette.lime
        case .sprint: Palette.pink
        case .paused: Palette.textMuted
        case .timesUp: Palette.dangerLine
        case .onBreak: Palette.green
        }
    }

    var ring: (Color, Color) {
        switch self {
        case .live: (Palette.teal, Palette.lime)
        case .sprint: (Palette.pink, Palette.lime)
        case .paused: (Palette.textDisabled, Palette.textMuted)
        case .timesUp: (Palette.danger, Palette.ember)
        case .onBreak: (Palette.green, Palette.mint)
        }
    }

    var halo: (Color, Color) {
        switch self {
        case .live, .paused: (Palette.teal, Palette.lime)
        case .sprint: (Palette.pink, Palette.teal)
        case .timesUp: (Palette.danger, Palette.ember)
        case .onBreak: (Palette.green, Palette.mint)
        }
    }
}
