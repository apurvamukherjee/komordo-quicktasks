# Handoff: where Komodo stands and where to continue

Last updated: 2026-09-27. The app icon and menu bar icon commits on `main` are local and not pushed yet. `CHANGELOG.md` has the full list of
what landed.

---

## 1. Prompt for the next session

Paste this as the first message of a new session:

```text
Read CLAUDE.md, docs/HANDOFF.md, CHANGELOG.md and CONTRIBUTING.md first, then docs/DESIGN_HANDOFF.md.
Follow every rule in them. The most important ones:
- Commit as my git identity only, with Conventional Commits (type(scope): summary), about 20–25 small
  commits per task, each one building on its own. No co-author or tool trailers. Never push, I push.
- Before rewriting any commit, run git fetch and make sure it isn't already on origin/main.
- When a feature lands, update README.md in the same task with fresh screenshots and a recording captured
  from the running app (steps in CONTRIBUTING.md). The README never mentions AI.
- Before saying a task is done: xcodebuild with zero warnings, swift format lint --strict clean,
  swift test in KomodoCore passing.

Then continue from docs/HANDOFF.md §4 "Next task": build the Task inspector to match
design/previews/Inspector.png and design/screens/Inspector.dc.html (DESIGN_SYSTEM §13.5), with the behavior
from FEATURES §4.3–4.5. Open it by clicking a card on the Board, and wire the live card's Notes tile to it.
Keep using the in-memory BoardStore and sample data. Show me a screenshot of the running app next to
Inspector.png, and list every place where you followed one spec over another.
```

---

## 2. Status by milestone

The build order follows DESIGN_HANDOFF §3 and §6 step 3.

| # | Milestone | Status | Notes |
| --- | --- | --- | --- |
| 1 | Plan | ✅ | Structure follows ARCHITECTURE §12 |
| 2 | Scaffold: XcodeGen project, KomodoCore, color sets, tokens | ✅ | macOS 14+, arm64, Swift 6 strict concurrency, warnings as errors |
| 3 | Effects + Design System Gallery | ✅ | Gallery recreates `Foundations.png`; Debug only |
| 4 | Components (DESIGN_SYSTEM §9–10, DESIGN_HANDOFF §3 list) | ✅ | See §5 for components not built yet |
| 5a | Board, single list (`Main.png`) | ✅ | In-memory sample data; checked side by side with `Main.png` |
| 5b | **Inspector** | ⏭ **Next** | See §4 |
| 5c | Quick add panel (⌘⌥T), Schedule popover + Repeat | ⬜ | The inline and Today quick add already exist |
| 5d | Focus Panel + FocusStates | ⬜ | The Board already runs Focus mode in its Today stage |
| 5e | Floating timer, Celebration, Day summary, Command palette | ⬜ | |
| 5f | Settings, Gmail → Calendar, Data & backup, Onboarding, System surfaces | ⬜ | ARCHITECTURE puts Settings and Gmail in Phase 0a |
| — | Persistence (SQLite with GRDB) | ⬜ | Not started. A new dependency needs the user's OK first (bundle cost plus one alternative) |

The remaining screen prompts from DESIGN_HANDOFF §6 step 5, in order: Inspector → Quick add → Schedule → Focus
Panel (plus FocusStates) → Floating timer → Celebration → Palette → Settings → Gmail → the rest.

---

## 3. How the code is organised

