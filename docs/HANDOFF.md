# Handoff: where Komodo stands and where to continue

Last updated: 2026-09-28. Milestones through 5e (floating timer, celebrations, day summary, command palette) are on `main`. The maintainer
committed and pushed most of 5c as one commit (`4d5db3a`); leave it as it is and build new commits on top.
`CHANGELOG.md` has the full list of what landed.

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
  from the running app (steps in CONTRIBUTING.md). The README never mentions AI tools used to build Komodo;
  Komodo's own AI features are showcased once they ship.
- Before saying a task is done: xcodebuild with zero warnings, swift format lint --strict clean,
  swift test in KomodoCore passing.

Then continue from docs/HANDOFF.md §4 "Next task": Settings and the system surfaces (menu bar extra, global
shortcuts, notifications) to match design/previews/Settings.png and System.png and their design/screens/*.dc.html
(DESIGN_SYSTEM §14), with the behavior from FEATURES §4.12, §4.17 and §4.18. Keep using the in-memory BoardStore
and sample data. I use this Mac while you work: capture Komodo's own windows (screencapture -l) with the Debug
launch flags and -quietCapture instead of moving my pointer. Show me a screenshot of the running app next to each
PNG, and list every place where you followed one spec over another. Ask me HANDOFF §9's questions, and ask before adding any dependency (bundle cost plus one alternative).
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
| 5b | Inspector (`Inspector.png`) | ✅ | Notes are RTF in an `NSTextView` |
| 5c | Quick add panel (⌘⌥T), Schedule popover + Repeat | ✅ | Checked against `Schedule.png` and `BoardStates.png`; see §5 for what's left |
| 5d | Focus Panel + FocusStates | ✅ | Checked against `FocusPanel.png` and `FocusStates.png`; see §5 for what's left |
| 5e | Floating timer, Celebration, Day summary, Command palette | ✅ | Checked against `FloatingTimer.png`, `Celebration.png` and `CommandPalette.png`; see §5 |
| 5f | **Settings, System surfaces**, then Gmail → Calendar, Data & backup, Onboarding | ⏭ **Next** | See §4. ARCHITECTURE puts Settings and Gmail in Phase 0a |
| — | Persistence (SQLite with GRDB) | ⬜ | GRDB approved (§6: bundle cost and the alternative). Not started |

The remaining screen prompts from DESIGN_HANDOFF §6 step 5, in order: Inspector → Quick add → Schedule → Focus
Panel (plus FocusStates) → Floating timer → Celebration → Palette → Settings → Gmail → the rest.

---

## 3. How the code is organised

```
Komodo/
  App/                KomodoApp (scenes, commands, LaunchOptions), AppDelegate, DebugCommands (Debug menu, gallery)
  DesignSystem/       Palette, Typography, Metrics (Space/Radius/Layout), Motion, Elevation,
                      WeightedHStack, FlowLayout
    Effects/          Spotlight, BeamBorder, FocusDial, OdometerText, TimerTone, Ping, Shake, Sheen, Rise, Aurora,
                      LayerEffect (hosts the Core Animation loops)
    Components/       Buttons, chips, badges, fields, TaskCard/QueueCard, LiveTaskCard, BreakCard, DayMeter,
                      ControlBar, Toast, Banner, PopoverSurface, CardSurface, KomodoMark
    Gallery/          Debug-only replica of Foundations.png plus a Components section
  Features/Board/     HomeView, SidebarView, BoardView (toolbar + header), BoardColumnView, TodayStageView,
                      BoardStore (+Cards adapter), BoardSamples
  Features/Inspector/ InspectorView, InspectorDetails (+ InspectorRow/InspectorValue), Subtasks, Notes, Activity
  Features/Schedule/  SchedulePopover (steps, month grid), ScheduleDetailsStep, RepeatPicker (+ CustomRepeatSheet)
  Features/QuickAdd/  QuickAddPanel (⌘⌥T, overlaid on the Board)
  Features/Focus/     FocusPanelView (header, day tile, lists), FocusHeroCard (236 pt dial), FocusStateCards
                      (break, timed tasks only, won day), FocusPanelRows, QuickSettingsView, FloatingTimerView
  Features/Palette/   CommandPalette (⌘F search and > commands, overlaid on the Board)
  Windows/            FocusPanel (FocusSurfaceController: sets Home aside, docks the panel, shows the timer),
                      FloatingTimerPanel (pill window plus the celebration window above it)
  Resources/          AppIcon.icon (Icon Composer), Assets.xcassets (color sets, menu bar icons)
scripts/render-icons.swift  Renders the AppIcon.icon layers and the menu bar template images
KomodoCore/           Pure logic, no UI, tested with Swift Testing
  Models/             LocalDate, TaskItem (+Bucket, Subtask, WorkSession, TaskSource), TaskList
  Board/              WeekRange, BoardLayout, DayPlan, DaySummary, FocusHistory, TaskSearch, CelebrationCopy
  Timer/              FocusClock, TimerFormat
  Formatting/         DurationFormat
  Parsing/            EstimateParser
  Recurrence/         RepeatRule (kinds, occurrences, wording), Recurrence (this week's copies)
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
- **Continuous effects** loop as Core Animation layer animations through `LayerEffect`. Never drive a looping
  effect from `TimelineView`, because it re-runs the Board's layout every frame.
- **Repeats:** a repeating task is a parent that stays in its column. `Recurrence.expanding` makes this week's
  copies with IDs like `weekly@2026-10-02`, so running it again never duplicates. Deleted copies are
  remembered and stay gone.
- **Undo:** `offerUndo` registers with the window's `UndoManager` and shows the toast, so ⌘Z and the toast's
  button do the same restore.
- **Focus Panel:** `store.isFocusPanelOpen` drives it. `FocusPanelController` observes the store, docks an
  `NSPanel` to `panelSide` and sets the Home window aside while it's up. Both surfaces read one store, so
  there's one timer. Live-task tone and control mode come from `TimerTone(elapsed:…)` and
  `ControlBar.Mode(tone:)`, shared with the Board's live card.
- **Narrow widths:** `ViewThatFits` fallbacks keep the Today column readable at the 1200 pt default window.
  The wide layout is the one that matches the canvas.

---

## 4. Next task: Settings and System surfaces

- **Spec:** DESIGN_SYSTEM §14 (menu bar, notifications) and the Settings section; FEATURES §4.12 (reminders),
  §4.17 (shortcuts) and §4.18 (settings). Pixels: `design/previews/Settings.png` and `System.png`; values:
  their `design/screens/*.dc.html`.
- **Hooks already in place:**
  - The store holds the Focus settings in memory (`isPomodoroOn`, `sprintLength`, `breakLength`, `panelSide`,
    `playsSounds`); Settings should edit the same values and persist them (`@AppStorage` or the database).
  - `FocusCommands` has ⌘⇧T and ⌘⇧P as app shortcuts. Make them and ⌘⇧B global; there's no dependency for it
    in the project yet, so ask before adding one.
  - Menu bar icons exist as image sets; `FloatingTimerView`'s `PillState` shows what each timer state says.
  - Disabled placeholders waiting for Settings: the sidebar's Settings row, Quick Settings' All settings, the
    palette's Settings command.
- **Capturing:** Settings is its own window; add a flag like `-openSettings <section>`.

---

## 5. Known gaps and placeholders

- **No persistence:** everything is in memory (`BoardSamples`). Nothing survives a relaunch.
- **Disabled until their milestones:**
  - Reports, Trash and Settings (sidebar)
  - Create list (sidebar **+**)

  Each has a `.help` note.
- **Reminders** are stored (`remindsAtStart`) and shown as "Reminder on", but nothing fires until the
  notifications milestone.
- **Archive** in the card menu stays disabled until Trash lands.
- **Repeat copies** are made at launch and after schedule changes only. Midnight rollover and wake from sleep
  need a trigger (FEATURES §4.7).
- **Card ⋯ menu:** its items, groups and shortcuts were checked against `BoardStates.dc.html` in code. It's a
  native menu, so it hasn't been captured, and ⌘D / ⌘⌫ on a focused card haven't been tried in the running app.
- **README recording** has not been re-recorded for 5b to 5e. The screenshots are fresh, but recording needs the
  pointer and the screen. Ask the maintainer for a window when it's time.
- **Celebration:** no fun GIF or success sound (they need bundled assets and Settings toggles), and no "3 in a
  row today" chip (needs streak rules). The success screen can't be switched off until Settings.
- **Floating timer:**
  - ⌘⇧T and ⌘⇧P only work while Komodo is active; they become global with System surfaces.
  - The title doesn't scroll (Scrolling title is a Settings toggle); the timed alert is P1.
  - Its window is a fixed 600 × 88 transparent frame. Clicks pass through the transparent part; that was
    reasoned from AppKit's alpha hit-testing, not tried by clicking.
  - Dragging, hover controls and the position memory weren't exercised with the pointer.
- **Command palette:** the dim covers the Board, not the sidebar. Backup, Gmail and Settings show dimmed.
  Keyboard navigation and ⌘F weren't tried with real keystrokes; each state was opened with `-openPalette`.
- **Day summary:** unfinished tasks with Tomorrow / This week are the P1 end-of-day review (FEATURES §6.4).
- **Alerts** (`FocusAlerts`): sprint end and break over sound and notify, but neither has been triggered on the
  maintainer's Mac, since the first one asks for notification permission with a system dialog. The macOS
  "Glass" sound stands in for Komodo's own sounds. Scheduled reminders and Time's Up notifications (§14.2) come
  with the notifications milestone; they can reuse `FocusAlerts`.
- **Sounds:** the Quick Settings switch is stored; nothing plays yet.
- **Focus Panel:**
  - The Scheduled today **+** is disabled with a `.help` note.
  - Rows have Make live, Done, Duplicate and Delete. Schedule, Subtasks, Notes and Move to list open the Home
    window, so they're left out of the panel's menu, and rows can't be dragged to reorder yet.
  - Start → panel → Home was only exercised through the launch flags, not by clicking in the running app.
  - If the Home window was closed before Start, Home has no window to bring back.
  - It docks to `NSScreen.main`.
  - The won card's twinkling sparks are left out, and See reports is disabled until Reports.
- **Timed tasks** don't join the queue when their time passes (FEATURES §4.6); the calm card waits for them.
- **Gmail status row** in the sidebar is hidden, because Gmail isn't connected (DESIGN_SYSTEM §12).
- **Components not built yet** (DESIGN_SYSTEM §9): table, integration card, suggestion card, page dots, code
  block, folder picker. Build each with the
  screen that uses it.
- **Menu bar icons** exist as image sets, but nothing shows them until the menu bar extra lands (System
  surfaces milestone, DESIGN_SYSTEM §14.1).
- **README recording** (`board.gif`) still shows the old sidebar mark (clock hand, no check).
- **Increase Contrast:** the color sets have dark and universal values only, no Increase Contrast variants.
- **Test file:** the original scaffold test file (`KomodoCoreTests.swift`) was replaced before it was ever
  committed. Its contents are unknown, and the current suites cover FocusClock, TimerFormat, DurationFormat,
  EstimateParser, BoardLayout, DayPlan, DaySummary and FocusHistory.

---

## 6. Decisions made (and where one spec was followed over another)

| Topic | Decision | Why |
| --- | --- | --- |
| Button heights | 28 / 34 / 40 pt | The canvas wins on pixels; DESIGN_SYSTEM text says 24/28/36 |
| Switches, segmented pickers | Native | DESIGN_SYSTEM "native first"; the canvas draws custom ones |
| Sprint state | A Sprint display choice: Task (default) or Sprint | The maintainer's pick. Task follows `Main.png` / `FocusPanel.png` (lime, estimate, sprint chip); Sprint follows DESIGN_SYSTEM §10.2 and FocusStates ④ (pink, sprint countdown). It lives in Quick Settings until Settings lands |
| Persistence | GRDB approved by the maintainer | Adds roughly 2–4 MB to the app (to be measured when it lands). Alternative: the system SQLite C API through `import SQLite3`, which costs nothing but needs hand-written statements, migrations and observation |
| Pomodoros default | On | The maintainer's call, matching `Main.png` and `FocusPanel.png`; FEATURES §4.18 now says On |
| Sprint-end notification | "Sprint 2 of 4 done" · "Take 5min. Design review is paused." | DESIGN_SYSTEM §14.2 has no sprint-end row; FEATURES §4.10 asks for one |
| Alert sound | macOS "Glass" | No bundled sounds yet (`success.caf` is named on the canvas) |
| Sprint timing | Work across tasks counts toward one sprint; only a full sprint moves the count; a hand break resumes it | FEATURES §4.10–4.11 leave it open; this matches a classic Pomodoro |
| Single-list badges | Every card in "Work" shows W | `Main.png` mixes S/P/L badges into the Work list; the spec filters to one list |
| Dated tasks in This week | At the bottom | FEATURES §4.2 |
| Workday end | 6:00 PM by default, in Quick Settings until Settings lands | The maintainer asked for it; no spec gives a default |
| Running past the workday | "runs 40min past your workday" | Main.png only shows the "to spare" case |
| Ends around | Computed: now + queue + scheduled remaining | `Main.png` shows a static 6:40 PM |
| Home window | `HStack` with a fixed 248 pt sidebar, hidden title bar | macOS 26 draws the `NavigationSplitView` sidebar as a floating inset panel. ⌃⌘S is recreated by `SidebarCommand` |
| Start shortcut | Return (`.defaultAction`) | ⌘⇧B is "Open Komodo" (§14.1); FEATURES §4.8 says "⌘⇧B then Return" |
| Violet, green, red badge glyphs | Nearest defined dark glyph | DESIGN_SYSTEM §2.4 only defines five |
| Key cap label in the gallery | "SF Mono" | What ships; the canvas used Geist Mono as a stand-in |
| README scope | No mention of AI tools used to build Komodo; Komodo's own AI features are showcased once they ship | The maintainer's rule, narrowed on 2026-09-28; the README only showcases shipped work |
| App icon | Black body, spectrum ring (violet → lime), white check; no mascot | The user asked for black primary with the accents as secondary. `System.png` shows a teal → lime ring and hand on `#171717` |
| Schedule calendar | Custom Monday-first month grid | `Schedule.png` wins on pixels; the native graphical `DatePicker` was small and followed the locale's first weekday |
| Schedule time field | `TimeField`: clock icon, digits and stepper in a 116 pt Komodo field, plus ✕ to remove the time | Matches `Schedule.png`. It wraps an unbezeled `NSDatePicker` to keep typing and arrow keys. The ✕ stays because a time must be removable (FEATURES §4.6) |
| Column titles | Always whole on one line; the subtitle truncates | With the inspector open at 1440 pt, "Backlog", "This week" and "Today" wrapped |
| Custom repeat controls | Native stepper, unit menu and date field | "Native first"; the canvas draws a − N + stepper and an "Oct 31" field with a calendar icon |
| Repeat menu button | The canvas's field (glyph, rule, up-down chevron) over a native menu with an inline picker | Keeps the native checkmark on the current rule |
| Focus Panel width | 340 pt (`Layout.focusPanelWidth`) | DESIGN_SYSTEM §13.8 and FocusStates say 340; the FocusPanel artboard is 380 wide. The header icons sit edge to edge to fit |
| Focus Panel level | `.floating`, non-activating, can become key | Docked beside other apps it should stay visible; key status lets ADD TASK and Notes take typing |
| Panel list picker | The Board's list filter | One filter for both surfaces, so the queue matches what Home shows |
| Panel Notes | A popover with the inspector's notes | The inspector lives in the hidden Home window |
| Timed tasks left | The calm card, not the won day | FocusStates ⑥; `completeLive()` wins only when nothing timed is left |
| Won card Done | Ends Focus mode and brings Home back | The canvas says "Close the summary"; nothing is left to focus on |
| On est. | Share finished early or within ±10% | FEATURES §4.14's on-time tolerance; the canvas's 82% is illustrative |
| Won tiles | `5h 40m` (`DurationFormat.compact`) | The canvas's copy; `5hr 40min` overflows the tile |
| Panel Done row | The shared `DoneSectionButton` (44 pt, expands) | Same component as the Board; the canvas draws 40 pt with a right chevron |
| Break buttons | 40 pt large buttons | The house button heights; the canvas draws 42 pt |
| Panel sprint chip | Shown in Task display; the links chip gives way at 340 pt | FocusPanel.png at 380 pt fits all three |
| Floating timer window | Fixed transparent frame, pill at the leading edge; a separate window for the celebration | Hover controls grow right without resizing; the card goes above the pill, or below near the top of the screen |
| Floating timer drag | A drag gesture on the pill | "Movable by background" would turn its buttons into drag handles |
| Floating timer glass | `.ultraThinMaterial` under white 10% at 84% | DESIGN_SYSTEM §10.5; the canvas uses 62% with a heavier blur |
| Celebration timing | The next task starts when it ends | FEATURES §4.13 "never mid-task"; the canvas says "starting in 2s" |
| Celebration on-time band | ±10% of the estimate | Celebration.png's copy card; the FocusPanel canvas script used ±1 min |
| Day won in timer mode | Opens back into the panel | The summary and the calm card need the panel's room |
| Palette empty query | Search row and footer only | No spec for it |
| Palette surface | `popoverSurface` (radius 14) | The shared glass; the canvas draws radius 16 |
| Toolbar search | A button that opens the palette | DESIGN_SYSTEM §13.7; the Board no longer filters in place |
| Move to list items | Letter-square symbols (`w.square.fill`) | Native menus draw symbols in one color, so the canvas's colored list badges can't be matched exactly |
| Quick add empty footer | "A trailing time like “45m” sets the estimate." | No spec copy for the empty state; the canvas only shows the filled one |
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
  - Surfaces: add `-openSchedule <task id>`, `-openInspector <task id>` or `-openQuickAdd YES`. Sample ids:
    `roadmap` (unscheduled, opens step 1), `weekly` (repeating, opens step 2), `mcp` (subtasks). Add
    `-openCustomRepeat YES` to `-openSchedule` for the Custom repeat sheet.
  - Focus Panel: `--args -sampleTime artboard -ApplePersistenceIgnoreState YES -openFocusPanel YES -quietCapture
    YES`, plus `-focusState paused|timesUp|break|celebrating|scheduled|won` for the other states. Use
    `-openFloatingTimer YES` for the pill (window "Floating Timer", celebration "Floating Celebration") and
    `-openPalette "<query>"` for the palette. A celebration ends after 2.5 s, so capture about 1.2 s after its
    window appears. `-quietCapture` keeps the
    panel at normal level behind other apps, so it doesn't cover the screen; `screencapture -l` still gets it.
    The window is named "Focus Panel" in `CGWindowListCopyWindowInfo` (use `.optionAll`, it isn't on top).
  - **The maintainer uses the Mac while you work.** Launch with `open -g` so Komodo stays in the background,
    capture with `screencapture -x -o -l <window id>`, and type with `CGEvent.postToPid`, which reaches Komodo
    without bringing it forward. Never click or record the screen without asking first.
  - Switches draw grey while Komodo isn't the active app. For a shot with a switch on, ask first, then launch
    without `-g`, capture, and reactivate the app that was in front. Activating an already running Komodo closes
    its popovers. Captures fail while the screen is locked or Komodo is on another Space.

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
- **Times:** formatters put a narrow no-break space (U+202F) before "PM". Split on `\.isWhitespace`, never on
  `" "`.
- **WeightedHStack** fills a concrete proposed height. Outside a scroll view give it
  `.fixedSize(horizontal: false, vertical: true)`, or it stretches its row.
- **Parallel sessions:** two sessions editing the same folder overwrote each other once. Run only one working
  session per checkout.

---

## 9. Open questions for the user

None right now.
