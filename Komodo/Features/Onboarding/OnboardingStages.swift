import SwiftUI

/// `.ob-stage`: the 250 pt illustration above each intro step's title (Onboarding.png). They're drawings of Komodo,
/// not live views, so nothing here reads the store.
struct OnboardingStage: View {
    var step: OnboardingView.Step

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        ZStack {
            Palette.bg
            EllipticalGradient(
                colors: [Palette.lime.opacity(step == .win ? 0.1 : 0.06), .clear],
                center: step == .win ? .center : .top, startRadiusFraction: 0, endRadiusFraction: 0.7)
            switch step {
            case .plan: PlanIllustration()
            case .focus: FocusIllustration()
            case .win: WinIllustration()
            case .notifications, .today: NotificationIllustration()
            }
        }
        .frame(height: 250)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.06)))
        .accessibilityHidden(true)
    }
}

// MARK: 1 Plan

/// Three mini columns whose cards rise in one after another.
private struct PlanIllustration: View {
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MiniColumn(title: "Backlog", symbol: "moon", tint: Palette.violet, glyph: Palette.violetText, count: 4) {
                card(0, "Q4 roadmap", badge: ("W", Palette.lime), chips: [("3hr", nil), ("0/5", nil)])
                card(
                    3, "Weekly review", badge: ("P", Palette.teal),
                    chips: [("Every Fri", Palette.violet), ("45min", nil)])
                card(6, "Hire a designer", badge: ("W", Palette.lime), chips: [("1hr", nil)])
            }
            MiniColumn(title: "This week", symbol: "calendar", tint: Palette.blue, glyph: Palette.blueText, count: 3) {
                card(
                    1, "Wireframes: pill", badge: ("W", Palette.lime),
                    chips: [("Sun 10:00 AM", Palette.blue), ("2hr", nil)])
                card(4, "RTF export", badge: ("S", Palette.blue), chips: [("1hr 15min", nil)])
                card(7, "Submit visa form", badge: ("P", Palette.teal), chips: [("Due Oct 10", Palette.amber)])
            }
            MiniColumn(
                title: "Today", symbol: "sun.max.fill", tint: Palette.lime, glyph: Palette.onAccent, count: 3,
                isToday: true
            ) {
                MiniLiveCard().rise(index: 2, hasAppeared: hasAppeared, reduceMotion: reduceMotion)
                card(
                    5, "Wire date parsing", badge: ("W", Palette.lime),
                    chips: [("1hr 30min", nil), ("~3:05 PM", Palette.lime)])
                card(8, "Prep 1:1 with Apurva", badge: ("L", Palette.pink), chips: [("30min", nil)])
            }
        }
        .padding(14)
        .onAppear { hasAppeared = true }
    }

    private func card(_ index: Int, _ title: String, badge: (String, Color), chips: [(String, Color?)]) -> some View {
        MiniCard(title: title, badge: badge, chips: chips)
            .rise(index: index, hasAppeared: hasAppeared, reduceMotion: reduceMotion)
    }
}

private struct MiniColumn<Content: View>: View {
    var title: String
    var symbol: String
    var tint: Color
    var glyph: Color
    var count: Int
    var isToday = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(glyph)
                    .frame(width: 18, height: 18)
                    .background(
                        isToday
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Palette.teal, Palette.lime], startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                            : AnyShapeStyle(tint.opacity(0.16)),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.textBody)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isToday ? Palette.limeText : glyph)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 15, minHeight: 15)
                    .background((isToday ? Palette.lime : tint).opacity(0.16), in: Capsule())
            }
            .frame(height: 24)
            .padding(.horizontal, 3)
            content
        }
        .padding(.horizontal, 7)
        .padding(.top, Space.s2)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(isToday ? Palette.panel : Palette.bg.opacity(0.6), in: shape)
        .overlay(alignment: .top) {
            if !isToday {
                LinearGradient(colors: [.clear, tint, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 2)
            }
        }
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isToday
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Palette.teal.opacity(0.8), Palette.lime.opacity(0.45), .white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.07)))
        )
        .shadow(color: isToday ? Palette.lime.opacity(0.3) : .clear, radius: 20)
    }
}

private struct MiniCard: View {
    var title: String
    var badge: (String, Color)
    var chips: [(String, Color?)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(badge.0)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 14, height: 14)
                    .background(badge.1, in: RoundedRectangle(cornerRadius: 4))
                Text(title).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Palette.textBody).lineLimit(1)
            }
            HStack(spacing: 4) {
                ForEach(chips, id: \.0) { chip in
                    Text(chip.0)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(chip.1 ?? Palette.textTertiary)
                        .padding(.horizontal, 5)
                        .frame(height: 15)
                        .background(
                            (chip.1 ?? .white).opacity(chip.1 == nil ? 0.06 : 0.14),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, Space.s2)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.control)
    }
}