```
Komodo/
  App/                KomodoApp (scenes, commands, LaunchOptions), AppDelegate, DebugCommands (Debug menu, gallery)
  DesignSystem/       Palette, Typography, Metrics (Space/Radius/Layout), Motion, Elevation,
                      WeightedHStack, FlowLayout
    Effects/          Spotlight, BeamBorder, FocusDial, OdometerText, TimerTone, Ping, Shake, Sheen, Rise, Aurora
    Components/       Buttons, chips, badges, fields, TaskCard/QueueCard, LiveTaskCard, BreakCard, DayMeter,
                      ControlBar, Toast, Banner, PopoverSurface, CardSurface, KomodoMark
    Gallery/          Debug-only replica of Foundations.png plus a Components section
  Features/Board/     HomeView, SidebarView, BoardView (toolbar + header), BoardColumnView, TodayStageView,
                      BoardStore (+Cards adapter), BoardSamples
  Resources/          AppIcon.icon (Icon Composer), Assets.xcassets (color sets, menu bar icons)
scripts/render-icons.swift  Renders the AppIcon.icon layers and the menu bar template images
KomodoCore/           Pure logic, no UI, tested with Swift Testing
  Models/             LocalDate, TaskItem (+Bucket, Subtask, WorkSession, TaskSource), TaskList
  Board/              WeekRange, BoardLayout, DayPlan, FocusHistory
  Timer/              FocusClock, TimerFormat
  Formatting/         DurationFormat
  Parsing/            EstimateParser
docs/                 Specs, this handoff, and media/ (README screenshots and recordings)
design/               previews/*.png (pixel truth) and screens/*.dc.html (exact values)
```

**Key patterns**
- **Spotlight surfaces:** `.spotlight(tint) { CardSurface() }`. The modifier draws the surface itself so the
  glow sits between the surface and the content. Never put an opaque background behind `.spotlight` instead,
  because the glow would be hidden.
- **Derived state:** columns, start times, day totals, focus history and streaks all come from KomodoCore.
  `BoardStore` only stores lists, tasks, the selected list and the Focus state.
- **Live clock:** it comes from the live task's sessions (an open session means running). `FocusClock` is
  rebuilt from them on every read, so nothing counts ticks.
- **Sample clock:** `BoardStore` takes a `clock`. With `-sampleTime artboard` the store's day is anchored
  to Sat Sep 26, 2:14 PM and keeps moving. `clockOffset` converts back to wall-clock time for any
  `TimelineView`. When the database lands, the clock becomes `Date.init` and the offset becomes zero.
- **Cards:** `TaskCardModel` is a plain display model. `BoardStore+Cards.swift` turns a `TaskItem` into it,
  including chip wording and dates.
- **Narrow widths:** `ViewThatFits` fallbacks keep the Today column readable at the 1200 pt default window.
  The wide layout is the one that matches the canvas.

---

## 4. Next task: Task inspector

- **Spec:** DESIGN_SYSTEM §13.5 (normal, live and locked, from Gmail, with subtasks and notes);
  FEATURES §4.3 (editing, and title and EST locked while live), §4.4 (subtasks), §4.5 (notes). Pixels:
  `design/previews/Inspector.png`; values: `design/screens/Inspector.dc.html`.
- **Hooks already in place:**
  - Clicking a card currently only focuses it (`boardCardBehavior` in `BoardColumnView.swift`). The inspector
    should open from there.
  - The live card's **Notes** tile is a no-op (`openNotes: {}` in `TodayStageView.controlActions`). Wire it to
    the inspector.
  - The Board has no inspector yet. DESIGN_SYSTEM §4.1 puts it on the trailing edge: 380 pt ideal, 320–460.
    Because the Home window is a custom `HStack` rather than `NavigationSplitView` (see §6), check whether
    `.inspector` works there or build a trailing panel.
  - `TaskItem` already has `notes`, `subtasks`, `estimate`, `scheduledDate`/`scheduledMinute`, `dueDate`,
    `repeatSummary`, `linkCount` and `source`. Add store actions for edits: title, EST (DurationField exists),
    subtasks, notes and time taken.
- **Notes editor:** FEATURES and DESIGN_SYSTEM §10.6 call for a wrapped `NSTextView` with RTF and a toolbar.
  Start with plain text if RTF is too much for one milestone, and say so.

---

## 5. Known gaps and placeholders

- **No persistence:** everything is in memory (`BoardSamples`). Nothing survives a relaunch.
- **Disabled until their milestones:**
  - Reports, Trash and Settings (sidebar)
  - Create list (sidebar **+**)
  - the floating-timer toolbar button

  Each has a `.help` note.
