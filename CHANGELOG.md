# Changelog

All notable changes to Komodo. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

Nothing yet.

## [0.9.0] — 2026-10-02

The first downloadable build: everything that works offline, as a DMG on GitHub Releases. Gmail → Calendar is
still parked, so this is a preview. Milestones are grouped below in the order they landed (DESIGN_HANDOFF §3
build order).

### Offline polish and the first DMG — 2026-10-02

#### Added
- **Scheduled today +** in the Focus Panel: the new task lands on the next half hour and the Schedule popover opens
  on its time. Debug flag `-addScheduled "<title>"`.
- **Drag to reorder** the Focus Panel's Up next rows, as on the Board.
- **Twinkling sparks** around the won card, and **pulse rings** around Start while the Start tip shows, both as
  Core Animation layers and off under Reduce Motion.
- **Load earlier** in Sessions: the newest 100 sessions, then 100 more per press ("Showing N of M sessions").
- **`.kbak` is Komodo's document type**: Finder shows "Komodo Backup", and double-clicking one opens Restore in
  Settings ▸ Data & backup.
- The selected list and a same-day **Pomodoro count** survive a relaunch.
- Sessions PDFs print on the Mac's default paper (A4 or Letter).
- `scripts/make-dmg.sh` and its background art: a styled install window with only Komodo and Applications in it.

#### Changed
- Version 0.9.0, build 1.
- Hidden windows stop redrawing their timers: with a task live, the Focus Panel went from 5.5% to 2.9% CPU and
  the floating timer from 4.6% to 1.7% (optimized build, 20 s average).

#### Fixed
- Todoist: a finished repeating task stays done with its sessions, and its next date arrives as a new task.
- Todoist: a task deleted there no longer comes back as a new item when it was made in Komodo.
- Todoist: a full sync unlinks items it no longer lists, a change to an item Todoist deleted unlinks instead of
  retrying forever, and an add resent after a crash can't make a second copy.
- Calendar import: tasks from a calendar sharing its name with an unread one keep their link.
- Leaving Focus mode reopens Home when it was closed before Start.

### Todoist sync (Phase 2) — 2026-10-02

#### Added
- **Todoist** on Settings ▸ Integrations (FEATURES §5, DESIGN_SYSTEM §13.17): a card with Connect, Active and
  Needs attention, the token sheet from DataSheets.dc.html (Test, project and list pickers, Save to the
  Keychain), and a TODOIST group with Sync with list, Auto sync, Sync deletes, Only my items and Disconnect.
- **Two-way sync** of one project with one list: imports placed by date, new tasks sent up, edits and completions
  both ways with only the changed fields, the newer edit winning a conflict, remote deletes that only unlink, and
  refused changes retried. Polled every 5 minutes, at launch and on wake, backing off after failures.
- `external_links` (schema v5) with a snapshot of the synced fields; `ExternalItem` and `ExternalSync` (pull,
  pushes, confirm) in KomodoCore for every provider to share; Todoist's API v1 sync types, item mapping and
  commands, with tests against documented responses. A "Todoist" source badge on cards and in the inspector.
- Debug flags `-sampleTodoist`, `-connectTodoist`, `-openTodoistSheet` and `-todoistToken`.

#### Fixed
- A task finished elsewhere while it was live now ends its session and leaves Focus mode.
- Delete all data also removes the Todoist token from the Keychain.

### Voice input and voice notes (Phase 2) — 2026-10-02

#### Added
- **Hold the mic to talk** in the Assistant (Assistant.png ②): timer, live waveform, transcript, and release to
  send.
- **Voice notes** in the inspector (FEATURES §4.5): Voice note listens, Add to notes appends the words as a new
  paragraph, undoable like typing.
- `SpeechTranscriber`: `SFSpeechRecognizer` with on-device recognition required, through `AVAudioEngine`. The
  audio-input entitlement and the microphone and speech usage strings. Debug flags `-voiceSample`,
  `-assistantListening` and `-voiceNote`.

### Komodo Assistant (Phase 2) — 2026-10-02

#### Added
- **Komodo Assistant** (FEATURES §4.19, DESIGN_SYSTEM §13.26): the lime bubble at the bottom right of Home (⌘J)
  and its 360 × 520 popover with the welcome, thinking, an editable preview, Discard, Add or Apply, the applied
  card with Undo, and errors with Try again.