/// The live card in miniature: LIVE, the time and a lime progress bar inside a teal-to-lime edge.
private struct MiniLiveCard: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                HStack(spacing: 3) {
                    Circle().fill(Palette.lime).frame(width: 4, height: 4)
                    Text("LIVE").font(.system(size: 7.5, weight: .heavy)).tracking(0.6)
                }
                .foregroundStyle(Palette.limeText)
                .padding(.horizontal, 5)
                .frame(height: 13)
                .background(Palette.lime.opacity(0.14), in: Capsule())
                Spacer(minLength: 0)
                Text("32:13")
                    .font(.system(size: 12, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .shadow(color: Palette.lime.opacity(0.6), radius: 6)
            }
            Text("Design review prep")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
            GeometryReader { geo in
                Capsule().fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.liveGradient).frame(width: geo.size.width * 0.72)
                    }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, Space.s2)
        .padding(.vertical, 7)
        .background(Palette.panel, in: shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(colors: [Palette.teal, Palette.lime], startPoint: .leading, endPoint: .trailing),
                lineWidth: 1)
        )
        .shadow(color: Palette.lime.opacity(0.35), radius: 10)
    }
}

extension View {
    /// `.ob-in`: rises into place 140 ms after the one before.
    fileprivate func rise(index: Int, hasAppeared: Bool, reduceMotion: Bool) -> some View {
        opacity(hasAppeared || reduceMotion ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 10)
            .animation(
                reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9).delay(Double(index) * 0.14 + 0.2),
                value: hasAppeared)
    }
}

// MARK: 2 Focus

/// A mail window under the floating timer, with the live time in the menu bar.
private struct FocusIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Wallpaper()
            MenuBarStrip(app: "Mail", menus: ["File", "Edit", "View"], showsTimer: true)
            MiniWindow().frame(width: 250, height: 150).opacity(0.5).scaleEffect(0.96).offset(x: 70, y: 48)
            MiniWindow(showsMessage: true).frame(width: 330, height: 170).offset(x: 40, y: 62)
            VStack(spacing: Space.s3) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 2.5)
                        Circle().trim(from: 0, to: 0.72)
                            .stroke(Palette.lime, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 14, height: 14)
                    Text("Write launch email").font(.system(size: 12.5, weight: .semibold))
                    Text("32:13")
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .shadow(color: Palette.lime.opacity(0.5), radius: 9)
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(.leading, 11)
                .padding(.trailing, 14)
                .frame(height: Layout.floatingTimerHeight)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .shadowFloat(cornerRadius: Radius.tile)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 22)
            .padding(.top, 40)
            HStack(spacing: 6) {
                KeyCap("⌘⇧T")
                Text("panel ↔ pill")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 30)
            .padding(.bottom, 18)
        }
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Palette.violet.opacity(0.34), .clear], center: UnitPoint(x: 0.15, y: 1), startRadius: 0,
                endRadius: 260)
            RadialGradient(
                colors: [Palette.teal.opacity(0.26), .clear], center: UnitPoint(x: 0.95, y: 0.05), startRadius: 0,
                endRadius: 240)
            RadialGradient(
                colors: [Palette.pink.opacity(0.12), .clear], center: UnitPoint(x: 0.65, y: 0.7), startRadius: 0,
                endRadius: 160)
        }
    }
}

private struct MenuBarStrip: View {
    var app: String
    var menus: [String]
    var showsTimer = false

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Palette.textBody).frame(width: 6, height: 6)
            Text(app).fontWeight(.bold).foregroundStyle(Palette.textPrimary)
            ForEach(menus, id: \.self) { Text($0) }
            Spacer()
            if showsTimer {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").foregroundStyle(Palette.lime)
                    Text("32:13").fontWeight(.semibold).monospacedDigit().foregroundStyle(Palette.textPrimary)
                }
                .padding(.horizontal, 6)
                .frame(height: 15)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            }
            Text("Sat 26 Sep 2:14 PM")
        }
        .font(.system(size: 9.5))
        .foregroundStyle(Palette.textTertiary)
        .padding(.horizontal, 10)
        .frame(height: 20)
        .background(.ultraThinMaterial.opacity(0.9))
    }
}

private struct MiniWindow: View {
    var showsMessage = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach([Color.red, .yellow, .green], id: \.self) { color in
                    Circle().fill(color.opacity(0.85)).frame(width: 7, height: 7)
                }
                if showsMessage {
                    Text("New message")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.leading, Space.s2)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.025))
            if showsMessage {
                VStack(alignment: .leading, spacing: 7) {
                    field("To:", "team")
                    field("Subject:", "We launch Thursday")
                    Text("Hi all, quick update on launch day")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textTertiary)
                    ForEach([0.92, 0.78, 0.84], id: \.self) { width in
                        GeometryReader { geo in
                            Capsule().fill(Color.white.opacity(0.08)).frame(width: geo.size.width * width)
                        }
                        .frame(height: 6)
                    }
                }
                .padding(.horizontal, Space.s3)
                .padding(.vertical, 10)
            }
            Spacer(minLength: 0)
        }
        .background(Palette.panel, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.9), radius: 25, y: 12)
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(Palette.textMuted)
            Text(value).foregroundStyle(Palette.textBody)
        }
        .font(.system(size: 9.5))
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1) }
    }
}

