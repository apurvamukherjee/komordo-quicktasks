# Komodo: Design handoff for Claude Code

> Read this first, then DESIGN_SYSTEM.md (what things look like), FEATURES.md (how they behave) and ARCHITECTURE.md (how they're built).
> Visual source of truth: the canvas **"Komodo — Design System & Screens"** (18 artboards). Every artboard is exported as a PNG in `design/previews/` and as HTML/CSS source in `design/screens/`.

---

## 1. What's in this package

```
komodo-design/
├─ CLAUDE.md                     drop into the repo root (project instructions for Claude Code)
├─ docs/
│  ├─ DESIGN_HANDOFF.md          this file
│  ├─ DESIGN_SYSTEM.md           updated to Obsidian Spectrum tokens (Part A + §10 + §16 rewritten)
│  ├─ FEATURES.md                unchanged
│  └─ ARCHITECTURE.md            unchanged
└─ design/
   ├─ previews/*.png             one image per artboard (settled state, no motion)
   └─ screens/*.dc.html          the artboard source: exact colors, sizes, radii, copy, motion
```

The `.dc.html` files are HTML + CSS mockups, not code to ship. Treat them as a precise spec: read the inline styles for exact values, and the `<style>` block (the shared kit is the same in every file) for hover, motion and effect definitions. Build everything in SwiftUI.

## 2. Artboard → spec map

| Artboard (preview) | What it shows | Spec |
| --- | --- | --- |
| `Main` | Board, single list: sidebar, 3 columns with time temperature, Today stage, live card with focus dial, queue, quick add, scheduled, done. Interactive (Pause, Skip, Done → celebration, Break, bolt) | DS §12, §13.2, §10.1–10.4 · FEATURES §4.2–4.3, §4.8 |
| `FocusPanel` | The docked Focus Panel with the hero focus dial. Interactive, with a `state` tweak | DS §13.8, §10.2 · FEATURES §4.8–4.11 |
| `FocusStates` | All 7 panel states + Quick Settings popover | DS §13.8, §15 row 8–9 |
| `FloatingTimer` | Floating pill, hover expansion, every state, celebration above the pill, menu bar item | DS §10.5, §13.9, §14.1 |
| `Celebration` | Panel celebration, GIF variant, Reduce Motion, copy variants, day summary with and without unfinished tasks | DS §13.10–13.11 · FEATURES §4.13, §6.4 |
| `BoardStates` | All lists + filter menu, drag in progress, empty Today drop target, ⌘⌥T quick add, focused card, card menu, inline add, undo toast | DS §13.2–13.4 |
| `Inspector` | Inspector: normal, live (locked), from Gmail | DS §13.5 |
| `Schedule` | Schedule step 1 and 2, repeat menu, custom repeat, editing a repeat | DS §13.6 · FEATURES §4.6–4.7 |
| `CommandPalette` | Palette results, empty, command mode | DS §13.7, §10.12 |
| `Trash` | Trash table + empty | DS §13.14 |
| `Reports` | Overview, Punctuality, Time spent, Sessions + session sheet + export menu; `dataState` tweak for empty / loading | DS §13.12–13.13 |
| `Settings` | Settings window with every page | DS §13.15–13.17, §13.21, §13.23–13.25 |
| `DataSheets` | Data & backup in 3 states, restore confirm / success / errors, typed delete, token sheet | DS §13.21–13.22, §13.17 |
| `Gmail` | Gmail → Calendar: connect flow + errors, status lines, overview, settings modes, activity, review | DS §13.18–13.20 · FEATURES §4.0 · ARCH §6 |
| `Onboarding` | 6 onboarding steps + the first-run Start tip | DS §13.1 · FEATURES §6.1 |
| `Assistant` | Komodo Assistant: empty, listening, thinking, proposal, applied | DS §13.26 · FEATURES §4.19 |
| `System` | Menu bar menu, menu bar icons, app icon, notifications, banners, toasts, Dock menu, app menus | DS §6.1, §14 |
| `Foundations` | Tokens with Swift names, type, radius, glow, motion demos, cursor spotlight showcase, component states | DS Part A, §9–10, §16 |

## 3. Build order (matches ARCHITECTURE §16)

1. **DesignSystem module**: `Palette`, `Typography`, `Space`, `Radius`, `Layout`, `Motion` (DS §16), the asset catalog color sets, then the effects in §4 below. Add a `DesignSystemGallery` window (debug builds only) that recreates the `Foundations` artboard, so every effect can be checked in isolation.
2. **Components** (DS §9): Button styles, chips, badge, status dot, toggle tint, fields, task card, section header, day meter, control bar, toast, banner, popover styling.
3. **Phase 0a** screens: menu bar app, Settings (Gmail → Calendar, Data & backup, About), onboarding step 6.
4. **Phase 0b** screens: Board → Inspector → Quick add → Schedule → Focus Panel → Floating timer → Celebration → Day summary → Palette.
5. **Phase 1**: Reports, Trash, AI, Local MCP, Review tab.
6. **Phase 2**: Assistant.

After each screen, compare it side by side with its PNG in `design/previews/` and fix any differences before moving on.

## 4. Signature effects in SwiftUI

These four effects make Komodo feel like Komodo. Build them once in `Komodo/DesignSystem/Effects/`, then reuse them everywhere. The code is a starting point: keep the values and adjust the API to fit.

### 4.1 Cursor spotlight (required on every card, tile, sheet group, menu, notification)

```swift
struct Spotlight: ViewModifier {
    var tint: Color
    var radius: CGFloat = Radius.card
    @State private var point: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(alignment: .topLeading) {
                GeometryReader { geo in
                    if let point {
                        RadialGradient(colors: [tint.opacity(0.14), .clear],
                                       center: unit(point, geo.size), startRadius: 0, endRadius: 300)
                            .clipShape(shape)
                            .transition(.opacity)
                    }
                }
            }
            .overlay {
                GeometryReader { geo in
                    if let point {
                        shape.strokeBorder(
                            RadialGradient(stops: [.init(color: tint.opacity(0.95), location: 0),
                                                   .init(color: tint.opacity(0.22), location: 0.45),
                                                   .init(color: .clear, location: 1)],
                                           center: unit(point, geo.size), startRadius: 0, endRadius: 220),
                            lineWidth: 1)
                        .transition(.opacity)
                    }
                }
                .allowsHitTesting(false)
            }
            .offset(y: point != nil && !reduceMotion ? -3 : 0)
            .shadow(color: point != nil ? tint.opacity(0.35) : .clear, radius: 24, y: 9)
            .animation(Motion.spring, value: point != nil)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p):
                    if point == nil { withAnimation(Motion.spotlightFade) { point = p } } else { point = p }
                case .ended:
                    withAnimation(Motion.spotlightFade) { point = nil }
                }
            }
    }

    private func unit(_ p: CGPoint, _ size: CGSize) -> UnitPoint {
        UnitPoint(x: size.width > 0 ? p.x / size.width : 0.5, y: size.height > 0 ? p.y / size.height : 0.5)
    }
}

extension View {
    func spotlight(_ tint: Color, radius: CGFloat = Radius.card) -> some View {
        modifier(Spotlight(tint: tint, radius: radius))
    }
}
```

Only the fade in and out animates. While hovering, the gradient follows the pointer instantly, as in the canvas. Tints are listed in `SpotlightTint` (DS §16).

### 4.2 Border beam (live task, active heroes)

```swift
struct BeamBorder: View {
    enum Tone { case live, paused, timesUp, onBreak }
    var tone: Tone
    var radius: CGFloat = Radius.hero

    var body: some View {
        TimelineView(.animation(paused: tone == .paused)) { ctx in
            let angle = Angle.degrees(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.5) / 4.5 * 360)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(AngularGradient(stops: stops, center: .center, angle: angle), lineWidth: 1.5)
        }
        .phaseAnimator([0.0, 1.0]) { view, phase in
            view.shadow(color: glow.opacity(0.3 + 0.35 * phase), radius: 18 + 14 * phase)
        } animation: { _ in .easeInOut(duration: 1.6) }
    }
    // stops: dark → c1 (60°) → c2 (120°) → dark (190°…360°), colors per tone:
    // live teal/lime · paused grey, still · timesUp danger/#FF8A3D · onBreak green/#9DFFCB
}
```

### 4.3 Focus dial

```swift
struct FocusDial: View {
    var elapsed: TimeInterval, estimate: TimeInterval, tone: BeamBorder.Tone, size: CGFloat = 120

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let second = Int(elapsed) % 60
            let progress = min(1, elapsed / max(estimate, 1))
            ZStack {
                Halo(tone: tone).frame(width: size + 28, height: size + 28)        // blurred rotating AngularGradient, 7 s
                ForEach(0..<60, id: \.self) { i in
                    let d = (second - i + 60) % 60
                    Capsule()
                        .fill(tickColor(distance: d, major: i % 5 == 0))           // d == 0 white + glow, d < 14 fading tint
                        .frame(width: 2, height: i % 5 == 0 ? 9 : 6)
                        .offset(y: -size / 2 + 4)
                        .rotationEffect(.degrees(Double(i) * 6))
                }
                Circle().stroke(Palette.border, lineWidth: 7).padding(size * 0.15)
                Circle().trim(from: 0, to: progress)
                    .stroke(AngularGradient(colors: [Palette.teal, Palette.lime], center: .center),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(size * 0.15)
                    .animation(Motion.slow, value: progress)
                Comet(progress: progress, radius: size * 0.35)                      // 13 pt white dot + tinted glow
            }
            .frame(width: size, height: size)
        }
    }
}
```

The dial measures time itself (elapsed = accumulated + now − startedAt, ARCH §4.3). Nothing in the view counts ticks.

### 4.4 Odometer digits

On macOS 14, `Text(timeString).font(Typography.timerHero).contentTransition(.numericText(countsDown: true))` inside `withAnimation(Motion.spring)` is close enough. For the exact canvas look, render each digit as a clipped `VStack` of 0–9 offset by `-digit × lineHeight`. Add `.shadow(color: Palette.lime.opacity(0.4), radius: 17)` while running, and animate the colon's opacity 0.9 → 0.3 at 1 Hz.

## 5. Things the canvas decides that the old doc didn't

- True black canvas, the Obsidian Spectrum palette and new type scale (DS §2–3). The old `#111111` / `#B5D982` / `#55D9C6` values are gone.
- Columns are weighted 1 : 1.06 : 1.52, and Today sits on its own raised, bordered, glowing stage (DS §2.5). This separates This week from Today at a glance.
- Cards are bigger: padding 16, radius 18, 15 pt titles, a chip row, and a progress footer (DS §10.1).
- The live card shows a full focus dial with a Flow chip (DS §10.2). The Focus Panel uses the same dial at 204–236 pt.
- Break adds a breathing guide ("Breathe in / Breathe out"). Suggested; treat it as P0-optional.
- The Today queue shows projected start times ("starts ~2:23 PM"), and the day meter shows "Ends around". Both are derived values (ARCH §4.2), computed from the queue.
- The app mark is a timer ring (the Komodo ring with a crown). No bolt logo. Bolt is only the "make live" action.

## 6. Importing into Claude Code

### Step 1: Put the package in your repo

```bash
cd ~/Projects                       # or wherever you keep code
mkdir komodo && cd komodo && git init
unzip ~/Downloads/komodo-design-handoff.zip
mv komodo-design/* . && rmdir komodo-design
git add . && git commit -m "Add Komodo specs and design handoff"
```

This leaves `CLAUDE.md` in the repo root, with `docs/` and `design/` next to it.

### Step 2: Open Claude Code in that folder

```bash
cd ~/Projects/komodo
claude
```

Claude Code reads `CLAUDE.md` automatically. It can open the PNGs in `design/previews/` as images, so it can compare its SwiftUI previews against them.

### Step 3: Plan first, then build

Paste these prompts one at a time, and review each result before sending the next.

1. **Plan**
   > Read CLAUDE.md, docs/DESIGN_HANDOFF.md, docs/ARCHITECTURE.md, docs/FEATURES.md and docs/DESIGN_SYSTEM.md. Then propose the Xcode project and Swift package layout from ARCHITECTURE §12, and a milestone plan that follows DESIGN_HANDOFF §3. Don't write code yet.
2. **Scaffold**
   > Create the Xcode project (Komodo app target, KomodoCore local package, arm64, macOS 14, Swift 6 strict concurrency), the asset catalog color sets from DESIGN_SYSTEM §2, and DesignSystem/ with Palette, Typography, Space, Radius, Layout and Motion from §16. Make sure it builds with zero warnings.
3. **Effects and gallery**
   > Implement the Spotlight, BeamBorder, FocusDial and Odometer effects from DESIGN_HANDOFF §4, and a debug-only DesignSystemGallery window that recreates design/previews/Foundations.png. Put #Previews next to each view.
4. **Components**
   > Build the components in DESIGN_SYSTEM §9–10, matching design/screens/Foundations.dc.html for exact values. Every card and tile uses .spotlight(...).
5. **Screens**, one per prompt, in build order:
   > Build the Board (single list) to match design/previews/Main.png and design/screens/Main.dc.html, with the behavior from FEATURES §4.2–4.3. Use in-memory sample data for now, and show me a screenshot of the #Preview next to Main.png.

   Continue with the Inspector, Quick add, Schedule, Focus Panel (plus FocusStates), Floating timer, Celebration, Palette, then Settings, Gmail and the rest.

### Step 4: Keep the design in sync

When a screen changes on the canvas, export that artboard's PNG and source again, replace the files in `design/`, and tell Claude Code: "Main.png and Main.dc.html changed. Diff them against the current BoardView and update it."