- **Two brains, one plan:** Apple's on-device model through FoundationModels when Apple Intelligence is on,
  otherwise Claude with the user's key (structured output, low effort, server-side fallbacks).
- **Kept to the user's words:** each phrase sets its own task's day, time and length; `@Task` commands (move,
  log, estimate, done, rename, column, list) are read without a model; values nobody gave aren't invented; a
  brain dump never loses an item; nothing the user didn't name is changed.
- `AssistantPlan`, `AssistantResolver`, `AssistantPrompt`, `DayPhrase`, `RequestPhrase` and `TaskCommand` in
  KomodoCore, with tests. Debug flags `-assistantPrompt "<text>"` and `-assistantApply YES`.

### Settings ▸ AI (Phase 1) — 2026-10-02

#### Added
- **Settings ▸ AI** (DESIGN_SYSTEM §13.23): Apple Intelligence's status from FoundationModels (weak-linked, so
  macOS 14 and 15 still run), and Claude: the user's own key, checked against the Models API (nothing billed)
  and saved to the Keychain, with Remove; the model (`claude-opus-5-5` by default, or `claude-sonnet-5-5`); and
  Use Claude for, disabled until Gmail and the Assistant ship.
- Return in a secret field runs Test. Debug flag `-claudeKey <key>`; `-openSettings ai`.

#### Changed
- One `KeychainSecret` helper now holds the backup password and the Claude key.

### Calendar import and Integrations (Phase 1) — 2026-10-02

#### Added
- **Calendar import** through macOS Calendar (FEATURES §5): any account on the Mac, iCloud, Google or Exchange.
  Events become tasks placed by date, with time, length as the estimate, notes and the meeting link. Syncs at
  launch, on every Calendar change, at day rollover and on Sync now. No duplicates, deleted tasks stay deleted,
  moved events move their task, and a vanished event only unlinks it.
- **Settings ▸ Integrations** (DESIGN_SYSTEM §13.17): Calendar import, Local MCP server and coming-soon cards,
  and the calendar group: calendars by account, the list, the range (1–3 weeks), accepted only, Disconnect.
- The integration card component. `CalendarImport` and `CalendarEvent` in KomodoCore, with tests. Debug flag
  `-sampleCalendar YES`; `-openSettings integrations`.

#### Changed
- FEATURES §5's Google and Microsoft calendar rows become one row for macOS Calendar, the maintainer's call.

### Local MCP server (Phase 1) — 2026-10-02

#### Added
- **`komodo-mcp`**, a helper inside `Komodo.app/Contents/Helpers` that Claude Desktop, Claude Code and Raycast
  launch over stdio (FEATURES §5.1): `list_lists`, `list_tasks`, `create_task`, `update_task`, `complete_task`,
  `complete_subtask`, `log_time` and `start_focus`. Hand-written JSON-RPC, no dependency.