// MARK: 3 Win

/// The celebration card in miniature: the check and confetti, the result, what's next and the day's progress.
private struct WinIllustration: View {
    @State private var hasPlayed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Space.s5, style: .continuous)
        ZStack {
            if !reduceMotion {
                CelebrationBurst(hasPlayed: hasPlayed, isHero: false)
            }
            VStack(spacing: 6) {
                CelebrationCheck(hasPlayed: hasPlayed, side: 56, isStill: reduceMotion)
                Text("Nailed it. 12min early.")
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(-0.34)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, 6)
                Text("Next up: Review the API PR").font(.system(size: 11.5)).foregroundStyle(Palette.textSecondary)
                HStack(spacing: Space.s2) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index < 3
                                        ? AnyShapeStyle(Palette.liveGradient) : AnyShapeStyle(Color.white.opacity(0.1))
                                )
                                .frame(width: 16, height: 5)
                        }
                    }
                    Text("3/5 DONE")
                        .font(.system(size: 10, weight: .heavy).monospacedDigit())
                        .tracking(0.8)
                        .foregroundStyle(Palette.limeText)
                }
                .padding(.top, 6)
            }
        }
        .frame(width: 297, height: 197)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.lime.opacity(0.2), .clear], center: UnitPoint(x: 0.5, y: 0.3),
                    startRadiusFraction: 0, endRadiusFraction: 0.7)
            }
        }
        .clipShape(shape)
        .padding(1.5)
        .background(
            LinearGradient(
                colors: [Palette.teal, Palette.lime, Palette.amber, Palette.pink, Palette.violet],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Space.s5 + 1.5, style: .continuous)
        )
        .shadow(color: Palette.lime.opacity(0.45), radius: 30)
        .onAppear { hasPlayed = true }
    }
}

// MARK: 4 Notifications

/// A reminder with Start now and Snooze, and the Alerts style picked in System Settings.
private struct NotificationIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Wallpaper().opacity(0.7)
            MenuBarStrip(app: "Komodo", menus: ["File", "View", "Focus"])
            notification
                .frame(width: 340)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, Space.s4)
                .padding(.top, 32)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("KOMODO ALERT STYLE · SYSTEM SETTINGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.textMuted)
                HStack(spacing: 10) {
                    style("Banners", isOn: false)
                    style("Alerts", isOn: true)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.leading, 18)
            .padding(.bottom, Space.s4)
        }
    }

    private var notification: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        return HStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                KomodoMarkShape()
                    .stroke(Palette.onAccent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 18, height: 18)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Design review").font(.system(size: 12.5, weight: .bold)).foregroundStyle(
                            Palette.textPrimary)
                        Spacer()
                        Text("now").font(.system(size: 10.5)).foregroundStyle(Palette.textSecondary)
                    }
                    Text("Starts now").font(.system(size: 12)).foregroundStyle(Palette.textBody)
                    Text("with Apurva · Google Meet").font(.system(size: 10.5)).foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, Space.s3)
            .padding(.vertical, 11)
            VStack(spacing: 0) {
                Text("Start now").foregroundStyle(Palette.limeText).frame(maxHeight: .infinity)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text("Snooze 5 min").foregroundStyle(Palette.textBody).frame(maxHeight: .infinity)
            }
            .font(.system(size: 11.5, weight: .semibold))
            .frame(width: 104)
            .overlay(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .spotlight(Palette.teal, radius: Radius.tile, lifts: false) {
            shape.fill(.ultraThinMaterial).overlay(shape.strokeBorder(Color.white.opacity(0.12)))
        }
        .shadow(color: .black.opacity(0.8), radius: 20, y: 10)
    }

    private func style(_ title: String, isOn: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: isOn ? 72 : 60, height: isOn ? 24 : 18)
                    .overlay(alignment: .trailing) {
                        if isOn {
                            VStack(spacing: 5) {
                                Capsule().fill(Palette.lime).frame(width: 12, height: 2)
                                Capsule().fill(Color.white.opacity(0.5)).frame(width: 12, height: 2)
                            }
                            .frame(width: 20)
                            .overlay(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1) }
                        }
                    }
                    .padding(Space.s2)
            }
            .frame(width: 104, height: 58, alignment: .topTrailing)
            .background(isOn ? Palette.lime.opacity(0.05) : Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(isOn ? Palette.lime : Color.white.opacity(0.1)))
            .overlay(alignment: .bottomLeading) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 14, height: 14)
                        .background(Palette.lime, in: Circle())
                        .padding(7)
                }
            }
            .shadow(color: isOn ? Palette.lime.opacity(0.5) : .clear, radius: 10)
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isOn ? Palette.limeText : Palette.textSecondary)
        }
    }
}

#Preview("Stages") {
    VStack(spacing: Space.s4) {
        ForEach([OnboardingView.Step.plan, .focus, .win, .notifications], id: \.self) { step in
            OnboardingStage(step: step).frame(width: 512)
        }
    }
    .padding(Space.s6)
    .background(Palette.panel)
}
