# Handoff: where Komodo stands and where to continue

Last updated: 2026-10-03 (end of session). On `main`: every P0 milestone except Gmail → Calendar (parked by the
maintainer), all of Phase 1 except what depends on Gmail (Claude mode, the Review tab, reschedules) and the
XCUITest smoke tests (they need the maintainer's screen), and all of Phase 2's task tools: Todoist, Notion,
Linear, ClickUp and Asana, every one built and tested against documented responses only, with no real token yet.
Version 0.9.0 is the first downloadable build; the task tools are under Unreleased in `CHANGELOG.md`. Next is
the maintainer testing 0.9.0 and sharing test tokens, so each provider can be tried for real; then Gmail →
Calendar when the maintainer unparks it. §4 lists everything that remains, phase by phase. The maintainer
committed and pushed most of 5c as one commit (`4d5db3a`); leave it as it is and build new commits on top.
---

## 1. Prompt for the next session

Paste this as the first message of a new session:

```text
Read CLAUDE.md, docs/HANDOFF.md, CHANGELOG.md and CONTRIBUTING.md first, then docs/DESIGN_HANDOFF.md.
Follow every rule in them. The most important ones:
- Commit as my git identity only, with Conventional Commits (type(scope): summary), about 30–40 small
  commits per task, each one building on its own. No co-author or tool trailers. Never push, I push.
- Before rewriting any commit, run git fetch and make sure it isn't already on origin/main.
- When a feature lands, update README.md in the same task with fresh screenshots and a recording captured
  from the running app (steps in CONTRIBUTING.md). The README never mentions AI tools used to build Komodo;
  Komodo's own AI features are showcased once they ship.
- Before saying a task is done: xcodebuild with zero warnings, swift format lint --strict clean,
  swift test in KomodoCore passing.

Then continue from docs/HANDOFF.md §4 "Next task": trying Todoist, Notion, Linear, ClickUp and Asana against
real accounts once I share test tokens; ask me §9's questions first. §4 lists every phase that remains.
The XCUITest smoke tests wait until I give you the screen (they drive the pointer).
Gmail → Calendar stays parked until I say so. Try
persistence on a scratch file with -databasePath, never the real board. My own Komodo may be running: check
pgrep, launch scratch runs with open -n -g and stop them by pid, never quit by bundle ID. Release builds ignore
every Debug flag and open my real database, so ask before running one. Ask before anything that shows a macOS
permission prompt (microphone, speech, Calendar, notifications). I use this Mac while you work: capture Komodo's own windows (screencapture -l) with the Debug
launch flags and -quietCapture instead of moving my pointer. Show me a screenshot of the running app next to each
PNG, and list every place where you followed one spec over another. Ask me HANDOFF §9's questions, and ask
before adding any dependency (bundle cost plus one alternative). The README demo video waits until I give you
the screen; ask before recording.
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
| 5f-1 | Settings window | ✅ | General, Focus, Alerts & sounds, Celebration, Shortcuts, About; checked against `Settings.png` |
| 5f-2 | System surfaces: menu bar extra, notifications and reminders, global shortcuts | ✅ | Carbon hotkeys, no dependency (§6); see §5 for what wasn't exercised |
| — | Trash and archive, focus restore, crash recovery, day rollover | ✅ | Gaps from §5 closed between milestones; Trash checked against `Trash.png` |
| 5g | Data & backup, Onboarding, celebration GIFs | ✅ | Checked against `DataSheets.png`, `Onboarding.png`, `Celebration.png` |
| 5g | Gmail → Calendar | ⏸ Parked | The maintainer's call on 2026-09-29; §9 question 1 still open |
| — | P0 polish: lists, timed tasks, sleep, App Nap, scheduled alerts, scrolling title, File and Help menus | ✅ | 2026-10-01; tried on a scratch database |
| — | Idle CPU | ✅ | Timer digits and colon on Core Animation; ~3–4% idle in an optimized build |
| P1 | Reports and Sessions | ✅ | Checked against `Reports.png`; breaks recorded (schema v4) |
| P1 | End-of-day review and streak rules | ✅ | 2026-10-02; End Day, carry-over, clean sweep, "in a row today", Streaks switch |
| P1 | Password-protected backups | ✅ | 2026-10-02; `.kbak` export, daily backup and restore, password in the Keychain |
| P1 | Local MCP server | ✅ | 2026-10-02; hand-written JSON-RPC helper, Settings page, live refresh, `komodo://start` |
| P1 | Calendar import, Integrations page | ✅ | 2026-10-02; macOS Calendar through EventKit, the maintainer's call |
| P1 | Settings ▸ AI | ✅ | 2026-10-02; Apple Intelligence status, Claude key (Keychain, free check), model |
| P2 | Komodo Assistant | ✅ | 2026-10-02; on-device or Claude, editable preview, @ commands, one Undo |
| P2 | Voice input and voice notes | ✅ | 2026-10-02; on-device dictation; tried with a simulated voice only |
| P2 | Todoist sync | ✅ | 2026-10-02; two-way, one project per list; documented responses only, no real token yet |
| P2 | Notion, Linear, ClickUp, Asana | ✅ | 2026-10-03; one `ProviderAdapter` each on a shared `ProviderSync`; documented responses only, no real token yet |
| P2 | **Task tools with real tokens** | ⏭ **Next** | Needs the maintainer's test tokens; see §4 |
| P1 | Claude mode, Review tab, reschedules | ⏸ Parked | They're parts of Gmail → Calendar (FEATURES §4.0) |
| P2 | Light appearance | ⏳ Later | DESIGN_SYSTEM §2: dark only so far |
| — | Release: signing, notarizing, DMG, Sparkle | ⏳ Later | ARCHITECTURE §15; needs the maintainer's Developer ID |
| — | XCUITest smoke tests | ⏸ Waiting | Needs the maintainer's screen |
| — | Persistence (SQLite with GRDB) | ✅ | Write-through from `BoardStore`; see §3 and §5 for what's left |

Screens done: Main, Inspector, Quick add, Schedule, Focus Panel, FocusStates, Floating timer, Celebration,
Palette, Settings (General, Focus, Alerts & sounds, Celebration, Shortcuts, Integrations, Data & backup, AI,
Local MCP server, About), System (menu bar, notifications), Trash, DataSheets, Onboarding (steps 1–5 and the
Start tip), Reports, Assistant (all five states). Screens left: Gmail (connect, Overview, Settings, Activity,
Review) and onboarding step 6, all parked with Gmail; Settings ▸ Gmail → Calendar (dimmed in the sidebar). The
token sheet serves all five task tools. Reports states left: loading (nothing loads slowly on a local
database).

---

## 3. How the code is organised

```
Komodo/
  App/                KeychainSecret (one generic Keychain item per secret, with a Debug launch-flag override),
                      KomodoApp (scenes incl. MenuBarExtra, commands, LaunchOptions), AppDelegate (attaches the
                      store; Dock policy, hotkeys, day rollover, notification actions), FocusAlerts
                      (notifications, reminders), GlobalHotKeys (Carbon), Sounds (KomodoSound.play),
                      FocusCommands, FileCommands, HelpCommands, DebugCommands (Debug menu, gallery)
  DesignSystem/       Palette, Typography, Metrics (Space/Radius/Layout), Motion, Elevation,
                      WeightedHStack, FlowLayout
    Effects/          Spotlight, BeamBorder, FocusDial, OdometerText, TimerTone, Ping, Shake, Sheen, Rise, Aurora,
                      Marquee, HostedLayer (SwiftUI content Core Animation slides or fades), LayerEffect (hosts the
                      Core Animation loops)
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
  Features/Settings/  SettingsView (sidebar + page), SettingsSection (pages, search keywords), SettingsKit
                      (group, row, switch, menu picker, duration stepper, sound preview), one file per page:
                      General, Focus, Alerts, Celebration, Shortcuts (key recorder), Integrations, Data, AI,
                      Local MCP server, About
  Features/MenuBar/   MenuBarView (MenuBarLabel with the live time; MenuBarMenu with the live task and items)
  Features/Trash/     TrashView (shown in place of the Board when store.page is .trash): task and list rows
  Features/Lists/     ListEditorSheet (new, rename, color & icon), DeleteListSheet (typed name)
  Features/Reports/   ReportsView (header, filters, tabs), OverviewReport, PunctualityReport, TimeSpentReport,
                      SessionsReport, SessionSheet, SessionsExport (PDF, CSV), ReportTable, ReportsFormat,
                      BoardStore+Reports (ReportsState)
  Features/Backup/    BoardStore+Backup (export, daily backup, restore, delete all, protection), BackupSheets
                      (restore confirm, restore errors, typed delete, set and enter password), BackupPassword
  Features/Integrations/ CalendarSync (EventKit: access, calendars, sync on launch, change and day rollover),
                      TodoistSync (poll loop, connect, disconnect, one sync round), TodoistClient (sync
                      endpoint, TodoistError), TodoistToken (Keychain), TodoistTokenSheet
  Features/AI/        AppleIntelligence (FoundationModels status), ClaudeKey (Keychain item + free key check),
                      AssistantBrain (on-device guided generation or Claude structured output)
  Features/Assistant/ AssistantModel (conversation state), AssistantPanel (popover, rows, listening, waveform),
                      AssistantBubble (bubble + host, ⌘J)
  Features/Voice/     SpeechTranscriber (AVAudioEngine → SFSpeechRecognizer, on device only)
  Features/Onboarding/ OnboardingView (sheet, steps, dots), OnboardingStages (plan, focus, win, notification
                      drawings), OnboardingTodayStep (lines with EST chips)
  Windows/            FocusPanel (FocusSurfaceController: sets Home aside, docks the panel, shows the timer),
                      FloatingTimerPanel (pill window plus the celebration window above it),
                      SettingsWindow (SettingsWindowController: an AppKit window opened by store.settingsRequests)
  Resources/          AppIcon.icon (Icon Composer), Assets.xcassets (color sets, menu bar icons),
                      CelebrationGIFs (ten Animated Noto Emoji, CC BY 4.0, 200 px)
KomodoMCP/main.swift  komodo-mcp: stdio loop around MCPServer, embedded at Contents/Helpers
scripts/render-icons.swift  Renders the AppIcon.icon layers and the menu bar template images
KomodoCore/           Pure logic, no UI, tested with Swift Testing
  Models/             LocalDate, TaskItem (+Bucket, Subtask, WorkSession, TaskSource), TaskList
  Board/              WeekRange, BoardLayout, DayPlan, DaySummary, FocusHistory, TaskSearch, CelebrationCopy,
                      Reminders (upcoming task reminders), Trash (30-day rule), CarryOver, CalendarImport
  Settings/           AppSettings (every Settings value, stored as preferences), KeyCombo, GlobalShortcut
  Backup/             Backup (export zip, open and check, prune, file names), BackupManifest, CSV, BackupCrypto
                      (.kbak: AES-GCM + PBKDF2)
  MCP/                JSONValue, MCPServer (JSON-RPC), KomodoTools (+Definitions)
  Assistant/          AssistantPlan, AssistantPrompt, AssistantResolver (+Grounds), DayPhrase, RequestPhrase,
                      TaskCommand
  Storage/            AppDatabase (GRDB: v1 + v2 trash/archive migrations, load splits tasks/trash/archived,
                      write-through, preferences), BoardChange (the diff)
  Timer/              FocusClock, TimerFormat, PomodoroCycle, CrashRecovery, AwayTime
  Reports/            ReportRange, ReportData + ReportOverview, Productivity, Punctuality, TimeSpent, SessionLog
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
- **Persistence:** `BoardStore.persistent()` opens `Application Support/Komodo/Komodo.sqlite`. `tasks` and
  `lists` write through in their `didSet` via `BoardChange`, and the settings save as preferences. Only the
  launch path touches the file; previews and the Debug sample flags pass no database.
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
- **Settings:** Focus values (Pomodoros, lengths, side, sounds) are `BoardStore` properties shared with Quick
  Settings; everything else is `store.settings: AppSettings`, whose `didSet` writes only the changed keys.
  Surfaces follow settings with `withObservationTracking` loops (AppDelegate, FocusSurfaceController).
- **Opening windows from anywhere:** the store bumps a counter (`settingsRequests`, `homeRequests`) and the
  owner observes it: `SettingsWindowController`, and `MenuBarLabel` for Home (it's always alive).
- **Sounds and alerts:** every sound goes through `store.play(_:)` so the Sounds switch and volume apply.
  Timed work (sprint end, break end, Time's Up, timed alerts, heartbeat) are `Task`s re-armed from
  `syncSprint()`, which every open/close of a session passes through.
- **Trash and archive:** separate `trash` / `archived` arrays with their own write-through, so `tasks` only
  holds what the Board shows. Delete = move to trash with Undo.
- **Lists:** `allLists` holds every list in sidebar order with its `deletedAt` / `archivedAt`; `lists` is the
  active ones, which every picker reads. Tasks of a hidden list sit in `shelved` (loaded apart by
  `AppDatabase.load`) and come back with the list. Never move a list between arrays: the lists diff deletes rows
  missing from the array, and the database cascades that to its tasks. The last active list can't be archived or
  deleted (`canRemoveLists`). Trash reads `trashItems`, where a deleted list is one row holding its tasks.
- **Time-driven layout:** `layout` passes `now`, so timed tasks whose minute has passed lead Up next.
  `syncScheduleTick` sleeps until the next start today and bumps `scheduleTicks` so views redraw on time.
- **Focus alerts:** `arming(_:in:)` schedules sprint end, break over and Time's Up with the system when the
  in-app timer starts, only for a saved board; `disarm` withdraws one that's still ahead. `FocusAlerts` runs
  arm and cancel on one serial queue.
- **No SwiftUI animation that never settles.** A looping `phaseAnimator` or a spring retriggered every second
  makes SwiftUI lay out the whole window each frame (that was the 50% idle). Loop with `LayerEffect`, and move
  SwiftUI content with `HostedLayer` (its own hosting view, animated through its layer).
- **Reports:** `store.reportData` narrows `reportTasks` (Board, archived and shelved tasks; never Trash) and
  `breaks` to the chosen list; each tab builds its KomodoCore report from it during render. Filters live in
  `store.reports`. Breaks are recorded from `focus.breakEndsAt` changes in `recordBreak`. Sessions edits go through
  `saveSession` / `setSessions` / `saveBreak`, which find a task wherever Reports sees it.
- **Relaunch:** `pauseForQuit()` saves the live task, surface and break as preferences; the init restores
  them, or after a crash closes the open session at the saved heartbeat (`CrashRecovery`).
- **Backup and restore:** every file in a zip comes from one `VACUUM INTO` snapshot. A restore checks the zip's
  file list before unzipping, then the manifest, SQLite's integrity check and a load, and migrates the copy; it
  goes in with SQLite's online backup into the open pool, and `BoardStore.reload()` rebuilds the board with
  writes paused. So there's no file swap and no `ValueObservation` yet. Backup status settings (folder, last
  backup, last export, failure) are kept across a restore because they describe the Mac, not the data.
- **Onboarding:** shown when a saved board has no tasks, no trash, no archive and no `onboarded` preference, so an
  existing board never sees it. `finishOnboarding(adding:)` adds the lines to Today and raises the Start tip.
- **Outside writes:** `komodo-mcp` writes the file and posts `app.komodo.db-changed`; `AppDelegate` hears it and
  calls `BoardStore.absorbOutsideChanges()`, which re-reads rows without resetting the page or the live task.
- **Secrets:** every secret is a `KeychainSecret` (backup password, Claude key); the database only stores a flag
  (`protectsBackups`, `hasClaudeKey`) so nothing reads the Keychain unless it has to.
- **Calendar import:** `CalendarSync` reads EventKit and hands `CalendarEvent`s to
  `BoardStore.importCalendarEvents`, which runs the pure `CalendarImport.sync` rule. Task IDs are
  `calendar:<external ID>@<start>`.
- **Todoist:** each poll, `TodoistSync` asks `ExternalSync.pushes` what changed here since the links in
  `external_links` were agreed, sends them as `Todoist.Batch` commands in the same `/api/v1/sync` request that
  reads Todoist's changes, then runs `confirm` (what Todoist accepted) and `pull` (Todoist's changes), saving tasks
  through `BoardStore.saveImported`. Imported task IDs are `todoist:<item id>`. The connection's settings and
  sync token live in `AppSettings`; the token is `KeychainSecret.todoistToken`.
- **Assistant:** a brain returns an `AssistantPlan`; `AssistantResolver` keeps it to the user's words (per-phrase
  values, `@` commands, grounding, skipped phrases) and builds the preview; `applyAssistant` saves it with one undo.
  The resolver, not the model, decides days, times and lengths.
- **Narrow widths:** `ViewThatFits` fallbacks keep the Today column readable at the 1200 pt default window.
  The wide layout is the one that matches the canvas.

---

## 4. Next task, and everything that remains

### Next task: the task tools against real accounts (Phase 2)

Every provider is built against its documented responses, and none has met a real account. With the
maintainer's test tokens, for each of Todoist, Notion, Linear, ClickUp and Asana: connect a scratch database
(`-databasePath`) to a throwaway project, database, team or list, and try import, an edit each way, a completion
each way, a status move (Notion, ClickUp), Schedule by both ways (Notion, ClickUp, Asana), subtasks (Notion,
Asana), Sync deletes and a refused change. Record a real answer for each and swap it in for the
documented-shape fixtures in `TodoistTests`, `LinearTests`, `AsanaTests`, `ClickUpTests` and `NotionTests`.
§5 lists what each provider's docs left open.

### Everything that remains, by phase

**Phase 0a: Gmail → Calendar (parked by the maintainer since 2026-09-29)**
- FEATURES §4.0, DESIGN_SYSTEM §13.17–13.20, `Gmail.png`: connect Google, the two Komodo calendars, On this Mac
  extraction, the activity log, and its Settings page (dimmed in the sidebar today).
- It also brings onboarding step 6, the menu bar's Gmail rows, the sidebar status row, "and disconnects Google"
  in Delete all data, and the restore success sheet's Reconnect.
- Waits on §9 question 1 (OAuth client and sign-in approach).

**Phase 1: what's left**
- **Claude mode for Gmail**, the **Review tab** (DESIGN_SYSTEM §13.20, suggestion cards) and **reschedules and
  cancellations** (FEATURES §4.0): all part of Gmail → Calendar. Settings ▸ AI's "Use Claude for Gmail" box, the
  Claude mode warning and the "What's sent to Claude" explainer come with them.
- **XCUITest smoke tests** (ARCHITECTURE §14: Plan → Start → Done, and Export → Delete all → Restore) once the
  maintainer gives the screen.
- **Acceptance on the maintainer's Mac** (ARCHITECTURE §16: "every P1 acceptance check passes"): real Calendar
  access, a real MCP client, a working Claude key, notifications and global shortcuts tried by hand. Each needs
  the maintainer's go-ahead or setup.

**Phase 2: what's left**
- **Task tools against real accounts** (the next task above).
- **Light appearance** (DESIGN_SYSTEM §2: "Light is P2"): Light values for every color set, and the Settings
  appearance choice. Increase Contrast variants are missing too (§5), which DESIGN_SYSTEM §8 expects. Neither has
  values in the spec yet (§9 question 7).
- **Real voice:** voice was only tried with a simulated voice; try the microphone once the maintainer allows the
  prompts.
- **Assistant with Claude:** try once a key is in Settings ▸ AI; check the structured-output schema is accepted
  (nullable union types) and the refusal path.

**Release (ARCHITECTURE §15)**
- Signing with the maintainer's Developer ID, hardened runtime (already on), notarizing, a DMG, then Sparkle for
  Check for Updates (About's button is disabled until then) and Release notes. Re-check the Keychain and Calendar
  behavior on a signed build, since ad hoc builds may ask for Keychain access after each rebuild.
- Measure the Release helper (6.4 MB) and app (32 MB) once more and decide whether GRDB should live in one
  shared framework instead of twice.

**Polish carried in §5** (no phase of their own), each waiting on a design decision (§9 question 7) or its
screen: list image icons and the backup's `assets/`, an Archive screen, onboarding's moving drawings, the floating
card's GIF and "in a row" pill, the shared table, suggestion card and page-dot components, Komodo's own sounds,
and the Reports loading state. Done in 0.9.0: Load earlier, the pulsing rings, the panel's Scheduled today **+**
and row dragging, the won card's sparks, the `.kbak` type, saved list and Pomodoro count, A4 PDFs.

**Maintainer-only steps:** test the 0.9.0 DMG end to end, re-record the README demo video (ask first), foreground
captures with green switches, and trying notifications, global shortcuts, the menu bar, Calendar access, the
microphone and a Claude key by hand. Also untried by pointer from 0.9.0: dragging Focus Panel rows, the Scheduled
today **+** click (tried through `-addScheduled`), and double-clicking a `.kbak` in Finder (tried with `open -a`).

**Release (0.9.0 onward):** CONTRIBUTING.md ▸ Releases. The 0.9.0 DMG is ad hoc signed; Gatekeeper blocks it until
the `xattr` step in the notes. The Release app measured 34 MB on disk and the DMG 10 MB.

## 5. Known gaps and placeholders

- **Notion, Linear, ClickUp and Asana** (2026-10-03):
  - None has been tried against a real account; the fixtures follow each provider's documented response shape.
  - ClickUp leaves `due_date_time` and `start_date_time` out of some answers. Without the flag, a date counts as
    timed unless it falls on midnight here; check what real answers carry.
  - Asana: clearing a date sends `due_on: null` (or `start_on`) alone; whether that also clears a `due_at` isn't
    documented. A start sent with no due date is sent as the due date too, since Asana refuses a lone start.
  - Notion reads the first date property (by name) and the first people property; a database with several has no
    way to pick another yet. A plain `select` called Status stands in when there's no status property. Notes stay
    in Komodo, since Notion keeps them in the page body.
  - Linear reads its first 20 pages (2,000 issues) per read, and the same cap applies to Asana, ClickUp and Notion.
  - A status only places an undated task; a dated one always goes by its date. Moving a dated task between columns
    sends no status.
  - Changing the date mapping agrees the links with the tasks first, so the provider's dates win on the next pull.
  - If saving imported tasks fails (as the sample stand-ins' shared subtask IDs once made it), the links are still
    saved. After a relaunch those tasks are missing, and with Sync deletes on the next sync would delete them at
    the provider. Saving links and tasks in one transaction would close this; it applies to Todoist too.
- **Todoist:**
  - Never tried against the real API: the fixtures follow the documented response shape (§9 question 3).
  - Todoist sub-tasks come in as ordinary tasks, not as subtasks: two-way subtasks need each Komodo subtask
    linked to its own item. Sections, labels and priority aren't read, since Komodo has nothing to map them to.
  - One Todoist connection in all; changing the project means Disconnect and Connect again (needs a design for
    several connections).
  - A refused change is still retried on every sync, except ITEM_NOT_FOUND, which now unlinks.
  - A resent add relies on Todoist's documented uuid de-duplication; whether a repeated command returns its
    `temp_id_mapping` isn't documented, so without one the add takes the unlinked item with the same title from
    the same answer. Check against a real token.
  - A completion made in Todoist on a repeating task only moves the Komodo task to the next date (Todoist can't
    tell it from a reschedule); a completion made in Komodo keeps the finished task and adds the next one.
- **Persistence:**
  - The Pomodoro count carries over a relaunch on the same day and starts over on a new day.
  - No `ValueObservation`: nothing else writes the file, and a restore reloads in place. Add it with the MCP
    helper.
  - The selected list is saved. Panel positions already were: the floating timer remembers its spot per screen,
    and the Focus Panel docks to its saved side.
- **Data & backup:**
  - The Save and Open panels (Export zip, Change, Choose file…) weren't clicked; export, restore and delete were
    tried through the daily backup, `-openRestore`, `-openDeleteAll` and keystrokes, on scratch files only.
  - A restore without Google shows a "Restored." toast instead of the success sheet, whose copy is about
    reconnecting Google. A newer backup's error offers OK, since Check for Updates waits for Sparkle.
  - List icons (`assets/` in the zip) don't exist yet.
  - **Protected backups:** tried on a scratch database with `-backupPassword`, which stands in for the Keychain:
    the set sheet typed with `CGEvent.postToPid`, a sealed daily backup, a wrong then right password, and a
    sealed before-restore copy. The real Keychain wasn't touched. An ad hoc signed build may ask for Keychain
    access after each rebuild; a Developer ID build won't. The export Save panel wasn't clicked. `.kbak` is a
    declared document type (`app.komodo.backup`); opening one goes to Data & backup's restore.
- **Onboarding:**
  - Step 6 (Gmail) is left out, so the sheet counts five steps. The Start tip pulses its rings; the
    illustrations don't float or tick (static drawings, so an open sheet costs nothing).
  - Allow was pressed once in a background test, which may have shown the system notification prompt.
- **Reports:**
  - Sessions uses the header's list filter rather than its own multi-select Lists menu (two list filters on one
    tab would disagree). It shows the newest 100 sessions with Load earlier for 100 more.
  - The custom range popover, the session sheet, hover readouts and export panels weren't driven with the pointer;
    exports were checked through `-exportSessions`, and breaks on a scratch database with `-focusState break`.
  - PDF pages follow the Mac's default paper (A4 here). The loading state isn't built, since a local database
    answers at once.
- **Archive:** archived tasks and lists are kept for Reports; nothing shows them yet, and Undo is the only way
  back. A task restored from Trash into an archived list goes quietly onto that list's shelf.
- **Lists:**
  - No Create List tile on Home (FEATURES §4.1): `Main.png` draws none; the sidebar **+** and File ▸ New List
    cover it. No palette command either, since DESIGN_SYSTEM §13.7 lists none.
  - Badges are one letter or emoji; image icons (and `assets/` in the backup zip) wait.
  - Tried on a scratch database with `-deleteList` and a backdated purge, and the sheets and Trash were captured
    for the README; the context menu and dragging weren't driven with the pointer.
- **Card ⋯ menu:** its items, groups and shortcuts were checked against `BoardStates.dc.html` in code. It's a
  native menu, so it hasn't been captured, and ⌘D / ⌘⌫ on a focused card haven't been tried in the running app.
- **README recording** has not been re-recorded for 5b to 5e. The screenshots are fresh, but recording needs the
  pointer and the screen. Ask the maintainer for a window when it's time.
- **Celebration:** the floating card keeps the check, since the 240 × 180 GIF tile doesn't fit a 320 × 240 card.
  The 320 × 240 floating card leaves out "3 in a row today"; only the hero card shows it.
- **Floating timer:**
  - The scrolling title wasn't captured moving (screen locked); the marquee's pause-on-hover is untried.
  - Its window is a fixed 600 × 88 transparent frame. Clicks pass through the transparent part; that was
    reasoned from AppKit's alpha hit-testing, not tried by clicking.
  - Dragging, hover controls and the position memory weren't exercised with the pointer.
- **Command palette:** the dim covers the Board, not the sidebar. Backup, Gmail and Settings show dimmed.
  Keyboard navigation and ⌘F weren't tried with real keystrokes; each state was opened with `-openPalette`.
- **Day summary:** the review's Tomorrow / This week menus and End Day were captured through `-focusState ended`,
  not clicked. A task still ahead today isn't listed as unfinished, so it stays in Today.
- **Notifications** (`FocusAlerts`): sprint end, break over, Time's Up (panel hidden) and scheduled reminders
  with Start now / Snooze 5 min are built, but none has been triggered on the maintainer's Mac, since the first
  asks for permission with a system dialog. Reminders are replaced a second after edits and only for a saved
  board. They play the system default sound; Settings' reminder sound only covers the preview, because a
  custom notification sound needs a bundled file.
- **Sounds:** macOS system sounds stand in (Tink, Ping, Pop, Glass, and Hero for success) until Komodo bundles
  its own. The volume and Quick Settings' switch cover all of them.
- **Menu bar:** the item and its window-style menu were captured in the menu bar, but the menu itself wasn't
  opened with the pointer. Gmail rows wait for 5g. The label uses a one-second task because a `TimelineView`
  there re-renders the status item endlessly, and it opens Home at launch because a `MenuBarExtra` stops
  SwiftUI from doing so (§8).
- **Global shortcuts:** registered with Carbon and re-registered on every settings change; not pressed from
  another app yet. Background captures (`-quietCapture`) skip them. A conflict is only detected against another
  Carbon hotkey.
- **Settings:**
  - Switches draw grey in the background captures (docs/media) because Komodo wasn't the active app; a
    foreground capture needs the maintainer's go-ahead (§7).
  - Check for Updates is disabled until the signed release (Sparkle); Release notes isn't linked.
  - The Dock toggle and Open at login weren't flipped on the maintainer's Mac.
- **Focus restore:** a relaunch brings the live task back paused, in its surface, with an unfinished break;
  the Pomodoro count starts over.
- **Sleep:** the away toast counts by default and offers Discard; the current sprint isn't shifted by a discard.
  Not tried with a real sleep yet.
- **Scheduled focus alerts:** only a saved board arms them. A crash can leave one pending until the next launch
  clears it. None has been seen firing on the maintainer's Mac.
- **Focus Panel:**
  - The Scheduled today **+** adds a task at the next half hour and opens the Schedule popover beside the panel.
  - Rows have Make live, Done, Duplicate and Delete. Schedule, Subtasks, Notes and Move to list open the Home
    window, so they're left out of the panel's menu. Rows drag to reorder (not tried with the pointer).
  - Start → panel → Home was only exercised through the launch flags, not by clicking in the running app.
  - If Home was closed before Start, leaving Focus mode opens it afresh.
  - Hidden windows' timers idle (`isOffscreen`); with Home visible and a task live, the Board still spends about
    4% CPU on its one-second layout pass.
- **Local MCP server:**
  - Driven over stdio against scratch files and seen refreshing a running scratch instance; not yet connected
    from Claude Desktop, Claude Code or Raycast.
  - `start_focus` wasn't opened live: with the maintainer's own Komodo running, `komodo://` would reach that
    copy. `komodo://start` is handled in `AppDelegate.application(_:open:)`.
  - The helper is 8.9 MB in Debug (GRDB is linked into it as well as the app); measure it in Release.
  - "Works while Komodo is running" is the spec's copy, but the helper also works with Komodo closed: writes land
    in the file and show at the next launch, and `start_focus` launches Komodo.
- **Calendar import:**
  - Tried with `-sampleCalendar YES` on a scratch database; real EventKit wasn't read, because Connect shows the
    system's Calendar access prompt on the maintainer's Mac. Ask before pressing it.
  - A recurring event's occurrences are told apart by external ID plus start, so moving one occurrence makes a
    new task and unlinks the old one.
  - A task only knows its calendar's name. A name an unread calendar also uses is left out of unlinking, so such
    tasks stay linked when their event goes; telling them apart needs the calendar's identifier on the task.
  - Switching a calendar off unlinks its open tasks in range rather than deleting them, as FEATURES §5 says.
- **Settings ▸ AI:** Test was checked against the Models API with a bogus key (401 → "Anthropic didn't accept
  this key"); a working key and its save to the Keychain weren't tried. The Claude mode warning and the What's
  sent to Claude explainer wait for Gmail.
- **Komodo Assistant:**
  - Tried with Apple's on-device model through `-assistantPrompt` on scratch databases: brain dumps, @ commands,
    Add and the applied card. The Claude path wasn't run (no key). Clicking, editing titles in the preview,
    Discard, Undo and ⌘J weren't driven with the pointer.
  - The on-device model is uneven; the resolver keeps the preview honest (see §6), but titles can still be
    terse ("Deck").
  - The input reads "Type or hold mic to talk…", the spec's copy, before the mic exists.
- **Voice:** tried only with `-voiceSample`, a simulated voice; the microphone and Speech permission prompts
  haven't been shown on the maintainer's Mac. Ask before the first real try. The hold gesture on the
  Assistant's mic and the inspector's buttons weren't driven with the pointer.
- **Gmail status row** in the sidebar is hidden, because Gmail isn't connected (DESIGN_SYSTEM §12).
- **Components not built yet** (DESIGN_SYSTEM §9): table and suggestion card (Gmail's Review tab). The integration
  card and code block exist (`IntegrationCard.swift`, `CodeBlock.swift`). Page dots and the folder picker exist
  inside onboarding and Data & backup, not as shared components. Build each with the screen that uses it.
- **README recording** (`board.gif`) still shows the old sidebar mark (clock hand, no check).
- **Increase Contrast:** the color sets have dark and universal values only, no Increase Contrast variants.
- **Archive:** no screen shows archived lists or tasks; it needs a design (§9 question 7).
- **Test file:** the original scaffold test file (`KomodoCoreTests.swift`) was replaced before it was ever
  committed. Its contents are unknown, and the current suites cover FocusClock, TimerFormat, DurationFormat,
  EstimateParser, BoardLayout, DayPlan, DaySummary and FocusHistory.

---

## 6. Decisions made (and where one spec was followed over another)

| Topic | Decision | Why |
| --- | --- | --- |
| Task tool UI | The four new providers reuse Todoist's card, token sheet and settings group, with their own words | No canvas draws them; DESIGN_SYSTEM §13.17 only describes the Coming soon tiles |
| Schedule by | Due date by default; with it, Komodo's own due date stays local | Most ClickUp and Asana tasks have only a due date, and they'd all land in Backlog with Start date |
| Status mapping | Places undated tasks only; a dated task goes by its date | FEATURES §5 "Imported tasks are placed by date"; the Board has no column for a dated task to sit in otherwise |
| Linear dates | Its due date is the schedule | Linear has no planned date, and Todoist's due date is the schedule too |
| Notion notes | Not synced | Notion keeps a page's text as blocks, not a property; reading blocks is a request per page |
| Deletions | Every sync reads all open items for the four new providers | None lists deletions; finished items missing from the read stay linked |
| Button heights | 28 / 34 / 40 pt | The canvas wins on pixels; DESIGN_SYSTEM text says 24/28/36 |
| Switches, segmented pickers | Native | DESIGN_SYSTEM "native first"; the canvas draws custom ones |
| Sprint state | A Sprint display choice: Task (default) or Sprint | The maintainer's pick. Task follows `Main.png` / `FocusPanel.png` (lime, estimate, sprint chip); Sprint follows DESIGN_SYSTEM §10.2 and FocusStates ④ (pink, sprint countdown). It lives in Quick Settings until Settings lands |
| Schema v1 | Mirrors the models: a repeat rule is a JSON column, ranks are REAL, estimates are seconds, instants are seconds since 1970 | Keeps the mapping lossless; ARCHITECTURE §5's `recurrences` table and text ranks can come with a later migration if needed |
| First launch | One list, "Personal" | Something to add tasks to until onboarding asks for lists |
| Storage errors | Logged, plus a toast: "Couldn't save your changes" / "Couldn't open your tasks" | Never lose work silently; no spec copy for it |
| Persistence | GRDB approved by the maintainer | Adds roughly 2–4 MB to the app (to be measured when it lands). Alternative: the system SQLite C API through `import SQLite3`, which costs nothing but needs hand-written statements, migrations and observation |
| Pomodoros default | On | The maintainer's call, matching `Main.png` and `FocusPanel.png`; FEATURES §4.18 now says On |
| Sprint-end notification | "Sprint 2 of 4 done" · "Take 5min. Design review is paused." | DESIGN_SYSTEM §14.2 has no sprint-end row; FEATURES §4.10 asks for one |
| Alert sound | macOS "Glass" | No bundled sounds yet (`success.caf` is named on the canvas) |
| First release | 0.9.0, ad hoc signed DMG on GitHub Releases | Gmail → Calendar (P0) is parked, so it's a preview; signing waits for a Developer ID (§9 question 6) |
| DMG labels | Light plates under both icon labels in the background art | Finder draws icon labels black on a custom background, unreadable on Komodo's near-black |
| Todoist unlink | The task keeps `source = .todoist` and loses its URL | Clearing the source made a Komodo-made task look new, so it was sent back to Todoist |
| Shared calendar names | Left out of unlinking | Tasks keep only the calendar's name; the safe direction is staying linked |
| Scheduled today + | Next half hour, then the Schedule popover | The canvas draws only the button; Komodo has no time parsing in titles |
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
| Global shortcuts | Carbon `RegisterEventHotKey`, no dependency | The maintainer's pick (2026-09-29). KeyboardShortcuts was the alternative; conflicts are only detected against other Carbon hotkeys |
| Settings sounds | macOS system sounds by name | No bundled sound files yet; each has a preview button |
| Settings segmented control | Native `.segmented` for Panel side | Matches Quick Settings; the canvas draws `.k-seg` |
| Celebration preview | The real check and burst at 52 pt, rebuilt on Preview | Reuses `CelebrationCheck` and `CelebrationBurst` instead of a second animation |
| Menu bar menu | `MenuBarExtra` with `.window` style | The live task row with Pause, Done and Skip needs custom views; a `.menu` style can't draw them |
| Trash | Separate `trash` and `archived` arrays in the store and `StoredBoard` | Nothing on the Board, in search or reminders has to skip them |
| Empty Trash | Asks first with a confirmation dialog | Can't be undone; the canvas shows no dialog |
| Crash recovery | A toast "Resume <task>?" and the task live but paused | ARCHITECTURE §4.3 says "asked"; a toast doesn't block launch |
| Celebration GIFs | Ten Animated Noto Emoji by Google, CC BY 4.0, credited in About and the README | The maintainer asked for funny GIFs bundled without review; meme GIFs are copyrighted, these can ship |
| GIF on the floating card | The check stays | `Celebration.png` only shows the GIF in the panel; a 240 × 180 tile doesn't fit the 320 × 240 card |
| Restore mechanics | SQLite online backup into the open pool, then an in-place reload | ARCHITECTURE §7 says close the pool and swap the file; this keeps the store's connection and needs no relaunch |
| Daily backup timing | A check 60 s after launch plus an hourly `NSBackgroundActivityScheduler` | FEATURES §4.21's "within 5 minutes"; ARCHITECTURE §4.4 names the scheduler at 24 h, which could miss that |
| Delete all data copy | "Deletes every list, task, and session on this Mac." | The spec's "and disconnects Google" returns with Gmail |
| Last export / last backup dates | Date and time formatted apart: "24 Sep, 10:08 PM" | Some locales join them with "at"; the canvas writes "Sep 24, 6:12 PM" |
| Keep last row | Custom row: picker and "backups" left, the status right | Matches the canvas; `SettingsRow` puts controls only on the trailing side |
| Onboarding trigger | An empty saved board without the `onboarded` preference | The maintainer's board already has tasks, so it never sees onboarding |
| Onboarding step count | Five, Gmail left out | Gmail → Calendar is parked |
| ⌘Return in onboarding | Caught with `onKeyPress` on the editor | The text view takes ⌘Return before the button's shortcut |
| Menu bar and in-app mark | The check replaces the clock hand in the idle and attention states and in `KomodoMarkShape` | Matches the app icon. `System.png` draws a hand. Running keeps the spec's filled wedge |
| List sheet | One `FormSheet` for New list, Rename and Color & Icon: name, eight swatches, a one-character badge with a preview | No canvas or copy for it; titles "New list" / "Edit list" and the field hints are new strings |
| Delete list confirm | Type the list's name; "The list and its N tasks move to Trash for 30 days." | FEATURES §4.1 asks for the typed name; the layout follows Delete all data's sheet |
| Last list | Archive and Delete are off for the last active list | New tasks always need a list to go to |
| Deleted list in Trash | One row with its badge and a violet List chip, holding its tasks; restoring it brings them back | `Trash.dc.html`'s Growth row; a task deleted before its list keeps its own row |
| List reorder | A dragged list takes the place of the row it's dropped on | Lets a list reach the bottom without a drop gap |
| Timed task arrives | Joins the top of Up next in time order; a panel waiting on the calm card starts it | FEATURES §4.6 says it joins the queue; the calm card says it "joins the queue on time", and an empty hero would be blank |
| Away toast | "You were away 47min." · "Count it or discard it?" with Discard; counting is the default | ARCHITECTURE §4.3's question; `47min` follows DESIGN_SYSTEM §3's duration format |
| Scheduled alerts | Only for a saved board; cleared at launch and quit | A sample capture must never leave a notification pending on the maintainer's Mac |
| ⌘⌥T | File ▸ New Task instead of Home's hidden button | DESIGN_SYSTEM §14.3; the menu reaches it from every Komodo window |
| Restore from Backup… | Opens Settings ▸ Data & backup | The file picker and confirm live there |
| Diagnostics log | This process's Komodo log entries, up to 500 | DESIGN_SYSTEM §13.15 says "the app's own logs"; the unified log keeps values private |
| Odometer and colon | Core Animation through `HostedLayer`, same spring (response 0.4, bounce 0.38), beat and blink | The SwiftUI versions kept the window laying out every frame |
| Reports "7 days" | The current week, Monday to Sunday by default | `Reports.png` draws Mon–Sun with today on Saturday; its subtitle says "Last 7 days", kept as copy |
| Tile sparklines | The same metric over the last seven ranges | The canvas's spark arrays are weekly values |
| Tile chips | Counts for work days and tasks, % for hours, minutes for average; a longer average is amber | Canvas copy per range ("vs last Sat", "vs prior 30 days", "vs Aug 1 – 26") |
| Date spans | The system's date-interval format | "Sep 21 – 27" in US English, "21–27 Sep" in British English |
| Most productive day | The weekday with most tasks done in the range, work breaking ties | The canvas's chips count tasks per weekday |
| Charts | Swift Charts (system framework, no bundle cost) | DESIGN_SYSTEM §13.12 names `BarMark`, `LineMark`, `SectorMark` |
| Segmented range control | Native `.segmented`; Custom opens two date fields | "Native first", as for other segmented pickers |
| Sessions list filter | The header's list filter | The canvas also has a Lists multi-select on Sessions; one filter for all tabs is simpler |
| Running session | Read-only in Sessions (no Edit or Delete) | Editing the live session would fight the running clock |
| Added break | Not tied to a task | The canvas: "Break · not tied to a task" |
| Time spent | The top list starts open | The canvas's `openList: 'W'` |
| Report sample history | Nine months of archived weekday tasks and breaks | Reports need history; archived keeps the Board, bars and streak as on `Main.png` |
| Streak days | A day counts with one task done, archived ones included | FEATURES §4.13; the code had counted any focused time |
| Streaks switch | A fourth row in Settings ▸ Celebration | `Settings.png` draws three; FEATURES §4.13 says streaks can be switched off, and FEATURES wins on behavior |
| In a row | Early or on time, counted back from the latest finish; no estimate is skipped; shown from 3 | `Celebration.png` ① shows the chip; no spec gives the rule |
| Floating celebration | No "in a row" pill | The 320 × 240 card has no room |
| End Day | In the Focus menu and the palette, in the review's amber | FEATURES §6.4 makes it a flow; DESIGN_SYSTEM §13.7 lists no palette command for it |
| Unfinished tasks | Today's open tasks whose time has come, in every list | A task still ahead today isn't unfinished yet |
| Carry-over | Tomorrow keeps the time of day; This week clears the date | This week matches dragging a task there |
| Backup password storage | The Keychain, plus a `protectsBackups` setting | The daily backup must seal unattended; the flag stays with the Mac across a restore, like the backup folder |
| Password sheets | Komodo's form sheet with a lock in teal; copy written for them | `Settings.dc.html` draws only the switch and its "Saved as an encrypted .kbak file." line |
| Delete all data | Also removes the backup password | It leaves a first-launch Mac, and the switch resets with the other settings |
| Wrong password | Stays on the password sheet | AES-GCM can't tell a wrong password from a changed file; a wrong password is far likelier |
| MCP transport | Hand-written JSON-RPC 2.0 over stdio | The maintainer asked for Phase 1 to finish; no dependency needed asking about, and four methods are small |
| MCP refresh | A Darwin notification and an in-place re-read, not `ValueObservation` | Only the helper writes from outside, and the notification costs nothing at idle |
| New MCP tasks | Backlog of the first list unless a column or date is given | FEATURES §5: imported tasks with no date go to Backlog |
| Calendar import | macOS Calendar through EventKit, not Google and Microsoft sign-in | The maintainer's call on 2026-10-02: no OAuth client, tokens or dependency, and every account the Mac has |
| Calendar sync timing | EventKit's change notification, launch, day rollover, Sync now | Replaces ARCHITECTURE's 5 min poll; Calendar says when something changed |
| Imported events | The event wins for title, time and length; Komodo's notes are kept; done tasks are left alone | FEATURES §5 says the newer change wins; an event has no edit time EventKit exposes reliably |
| Integrations page | One Calendar import card; Gmail as coming soon | DESIGN_SYSTEM §13.17 drew Google and Microsoft calendar cards |
| Todoist API | v1 sync endpoint for reads and writes | One request a poll, and incremental changes include completions and deletes, which the task list endpoints don't |
| Todoist connection | In `AppSettings`, not ARCHITECTURE §5's `connections` table | One account per provider needs no table or second migration |
| External links | A `snapshot` of the synced fields per link | Drags, completions and other board changes don't stamp `edited_at`, so it couldn't find local edits |
| Todoist pushes | Only the changed fields | Rewriting an untouched due date would drop a Todoist repeat rule |
| Todoist estimates | An undated task's estimate stays in Komodo | Todoist keeps a duration only beside a due date |
| Todoist pushes new tasks | Only tasks made in the list after connecting, not repeating ones | Connecting shouldn't copy a whole list into Todoist; each occurrence would become its own task |
| Todoist date and status mapping | Not offered | Todoist has one date and no statuses (FEATURES §5's settings assume both) |
| Token sheet | Project and list pickers after a passed test; Test inside the field | DataSheets.dc.html shows neither, but one project per list needs the choice; the field matches §10.6's Claude key field |
| Claude models | `claude-opus-5-5` (default) and `claude-sonnet-5-5` | The canvas names `claude-opus-5` and `claude-sonnet-5`, now a generation old |
| Claude key check | `GET /v1/models/<model>` | Free, and tells a bad key from a model the key can't use |
| AI page before Gmail | Use Claude for disabled; no Claude mode warning or payload explainer | Both describe Gmail's Claude mode, which isn't built |
| Assistant values | Each task's day, time and length come from its own phrase; ungrounded values are dropped | The on-device model invented times, lengths and lists and moved them between tasks |
| Assistant edits | `@Task` commands read without a model; the model can't change a task the request doesn't name | The on-device model renamed and moved unrelated tasks |
| Assistant reply | The model's reply only when there's no preview; Komodo writes the applied line | The model claimed it had "called Apurva" |
| Assistant skipped items | A phrase no proposal covers becomes a task | The on-device model dropped items from brain dumps |
| Assistant shortcut | ⌘J | DESIGN_SYSTEM gives none; J was free in Home |
| Voice note in the editor | Inserted into the live text view, as typing | Reloading the editor with new notes left the old text on screen |
| Voice in the Assistant | Hold to talk, release sends; VoiceOver toggles | Assistant.png ②'s "hold mic to talk" |

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
  `components`, `gallery`, `board`, `readme`, `media`, `settings`, `focus`, `menubar`, `alerts`, `trash`,
  `handoff`, `backup`, `mcp`, `ai`, `assistant`, `voice`, `inspector`, `features`, `architecture`, `changelog`,
  `contributing`, `integrations`. Commit in dependency order so each commit builds, and
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
  - Settings: `-openSettings general|focus|alerts|celebration|shortcuts|data|about` (window "Settings"). With
    `data`, `-openRestore <zip|kbak>`, `-openDeleteAll YES` and `-openBackupPassword YES` open the sheets, and
    `-backupPassword <pw>` stands in for the Keychain. Trash: `-openTrash <count>` deletes that many sample tasks
    and shows Trash.
  - Lists: `-openListSheet new|edit|delete` (edit and delete act on the selected list) and `-deleteList <id>`,
    which pairs with `-openTrash <count>` for a list row in Trash.
  - Integrations, AI and MCP: `-openSettings integrations|ai|mcp`; `-sampleCalendar YES` stands in for macOS
    Calendar; `-sampleTodoist YES` stands in for Todoist, with `-connectTodoist YES` to connect the sample project,
    `-openTodoistSheet YES|tested` for the token sheet and `-todoistToken <token>` for the Keychain; `-claudeKey <key>` and `-backupPassword <pw>` stand in for the Keychain; `KOMODO_DATABASE=<file>`
    points `komodo-mcp` at a scratch file (pipe JSON-RPC lines into
    `Komodo.app/Contents/Helpers/komodo-mcp`).
  - Assistant and voice: `-assistantPrompt "<text>"` (plus `-assistantApply YES`) runs the real on-device model,
    about 15 s; `-assistantListening YES` and `-voiceNote <seconds>` with `-voiceSample "<text>"` simulate the
    microphone.
  - Onboarding: `-openOnboarding plan|focus|win|notifications|today` and `-openStartTip YES`. The sheet blocks
    Quit, so end those runs with `pkill` (sample data only, never a database).
  - Backups: launch without `-quietCapture` on a scratch database with its `backupFolder` preference pointed at
    a scratch folder, or the daily backup writes to `~/Documents/Komodo Backups` a minute after launch.
  - Persistence: `-databasePath <file>` points a Debug build at a scratch database. Quit with
    `osascript -e 'tell application id "app.komodo.Komodo" to quit'` to run the quit path; `pkill` acts like a
    crash, which is how crash recovery was tried.
  - Measure CPU on a Release build (`-configuration Release`); Debug idles near 50% with the same windows.
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
- **MenuBarExtra:**
  - A `TimelineView` in the label makes SwiftUI update the status button in an endless loop at launch, which
    also stops every window from appearing. Tick with a `.task` instead.
  - With a menu bar extra, SwiftUI no longer opens the first `Window` at a background launch; the label's
    `onAppear` opens Home.
- **History:** the maintainer pushes seconds after a commit. Rewrite only what `git log origin/main..HEAD`
  lists, and build each commit before committing it rather than after.
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
- **Release and sample data:** Release strips the Debug launch flags, so `-sampleTime` does nothing and the
  real board opens. For an optimized sample run, build with `-configuration Release
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG` into its own derived data folder.
- **Locked screen:** `screencapture -l` fails with "could not create image from window" while the screen is
  locked; check `CGSSessionScreenIsLocked` in `CGSessionCopyCurrentDictionary()` before retrying.
- **List arrays:** the lists diff deletes rows missing from the array and SQLite cascades to their tasks, so a
  list only ever changes flags in `allLists`, never moves to another array.
- **The maintainer's own Komodo may be running** (the Debug build, on the real board). `open -g` then just
  activates it and ignores the arguments, and `osascript … quit` by bundle ID asks it to quit. Check `pgrep -x
  Komodo` first, launch scratch runs with `open -n -g`, and stop them with `kill <pid>` of the new process
  (`pgrep -nx Komodo`), never by bundle ID.
- **Release builds ignore every Debug launch flag**, `-databasePath` included, so a Release Komodo opens the
  maintainer's real database. On 2026-10-02 one ran for 25 s next to the maintainer's copy to measure idle CPU
  (0.1–0.5%) and re-saved `lastBackupAt` with its unchanged value; nothing else was written. Measure CPU in
  Release only with the maintainer's go-ahead, or point a Debug build at a scratch file and accept Debug's
  higher numbers.
- **Parallel sessions:** two sessions editing the same folder overwrote each other once. Run only one working
  session per checkout.

---

## 9. Open questions for the user

1. **Gmail → Calendar (parked):** when it's unparked, which Google Cloud project and OAuth client should Komodo
   use, and is a Google sign-in dependency acceptable (GoogleSignIn, about 1 MB), or should it be
   `ASWebAuthenticationSession` with PKCE and no dependency?
2. **README demo video:** the maintainer will offer the screen later (2026-09-29). Ask before recording.
3. **Test tokens:** all five task tools are built against documented responses. When can the maintainer share a
   test token (or sandbox workspace) for Todoist, Notion, Linear, ClickUp and Asana?
4. **Permission prompts:** may the next session show macOS's Calendar, microphone and speech-recognition prompts
   on this Mac to try calendar import and voice for real?
5. **Claude key:** will the maintainer add one in Settings ▸ AI so the Assistant's Claude path can be tried?
6. **Release:** when should signing, notarizing and Sparkle happen, and with which Developer ID team? 0.9.0 is ad
   hoc signed.
7. **Designs needed:** Light values and Increase Contrast variants for every color set, an Archive screen (where
   archived lists and tasks show, and how they come back), how a list picks an image icon, and Komodo's own sound
   files. Each is code-only once there's a spec.
