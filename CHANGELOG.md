# Changelog

All notable changes to Komodo. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project will use [Semantic Versioning](https://semver.org/) from its first release.

## [Unreleased]

Nothing is released yet. Everything below is on `main`, grouped by milestone in the order it landed
(DESIGN_HANDOFF §3 build order).

### Task inspector — 2026-09-27

#### Added
- **Inspector** on the Home window's trailing edge (native `.inspector`, 380 pt ideal, 320–460). Click any card
  to open it; the live card's Notes tile and ⌘⌥N open the live task. Esc closes it, and ⌘↑ / ⌘↓ step through
  tasks in Board order.
- **Header:** done checkbox, the title (click to rename, Return saves, Esc cancels), a More menu with Duplicate,
  Move to List and Delete (with Undo), and close.
- **Details:** list picker, EST in the duration field, time taken (click to edit while the task isn't running),
  the schedule with a clear button, and the repeat rule.
- **Subtasks** with a progress dial: check, rename on click, delete on hover, and Return keeps adding.
- **Notes:** a rich-text editor (`NSTextView`, stored as RTF) with Bold, Italic, Underline, Strikethrough, Link,
  bulleted and numbered lists, Clear, and undo. A per-task switch opens the notes' links when the task starts.
- **Source** row for tasks from Gmail or a calendar, **Sessions** with count, total and the latest four as
  bars, and a footer with when the task was made and last edited, or when it went live.
- **Live task:** the beam, a compact focus dial and the rolling countdown above the title. Title and EST lock
  with "Pause to edit" while it runs, and time taken counts live.
- **Auto-open links:** when a task goes live, up to five `http`/`https` links from its notes open in the
  browser, unless its switch is off.
- KomodoCore: `NoteLinks`, `TaskItem.links` / `linksToOpen`, `setTimeTaken(_:at:)` (adjusts sessions),
  `notesRTF`, `opensLinks`, `createdAt`, `editedAt`, `sourceTitle`, `sourceURL`, with tests.

#### Changed
- A task's link count now comes from the links in its notes instead of a stored number.
- Sample tasks have named subtasks, notes with links, creation dates and Gmail sources.

### App icon and menu bar icon — 2026-09-27

#### Added
- **App icon** as an Icon Composer file (`AppIcon.icon`): a black body with a stopwatch ring in the Board's
  column spectrum (violet → blue → teal → lime) and a check inside it. macOS 26 derives the light, dark, clear
  and tinted looks from it, and Xcode flattens it for macOS 14–15.
- **Menu bar icons** for idle, running and attention, as template images for light and dark menu bars.
- `scripts/render-icons.swift` renders the icon layers and the menu bar images from SwiftUI drawings.

#### Changed
- The Komodo mark in the sidebar has a check in place of the clock hand, to match the icons.

### Board, single list — 2026-09-27

#### Added
- **Home window** shows the Board under a hidden title bar: a flush 248 pt sidebar beside the Board, with the
  traffic lights over the sidebar as on the canvas. ⌃⌘S hides and shows the sidebar.
- **Sidebar:** brand with the "On this Mac" chip; Home, All lists and Reports; lists with open counts and the
  selected list's lime bar; the Focused today card (ring, seven days of bars, streak); Trash and Settings.
- **Toolbar and header:** list picker, search (filters titles, notes and subtasks), Pomodoro chip, Start
  (Return, disabled with a reason when nothing is eligible), the list title with its open count and today's
  plan, and a Board / All lists switch.
- **Backlog and This week columns** with tinted material, count and summary, **+** to insert at the top,
  **+ ADD TASK** with an inline field, and hover actions on cards. This week has the seven-day strip with
  today ringed lime.
- **Today stage** with the aurora, gradient border and glow: the day meter, then the live task, break card or
  "You won the day." summary, then Up next with projected start times, quick add with 15m/30m/1h presets
  and ⌘↵ to add and start, Scheduled today, and a collapsible Done section. An empty Today shows the spec's
  copy.
- **Interactions:** drag and drop within and across columns (drop on a card to insert before it); keyboard
  focus on cards with Space (done), ⌥↑/⌥↓ (reorder) and N (add); the card context menu; a 5 s Undo toast
  after completing or moving a task; moving a dated task clears its date.
- **Focus mode on the Board:** Start, Pause/Resume, Skip, Done, Break (with +2 min and Skip break), +5/+15
  min at Time's Up, and the bolt to make any queued task live.
- `BoardStore`: in-memory state and actions for all of the above.
- `BoardSamples`: sample data shaped like the Main artboard, placed around a given moment.
- **KomodoCore:** `LocalDate`, `WeekRange`, `TaskItem`, `TaskList`, `Subtask`, `WorkSession`,
  `BoardLayout` (column rules), `DayPlan` (start times, end of day, estimate left, focused time),
  `FocusHistory` (daily focus and streak), and `EstimateParser` (`Write spec 45m` → "Write spec", 45 min).
  All tested.
- `Aurora` effect for the Today stage.
- `KomodoTextField` gains a 34 pt toolbar density and focus-on-appear for inline editors.
- Debug launch arguments `-sampleTime artboard` (anchors the sample day to Sat Sep 26, 2:14 PM) and
  `-homeWindowSize WxH`.

#### Fixed
- `WeightedHStack` now honors a concrete proposed height, so columns fill the window instead of growing
  with their content.
- The live card, day meter and queue chips fold instead of overflowing in the narrow Today column of the
  1200 pt default window.

#### Removed
- The Home placeholder view.

### Component library — 2026-09-26 to 09-27

#### Added
- **Controls:** `KomodoButtonStyle` (primary, secondary, ghost, danger, danger outline; 28/34/40 pt; busy
  state), `IconButtonStyle`, `CardActionButtonStyle` (with the lime "go" bolt), `Chip` with every tint,
  `PresetChipButtonStyle`, `ListBadge` and `ListColor`, `CountBadge`, `SourceBadge`, `StatusDot`, `KeyCap`,
  and `.komodoSwitch()`.
- **Fields:** `KomodoTextField` (standard, search and monospaced, with error text), `SecureKeyField` (Show and
  Test), and `DurationField` (HH:MM).
- **Cards:** `TaskCard` with `TaskCardModel` and `ColumnTone` (default, hover actions, focused, dragging,
  done, overdue), `QueueCard`, `ProgressBar`, and `SubtaskRing`.
- **Focus:** `ControlBar`, `LiveTaskCard` (switches itself to Time's Up), `BreakCard`, and `DayMeter`.
- **Feedback and structure:** `SectionHeader`, `AddTaskButton`, `DoneSectionButton`, `Toast` with
  `ToastCenter` and `.toastOverlay`, `Banner`, `.popoverSurface()`, and `FlowLayout`.
- **KomodoCore:** `DurationFormat` ("2hr 30min", HH:MM formatting and parsing), tested.
- **Palette:** three banner message colors.
- **Gallery:** a Components section, and the gallery now renders only real components.

### Signature effects and design gallery — 2026-09-26

#### Added
- **Effects:** `Spotlight` (cursor light on every surface), `BeamBorder`, `FocusDial`, `OdometerText`,
  `TimerTone`, `Ping`, `Shake`, `Sheen`, `Rise`, and `Aurora`. Every effect honors Reduce Motion.
- **Surfaces and layout:** `CardSurface`, `TileSurface`, `Elevation` (lift, float and drag shadows, plus the
  live, break and danger glows), `WeightedHStack`, and `KomodoMark`.
- **Tokens:** palette colors for the effects and badges, the `tile` and `stage` radii, and
  `Motion.Period`.
- **KomodoCore:** `FocusClock` and `TimerFormat`, tested.
- **Design System Gallery** (Debug only): the Foundations artboard rebuilt in SwiftUI. Open it from
  Debug → Design System Gallery (⌥⇧⌘G) or with `-design-gallery [-galleryScrollTo <section>]`.

#### Changed
- Timer and title tracking now match the canvas: −1.75 pt and −0.38 pt.

### Project foundation — 2026-09-26

#### Added
- Specs (FEATURES, ARCHITECTURE, DESIGN_SYSTEM, DESIGN_HANDOFF) and the design canvas exports.
- XcodeGen project for macOS 14+ on arm64, with Swift 6 strict concurrency and warnings treated as errors.
- The `KomodoCore` package.
- swift-format config and `.gitignore`.
- Obsidian Spectrum color sets and design tokens (`Palette`, `Typography`, `Space`, `Radius`, `Layout`,
  `Motion`).

### Documentation

- The README is a product showcase with real screenshots and recordings: the Board, components, motion and
  the design system.
- `CONTRIBUTING.md` covers the quality gates, Conventional Commits, and how to keep the README current.
- `docs/HANDOFF.md` records where the work stands and where to pick it up.