- **Search** filters the Board in place. DESIGN_SYSTEM §13.7 says it should open the command palette; switch
  it over when the palette lands.
- **Card actions:** the hover row has Move and Done only. The canvas also shows Schedule and ⋯; those come
  with the Schedule popover. The right-click menu already has Move, Done and Make live.
- **Celebration:** Done completes the task and starts the next one, but there is no confetti or celebration
  card yet (Celebration milestone).
- **Gmail status row** in the sidebar is hidden, because Gmail isn't connected (DESIGN_SYSTEM §12).
- **Components not built yet** (DESIGN_SYSTEM §9): table, integration card, suggestion card, command palette
  row, page dots, code block, folder picker, stat tile, celebration and day-summary cards. Build each with the
  screen that uses it.
- **Menu bar icons** exist as image sets, but nothing shows them until the menu bar extra lands (System
  surfaces milestone, DESIGN_SYSTEM §14.1).
- **README recording** still shows the old sidebar mark (clock hand, no check). Re-record it with the next
  README media refresh.
- **Increase Contrast:** the color sets have dark and universal values only, no Increase Contrast variants.
- **Test file:** the original scaffold test file (`KomodoCoreTests.swift`) was replaced before it was ever
  committed. Its contents are unknown, and the current suites cover FocusClock, TimerFormat, DurationFormat,
  EstimateParser, BoardLayout, DayPlan and FocusHistory.

---

## 6. Decisions made (and where one spec was followed over another)

| Topic | Decision | Why |
| --- | --- | --- |
| Button heights | 28 / 34 / 40 pt | The canvas wins on pixels; DESIGN_SYSTEM text says 24/28/36 |
| Switches, segmented pickers | Native | DESIGN_SYSTEM "native first"; the canvas draws custom ones |
| Sprint state | Pink "SPRINT 2 OF 4" pill and beam | DESIGN_SYSTEM §10.2. `Main.png` shows sprint dots under a lime LIVE pill; the Board passes no sprint, so it stays lime. **Ask the user** |
| Single-list badges | Every card in "Work" shows W | `Main.png` mixes S/P/L badges into the Work list; the spec filters to one list |
| Dated tasks in This week | At the bottom | FEATURES §4.2 |
| "fits your day with … to spare" | Omitted | Needs a workday-end setting that no spec defines. **Ask the user** |
| Ends around | Computed: now + queue + scheduled remaining | `Main.png` shows a static 6:40 PM |
| Home window | `HStack` with a fixed 248 pt sidebar, hidden title bar | macOS 26 draws the `NavigationSplitView` sidebar as a floating inset panel. ⌃⌘S is recreated by `SidebarCommand` |
| Start shortcut | Return (`.defaultAction`) | ⌘⇧B is "Open Komodo" (§14.1); FEATURES §4.8 says "⌘⇧B then Return" |
| Violet, green, red badge glyphs | Nearest defined dark glyph | DESIGN_SYSTEM §2.4 only defines five |
| Key cap label in the gallery | "SF Mono" | What ships; the canvas used Geist Mono as a stand-in |
| README scope | No AI mentions, including the product's AI features | The user's rule; the README only showcases shipped work |
| App icon | Black body, spectrum ring (violet → lime), white check; no mascot | The user asked for black primary with the accents as secondary. `System.png` shows a teal → lime ring and hand on `#171717` |
| Menu bar and in-app mark | The check replaces the clock hand in the idle and attention states and in `KomodoMarkShape` | Matches the app icon. `System.png` draws a hand. Running keeps the spec's filled wedge |

---

## 7. Workflow and gates

```bash
xcodegen generate
xcodebuild -scheme Komodo -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData build
swift format lint --strict --recursive Komodo KomodoCore/Sources KomodoCore/Tests KomodoCore/Package.swift
(cd KomodoCore && swift test)
```