- **Settings ▸ Local MCP server:** the switch (off by default; every tool refuses while it's off), setup for each
  AI app with a code block and Copy, and the tools.
- **Live updates:** the app hears `app.komodo.db-changed` after each write and takes in the new rows without
  resetting the page or the live task.
- **`komodo://start?task=<id>`** makes a task live in Focus mode; `start_focus` uses it.
- `MCPServer`, `KomodoTools` and `JSONValue` in KomodoCore, with tests. A code block component.
  `KOMODO_DATABASE` points the helper at a scratch file; `-openSettings mcp`.

#### Changed
- The app's version moved to the project settings, so the helper and the app always agree.

### Password-protected backups (Phase 1) — 2026-10-02

#### Added
- **Password-protect backups** in Settings ▸ Data & backup (FEATURES §4.21): a sheet sets the password twice,
  and from then on every export and daily backup is an encrypted `.kbak` (AES-GCM, PBKDF2-SHA256 with 600k
  rounds). The password lives in the Keychain, never in the database or a backup. Off, or Delete all data,
  removes it.
- **Restore from a `.kbak`:** Choose file… accepts it, asks for the password, and a wrong one stays on the sheet.
  The safety copy made before a restore is sealed too.
- A daily backup whose password has left the Keychain reports "the password isn't in your Keychain".
- A secure variant of the text field. `BackupCrypto` in KomodoCore, with tests. Debug flags
  `-openBackupPassword YES` and `-backupPassword <pw>`; `-openRestore` takes a `.kbak`.

#### Changed
- Keep last counts `.kbak` files alongside zips.

### End-of-day review and streaks (Phase 1) — 2026-10-02

#### Added
- **End-of-day review** (FEATURES §6.4): the day summary lists NOT FINISHED, Today's open tasks in every list
  whose time has come, each with a **Tomorrow** (default) / **This week** menu. Done, Return or See reports moves
  them all, with one Undo toast. Tomorrow keeps a task's time; This week parks it undated.
- **End Day** in the Focus menu and the command palette opens the summary at any time; the live task stops and
  keeps its time, and a break ends and is recorded. The subtitle then gives the day's span, "first task 9:02 AM ·
  last 5:48 PM".
- **Clean sweep:** with nothing left in Today, the summary shows "Clean sweep. Nothing carried over."
- **"3 in a row today"** on the celebration once three or more tasks in a row finish early or on time.
- **Streaks switch** in Settings ▸ Celebration (FEATURES §4.13); off hides the streak line and the pill.
- `CarryOver`, `DaySummary.result(of:now:)` and `onEstimateRun`, and `DayPlan.firstStart` / `lastFinish` in
  KomodoCore, with tests. Debug flag `-focusState ended`.

#### Changed
- **Streaks count days with a task done**, as FEATURES §4.13 says, instead of days with any focus, and archived
  tasks still count.
- Commits per task: roughly 30–40 (CONTRIBUTING.md).

### Idle CPU and Reports (Phase 1 begins) — 2026-10-01

#### Fixed
- **Idle CPU:** the Board, Focus Panel and floating timer idled near 50% because the timer's digit spring and
  colon beat kept SwiftUI laying out the window every frame. Both now run on Core Animation (`HostedLayer`), and
  an optimized build idles around 3–4%.

#### Added
- **Reports (⌘2, the sidebar, View ▸ Reports, and See reports on the day summary):** a list filter, Today /
  7 days / 30 days / Custom, and four tabs.
  - **Overview:** work days, tasks done, hours and average per task, each with a sparkline and a chip against
    the range before; Daily productivity bars (task hours, breaks, total session) with a hover readout; the most
    productive hour, weekday and month.
  - **Punctuality:** early / on time (±10%) / late with counts and shares, eight weeks of accuracy, and every
    measured task's estimate against its actual time, largest overrun first.
  - **Time spent:** a donut of hours by list and a table whose lists open to show their tasks.
  - **Sessions:** every work session and break a day at a time, with Breaks, Add, Edit, Delete (with Undo) and
    Export PDF / Export CSV.
- **Breaks are recorded** (schema v4, `breaks` table), for the Breaks series and the Sessions log.
- View menu: Board ⌘1 and Reports ⌘2.
- `ReportRange`, `ReportData`, `ReportOverview`, `Productivity`, `Punctuality`, `TimeSpent`, `SessionLog` (with
  CSV) in KomodoCore, with tests. Debug flags `-openReports <tab>` and `-exportSessions <file>`. Sample data
  carries nine months of archived history for Reports.

#### Changed
- Home tracks one page (Board, Trash, Reports) instead of a Trash flag.
- The backup's CSV timestamp and minutes helpers moved onto `CSV`.

### P0 polish: lists, timed tasks, sleep and alerts — 2026-10-01

#### Added
- **Lists:** the sidebar's **+** and File ▸ New List open a sheet with a name (1–60 characters), the eight list
  colors and a one-character badge (a letter or an emoji; empty follows the name's first letter). Right-click a
  list for Rename, Color & Icon, Archive and Delete. Drag lists to reorder them.
- **Archive a list:** it leaves the sidebar, All lists and search with its tasks, stays for reports, with Undo.
- **Delete a list:** type its name to confirm; the list and its tasks go to Trash for 30 days, with Undo. Trash
  shows it as one row with its badge and a violet List chip; Restore puts it back in its place with its tasks,
  and Delete now or the 30th day removes it with everything in it.
- **Timed tasks join the queue on time** (FEATURES §4.6): at their minute they move from Scheduled to the top of
  Up next, and a Focus Panel waiting on the calm card starts them.
- **Away from your Mac:** after sleeping more than five minutes with a task running, a toast asks "You were away
  47min." with Discard to take the gap out of the task's time.
- **File menu:** New Task ⌘⌥T, New List, Export Backup… and Restore from Backup…. **Help menu:** Keyboard
  Shortcuts and Save Diagnostics….
- **Scrolling title** in the floating timer: long titles scroll back and forth in a Core Animation marquee,
  pausing on hover.
- `TaskList` trash and archive dates (schema v3), `AwayTime`, `TaskItem.scheduledStart` and the queue rule in
  `BoardLayout`, with tests. Debug flags `-openListSheet new|edit|delete` and `-deleteList <id>`.

#### Changed
- Sprint end, break over and Time's Up are scheduled as system notifications when their timer starts, so they
  arrive on time while Komodo naps; Pause and Done withdraw them. A running timer also holds off App Nap.
- Save Diagnostics… adds this run's Komodo log and the list count.

### Data & backup, onboarding and celebration GIFs (5g without Google) — 2026-09-29

#### Added
- **Data & backup (Settings):** Export zip with a spinner and a "Backup saved" toast with Show in Finder, an
  automatic daily backup to a chosen folder (default `~/Documents/Komodo Backups`) that keeps the last 7, 14 or
  30, and shows the last backup or why it failed. Restore from backup checks the zip, shows its date, version
  and counts, saves the current data as a before-restore zip, then replaces it. Delete all data waits for DELETE
  to be typed. The palette's Export Backup opens the same Save panel.
- **Zip contents:** `manifest.json`, a `VACUUM INTO` snapshot as `komodo.sqlite`, every table as `data.json`,
  and `tasks.csv` and `sessions.csv` for spreadsheets. No tokens or keys are stored, so none are exported.
- **Onboarding:** a 560 × 520 sheet over Home on a first launch (or after Delete all data): Plan, Focus and Win
  illustrations, notifications with Allow and Not now, and "What do you want to finish today?" with each line's
  parsed estimate as a chip. ⌘Return adds the tasks to Today, then a tip points at Start.
- **Fun GIF:** ten bundled Animated Noto Emoji (CC BY 4.0, credited in About) play in the hero celebration
  when Fun GIF is on; Reduce Motion shows a still frame.
- `Backup` and `CSV` in KomodoCore with tests for the round trip, the refusals and pruning. Debug flags
  `-openRestore <zip>`, `-openDeleteAll`, `-openOnboarding <step>` and `-openStartTip`.

#### Changed
- A restore or Delete all data reloads the board in place: Focus mode ends and every setting is read again.
- Notification permission can be asked for up front instead of at the first alert.

### Settings, menu bar, reminders and Trash — 2026-09-29

#### Added
- **Settings window (⌘,):** General, Focus, Alerts & sounds, Celebration, Shortcuts and About, in a window of
  its own with a searchable sidebar. Everything applies as it changes and is saved. It opens from ⌘, the
  sidebar, the palette, Quick Settings (on Focus) and the menu bar.
  - General: Open at login, Show in Dock (off makes Komodo a menu bar app), the menu bar timer, the week's first
    day, quick task presets and hiding card times.
  - Focus: the panel's screen, side and full-screen floating with a live preview, Pomodoro lengths, the default
    break, scrolling titles and opening note links on start.
  - Alerts & sounds: timed alerts with interval, sound and timer pulse, the reminder sound, and one volume for
    every sound, each with a preview.
  - Celebration: success screen, fun GIF and success sound, with a preview of the moment.
  - Shortcuts: record new keys for the three global shortcuts, reset them, and see when another app holds one.
  - About: version, Save Diagnostics… and the local-only promise.
- **Menu bar item:** the Komodo mark, with the time left while a task or break runs. Its menu has the live task
  with Pause, Done and Skip, then Open Komodo, Settings and Quit.
- **Global shortcuts:** ⌘⇧B shows Komodo, ⌘⇧T swaps the panel and the floating timer, ⌘⇧P finds the timer, from
  any app.
- **Reminders:** each scheduled task with Remind at start notifies at its time, even with Komodo closed, with
  Start now and Snooze 5 min. Time's up notifies with +5 min and Done when the panel isn't showing.
- **Sounds:** a success sound on Done, timed alert nudges, and every sound at the chosen volume.
- **Trash:** deleted tasks wait 30 days with Restore and Delete now, the last three days in amber, and Empty
  Trash. Archive in the card menu hides a task everywhere but reports.
- **Picks up where you left off:** quitting saves the live task, its surface and any break, and relaunching
  brings them back with the task paused. After a crash, the open session ends at the last 30-second heartbeat
  and a toast offers to resume.
- **New day:** midnight, a time zone change or waking from sleep make this week's repeat copies and move the
  Board to the new day.
- `Reminders`, `CrashRecovery` and `Trash` in KomodoCore with tests; a v2 migration adds `deleted_at` and
  `archived_at`. Debug flags `-openSettings`, `-openTrash` and `-databasePath`.

#### Changed
- Delete moves a task to Trash instead of removing it; Undo still brings it straight back.
- The Focus Panel and floating timer open on the chosen display and join full-screen spaces only when Settings
  says so.
- The success screen can be turned off: Done then goes straight to the next task.

### Saving to disk — 2026-09-28

#### Added
- **Everything is saved:** lists, tasks, subtasks, work sessions and Quick Settings live in a SQLite database in
  Application Support and load at launch. Each change is written as it happens, in one transaction.
- The first launch starts with one list, Personal.
- Quitting ends the running session, so a relaunch doesn't count the time Komodo was closed.
- A failed write or an unreadable database shows an error toast instead of losing work silently.
- `AppDatabase` and `BoardChange` in KomodoCore, with round-trip tests; GRDB 7.11.

#### Changed
- The Debug sample day (`-sampleTime artboard`, `-sampleData YES`) stays in memory and never touches the database.

### Workday end — 2026-09-28

#### Added
- The Board's header says whether the plan "fits your day with 1hr 10min to spare" or "runs 40min past your
  workday", against a workday end (6:00 PM by default, in Quick Settings).

#### Changed
- Pomodoros start on; FEATURES §4.18 now says so.

### Pomodoro sprints — 2026-09-28

#### Added
- **Pomodoro sprints:** with Pomodoros on, focused work counts toward the current sprint across tasks, and a
  break starts when it reaches its length. The task keeps its time, and nothing resumes on its own.
- **Sprint display** in Quick Settings: **Task** (default) keeps the estimate on the dial with a "Sprint 2 of 4"
  chip or bars; **Sprint** turns the live card pink and counts the sprint down, on the Board and in the panel.
- **Alerts:** a sprint ending plays a sound and posts "Sprint 2 of 4 done" as its break starts; a break running
  out posts "Break's over" · "Back to …?" with Resume. Sounds follow the Quick Settings switch.
- The floating timer counts the sprint in pink in Sprint display.
- `PomodoroCycle` in KomodoCore; Debug flags `-sprintDisplay sprint` and `-sprintSeconds`.

### Floating timer, celebrations, day summary and command palette — 2026-09-28

#### Added
- **Floating timer:** ⌘⇧T collapses the panel into a 40 pt glass pill above every app and Space, with the
  mini ring, title, time and a progress line. It glows lime while running, greys out paused, turns red with
  inline +5 and Done at Time's Up, and counts a break down in green. Hovering slides in pause, done, skip,
  break, notes and expand; ⌘⇧P ripples it. It drags anywhere and remembers its spot per display.
- **Celebrations:** Done plays a confetti burst with the result against the estimate ("Nailed it. 12min
  early.") and what's next, then starts the next task after 2.5 s, a click or Esc. It fills the live card's
  place in the panel and on the Board, and floats above the pill in timer mode. Reduce Motion shows a still card.
- **Day summary:** the won card adds the streak.
- **Command palette (⌘F):** searches titles, notes and subtasks in every list, grouped by list with the
  match highlighted. Return opens, ⌘Return starts now, no match offers Create task, and `>` lists commands.
- **Focus menu:** ⌘⇧T, ⌘⇧P, ⌘⌥P, ⌘⌥B, ⌘⌥S and ⌘⌥F.
- `TaskSearch` and `CelebrationCopy` in KomodoCore; Debug flags `-openFloatingTimer`, `-openPalette` and
  `-focusState celebrating`.

#### Changed
- The toolbar search opens the palette instead of filtering the Board in place.
- Done waits for the celebration before the next task starts.

#### Not yet
- Fun GIFs and the success sound need their bundled assets; the "in a row" chip needs streak rules (P1).
- ⌘⇧T and ⌘⇧P are app shortcuts until the menu bar app makes them global.
- The title doesn't scroll; Scrolling title arrives with Settings.
- Unfinished tasks in the day summary are the P1 end-of-day review.

### Focus Panel — 2026-09-28

#### Added
- **Focus Panel:** Start docks a 340 pt panel to the screen edge and sets the Home window aside; Home brings it
  back with the task still running.
  - Header: list picker, "Today", a FOCUS pill colored by the timer, Quick Settings, Home and a collapse button.
  - The day at a glance: done of total, estimate left, one segment per task.
  - The live task on a 236 pt dial with the countdown on its face, Flow and links chips, and 54 pt controls.
  - Up next as compact rows with Done and the bolt on hover, ADD TASK (⌘⌥T), Scheduled today and Done.
- **Focus states:** paused in grey with Resume, Time's Up in red with +5 and +15 min, a green break that
  breathes four seconds in and four out and offers Resume once it's over, a calm card with Start early when only
  timed tasks are left, and "You won the day." with tasks, focused time and how the estimates held up.
- **Quick Settings:** Pomodoros with sprint and break lengths, panel side and sounds, applied live.
- **Notes** open in a popover beside the panel.
- `DaySummary` sorts the day's tasks into early, on time (±10%) and late, and `DurationFormat.compact` writes
  `5h 40m`.
- Debug flags `-openFocusPanel`, `-focusState` and `-quietCapture` for background captures.

#### Changed
- A hand-started break uses the break length from Quick Settings, and the Board's Pomodoro label shows it.
- Finishing the queue with timed tasks still to come waits for them instead of winning the day.

#### Fixed
- Scheduled times read "3:00" and "PM" in every locale; a narrow no-break space had left "3 PM" as the period.

#### Not yet
- Pomodoro sprints don't count down or start breaks on their own, and sounds don't play.
- The collapse button waits for the floating timer; the celebration between tasks waits for its milestone.

### Quick add, Schedule popover and Repeat — 2026-09-28

#### Added
- **Schedule popover** from the card's hover row, ⋯ menu and right-click, and from the inspector's Schedule and
  Repeat rows.
  - **Step 1:** Today, Later today, Tomorrow and Next week above a Monday-first month. Today has a lime
    ring, the pick is filled lime, days that already have something scheduled get a blue dot, and past days
    can't be picked.
  - **Step 2:** time, Repeat, a line saying what happens on the day, "Reminder at start time", Remove schedule
    and Save, with an "In 5 days" or "Was: …" badge.
  - Changing a repeat offers **Replace existing tasks**, and ending one offers **Delete existing tasks**.
- **Repeat:** Every day, Every weekday, Weekly on …, Monthly on the …, and a **Custom repeat** sheet (every N
  days, weeks, months or years, weekdays, and an end date), worded as on the canvas: "Every 2 weeks on Tue and
  Thu, no end date."
- **Card ⋯ menu:** Schedule · Subtasks · Notes · Duplicate · Move to list · Archive · Delete, on the hover row
  and on right-click. Backlog cards get Schedule on hover.
- **Card chips:** date, repeat, estimate and "Reminder on" together.
- **Quick add panel (⌘⌥T):**
  - a parsed-estimate chip, 15m / 30m / 1h presets, list and column pickers, and a "Creates …" footer;
  - Return adds, ⌘Return adds and starts, Esc closes.
- **⌘Z and Edit ▸ Undo** now reach the same restore as the Undo toast.
- KomodoCore: `RepeatRule` (kinds, occurrences, summaries), `Recurrence` (this week's copies with fixed IDs
  such as `review@2026-10-02`, never duplicated, and deleted copies stay gone), with 15 tests.
- Debug launch flags `-openSchedule <task id>`, `-openInspector <task id>` and `-openQuickAdd YES`, so these
  surfaces can be captured without driving the pointer.

#### Changed
- `TaskItem` stores a real repeat rule and start day in place of the free-text repeat summary, plus
  `remindsAtStart`.
- **Performance:** the beam, halo, aurora, sheen and ping loop as Core Animation layer animations
  (`LayerEffect`). With `TimelineView` they re-ran the view graph and the Board's layout 60 times a second.

#### Fixed
- Column titles no longer wrap or truncate when the inspector narrows the Board; the subtitle truncates instead.
- Step 2's time field matches the canvas: a clock icon, monospaced digits and a stepper in a Komodo field.
- The Custom repeat sheet's tiles span its width, Ends uses the blue tint, and the labels, spacing and summary
  border follow the canvas.
- The Repeat button in step 2 shows the repeat glyph, the rule and an up-down chevron, and fills its row.
- The card menu shows ⌘D beside Duplicate and ⌘⌫ beside Delete, and both keys work on a focused card. Move
  to list shows each list's letter.

#### Not yet
- Reminders are stored but don't fire until the notifications milestone.
- Archive stays disabled until Trash lands.
- This week's copies of a repeating task are made at launch and after schedule changes. Midnight and wake from
  sleep come later.

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