- New Swift files under `Komodo/` are only picked up after `xcodegen generate`.
- `swift format format --in-place --recursive Komodo KomodoCore/Sources KomodoCore/Tests` fixes most lint
  errors.
- **Commits:** Conventional Commits with scopes used so far: `core`, `app`, `design-system`, `effects`,
  `components`, `gallery`, `board`, `readme`, `media`. Commit in dependency order so each commit builds, and
  build an intermediate commit in a throwaway `git worktree` to prove it.
- **README media:** follow CONTRIBUTING.md.
  - Board: `open build/DerivedData/Build/Products/Debug/Komodo.app --args -sampleTime artboard -homeWindowSize
    1440x820 -ApplePersistenceIgnoreState YES`
  - Gallery: `--args -design-gallery -galleryScrollTo <section>`, where section is one of principles,
    neutrals, accents, temperature, type, spotlight, motion, controls, cards, components.

---

## 8. Gotchas learned the hard way

- **SourceKit noise:** "Cannot find 'Palette' in scope" and "No such module 'KomodoCore'" in the editor are
  index noise. `xcodebuild` is the source of truth.
- **Generic types:** Swift 6 has no static stored properties in generic types. Move constants to file scope.
- **Sendable:**
  - `Regex` isn't `Sendable`, so a static `Regex` fails strict concurrency. Use locals inside the function.
  - A `keyframeAnimator` closure in a generic modifier captures the generic metatype. Constrain the parameter
    to `Sendable`.
- **Swift Testing:** big `@Test(arguments:)` tuple literals with arithmetic time out the type checker. Use
  literal values and `as [(T, U)]`.
- **Shell:** BSD `sed` has no `\b`; use `perl -pi -e`.
- **Git:** never `git stash` with uncommitted work to fix up history. Reword commits with `git commit-tree`
  plus `git update-ref`, which leaves the working tree alone, and only when they aren't pushed yet.
- **Screen capture:**
  - The screen is 1710×1073 points.
  - `screencapture -l <window id>` fails with "could not create image from window" while the window is still
    animating in. Wait a couple of seconds and retry.
  - Window ids come from `CGWindowListCopyWindowInfo`. The name "Design System" has a space, so parse the
    fields with care.
  - Move the pointer off the window before recording; posting a `mouseMoved` CGEvent works.
  - SwiftUI saves the Home window frame under `NSWindow Frame home` in the `app.komodo.Komodo` defaults.
    Delete it to get a fresh `defaultSize`.
- **Icons:**
  - Don't add an `AppIcon.appiconset` next to `AppIcon.icon`. Xcode builds from the `.icon` for every macOS
    version and ignores the set.
  - Icon Composer masks the whole 1024 canvas, so the `.icon` layers are scaled up from the 824 pt grid.
  - Check the `.icon` without Xcode: `ictool Komodo/Resources/AppIcon.icon --export-image --output-file out.png
    --platform macOS --rendition Default --width 512 --height 512 --scale 1`. Renditions: `Default`, `Dark`,
    `TintedDark`, `ClearDark`. `ictool` is in `Icon Composer.app/Contents/Executables/`.
  - `ImageRenderer` output differs by 1/255 between runs. Commit re-rendered PNGs only when the drawing changed.
- **Parallel sessions:** two sessions editing the same folder overwrote each other once. Run only one working
  session per checkout.

---

## 9. Open questions for the user

1. **Sprint tone on the Board:** pink sprint pill and beam (DESIGN_SYSTEM §10.2), or lime LIVE with sprint dots
   (`Main.png`)?
2. **Workday end:** should Komodo have a workday-end setting, so the header can say "fits your day with …
   to spare"?
3. **Persistence:** OK to add GRDB (ARCHITECTURE §2)? Its bundle cost and one alternative need recording before
   adding it.
4. **README and AI features:** the product's own AI features (Claude mode, Assistant, Local MCP) are left out
   of the README. Keep it that way?
