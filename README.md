<div align="center">

<img src="docs/media/app-icon.png" alt="The Komodo app icon: a glowing stopwatch ring with a check inside, on black" width="128">

# Komodo

**A to-do list that collapses into a focus timer.**
Plan your day, press Start, and let the current task stay with you, above every app, until it's done.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Apple silicon](https://img.shields.io/badge/Apple%20silicon-arm64-B5F23D?style=flat-square&labelColor=0A0A0C)
![Swift 6](https://img.shields.io/badge/Swift-6-2DD9C4?style=flat-square&logo=swift&logoColor=white&labelColor=0A0A0C)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-4D8DFF?style=flat-square&labelColor=0A0A0C)
![Local only](https://img.shields.io/badge/data-on%20your%20Mac-35D483?style=flat-square&labelColor=0A0A0C)

<br>

<img src="docs/media/board.gif" alt="The Komodo Board: Backlog, This week and Today on its glowing stage, with the live task's focus dial counting down" width="100%">

<sub>Recorded from the running app · <a href="docs/media/board.mp4">watch in full quality</a></sub>

</div>

---

## Why Komodo

Most to-do apps stop at the list. Komodo keeps going: the list becomes the timer.

> **Plan the day → Start → one task at a time → finish and review.**

- **One live task, always visible.** The task you're on floats above every app with its countdown, so you never lose the thread.
- **Estimates you can trust.** Every task has an estimate and every session is timed. Reports show where your day actually went.
- **Delight at the finish line, silence during the work.** Celebrations play on *Done*, never mid-task.
- **Your data stays yours.** No account, no server. Everything lives in SQLite on your Mac and exports as a zip at any time.

## Features

| | Feature | What it does | Status |
| :-: | --- | --- | :-: |
| 🎨 | **Obsidian Spectrum design system** | True-black canvas, cursor spotlight on every surface, border beam, focus dial and odometer digits, all honoring Reduce Motion | ✅ Available |
| 🧩 | **Component library** | Buttons, chips, fields, task and queue cards, the live task card with its control bar, break card, day meter, toasts and banners | ✅ Available |
| 🗂️ | **Board with time temperature** | Backlog (cold), This week (warm) and Today (hot) on its own glowing stage. Drag and drop, quick add that reads estimates like `Write spec 45m`, a live task with projected start times, and Undo | ✅ Available · saving to disk is next |
| 🔎 | **Task inspector** | Everything about a task in one side panel: list, estimate, time taken, schedule, repeat, subtasks, rich-text notes and every focus session | ✅ Available |
| ⏱️ | **Focus mode** | Work top-down through Today in a Focus Panel docked to the screen edge: a live focus dial, breaks that breathe with you, and the queue a click away | ✅ Available |
| 💊 | **Floating timer** | A 40 pt pill that stays above every app and every Space, drags anywhere, and expands on hover | ✅ Available |
| 🎉 | **Celebrations and day summary** | A burst on every Done, and "You won the day." when the queue is clear | ✅ Available · fun GIFs and sounds are next |
| ✉️ | **Gmail → Calendar** | Finds meetings and deadlines in your email and adds them to Google Calendar. Never sends, deletes or changes email | 🚧 In development |
| 📅 | **Scheduling and repeats** | Pick a day, a time and a repeat in two steps. Recurring tasks get stable IDs, so nothing duplicates and a deleted copy stays gone | ✅ Available · reminders arrive with notifications |
| 📊 | **Reports** | Estimated vs. actual time, punctuality, time spent and full session history | 🚧 In development |
| ⌨️ | **Keyboard first** | Command palette, quick add from anywhere and a shortcut for every action | ✅ Available · global shortcuts arrive with the menu bar |
| 💾 | **Backup and restore** | One-click zip export and a verified restore, all on your Mac | 🚧 In development |

## The Board

<p align="center"><img src="docs/media/board.png" alt="The Board: sidebar with lists and today's focus, Backlog and This week columns, and Today with the day meter, the live task and the Up next queue" width="100%"></p>

- **Time has temperature.** Backlog is cold violet, This week is warm blue with a seven-day strip, and Today is hot, on its own stage.
- **Plan in seconds.** Type `Write spec 45m` and the estimate is filled in. Drag cards between columns, or use Space, ⌥↑ and ⌥↓.
- **Know when you'll be done.** Every queued task shows when it should start, and the day meter shows when the day ends.
- **One live task.** Start, pause, skip, take a break, or use the bolt on any card to switch. The dial and digits never drift, because time comes from the clock, not from counting ticks.

## The inspector

<p align="center"><img src="docs/media/inspector.png" alt="The Board with the inspector open on the right: list, estimate, time taken, schedule and repeat, a subtask checklist, the notes editor and the session history" width="100%"></p>

- **Click any card** to see and edit everything about it. ⌘↑ and ⌘↓ step through tasks, and Esc closes.
- **Notes with real formatting.** Bold, lists and links, and the links open by themselves when the task goes live.
- **Honest time.** Every focus session is recorded, and time taken stays locked while the timer runs.

## Scheduling and quick add

<table>
  <tr>
    <td width="50%"><img src="docs/media/schedule-date.png" alt="Schedule popover, step one: Today, Later today, Tomorrow and Next week, above a Monday-first month calendar"></td>
    <td width="50%"><img src="docs/media/schedule-details.png" alt="Schedule popover, step two: time, repeat rule, what will happen on the day, and the reminder switch"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="docs/media/quick-add.png" alt="Quick add panel reading an estimate out of Write launch email 45m, with list and column pickers"></td>
  </tr>
</table>

- **Two steps to schedule.** Pick a day, then add a time and a repeat. Komodo tells you exactly what will happen on that day.
- **Repeats that behave.** Every day, weekdays, weekly, monthly, or a custom rule like "Every 2 weeks on Tue and Thu". Change a rule and choose whether this week's copies are replaced.
- **Quick add with ⌘⌥T.** Type `Write launch email 45m`, pick the list and column, and press Return, or ⌘Return to start it straight away.

## Focus mode

<table>
  <tr>
    <td width="30%"><img src="docs/media/focus-panel.png" alt="The Focus Panel: day progress, the live task on a large glowing dial with Break, Notes, Pause, Skip and Done, then Up next, Scheduled today and Done"></td>
    <td width="70%"><img src="docs/media/focus-states.png" alt="Focus Panel states: paused in grey, Time's Up in red with +5 and +15 min, a green breathing break, a calm card when only timed tasks are left, and You won the day"></td>
  </tr>
</table>

- **One press to focus.** Start docks the Focus Panel to the edge of your screen and steps the Board aside. Home brings it back, with the task still running.
- **Every state at a glance.** The dial glows lime while you work, turns grey when paused and red with a shake when the estimate runs out, with +5 and +15 min one click away.
- **Breaks that breathe.** A green circle breathes four seconds in and four out while the break counts down. Nothing restarts until you say so.
- **The queue stays yours.** Add a task, finish one, or bolt any task live from the panel. When only timed tasks are left it waits calmly, and when the queue is clear you've won the day.
- **Pomodoro sprints, your way.** Work counts toward 25-minute sprints and a break starts when one ends. Keep the task's estimate as the big number with the sprint beside it, or switch Sprint display to count the sprint itself in pink.
- **Quick Settings.** Sprint and break lengths, sprint display, the panel's side and sounds, from the gear.

<p align="center"><img src="docs/media/focus-sprints.png" alt="The Focus Panel in Task display, counting the estimate with a Sprint 1 of 4 chip, and in Sprint display, counting the sprint down in pink" width="70%"></p>

## Floating timer and celebrations

<table>
  <tr>
    <td width="58%"><img src="docs/media/floating-timer.png" alt="The floating timer pill running with a lime ring, paused in grey, at Time's Up in red with +5 and Done, and on a green break"></td>
    <td width="42%"><img src="docs/media/celebration.png" alt="The Focus Panel celebrating: a lime check, Nailed it. 9min early., and what's up next"></td>
  </tr>
</table>

- **Out of the way, never out of sight.** ⌘⇧T collapses the panel into a 40 pt pill that floats above every app and Space. Drag it anywhere; it remembers its spot on each display.
- **Hover for controls.** Pause, Done, Skip, Break, Notes and back to the panel slide in on a spring. At Time's Up it turns red with +5 and Done inline, and ⌘⇧P ripples it so you can find it.
- **A moment for every Done.** A confetti burst and a word on how you did against the estimate: "Nailed it. 12min early." The next task starts when it's over, never mid-celebration.

## Command palette

<p align="center"><img src="docs/media/palette.png" alt="The command palette over the Board, searching design rev with the match highlighted in lime" width="100%"></p>

- **⌘F finds anything.** Titles, notes and subtasks across every list, Done included, grouped by list with the match highlighted.
- **Return opens, ⌘Return starts.** No match? Create the task right there.
- **Type > for commands.** New Task, Start and more, from the keyboard.

## The design system

Komodo's look is **Obsidian Spectrum**: black is the canvas, color is earned, light follows your cursor, and time has a temperature. Every token, effect and component is built in SwiftUI and can be inspected live in the debug gallery.

<table>
  <tr>
    <td colspan="2"><img src="docs/media/overview.png" alt="Design system gallery: header, principles, neutral palette and text steps"></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/media/colors.png" alt="Spectrum accents, list badges and the time-temperature columns"></td>
    <td width="50%"><img src="docs/media/type-and-spotlight.png" alt="Typography scale, radius and glow tokens, and the cursor spotlight"></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/media/motion-and-controls.png" alt="Focus dial, border beam, sheen and Time's Up motion, plus buttons and controls"></td>
    <td width="50%"><img src="docs/media/task-cards.png" alt="Task card states: default, focused, dragging, done and overdue"></td>
  </tr>
</table>

<p align="center"><img src="docs/media/components.png" alt="Components: live task card running and at Time's Up, day meter, break card, queue card, section rows, banners, toasts and a popover" width="100%"></p>

<p align="center"><img src="docs/media/motion.gif" alt="Signature motion: focus dial, border beam, primary sheen and the Time's Up shake" width="100%"></p>

**Signature effects**

- **Cursor spotlight.** Every card, tile, menu and notification lights up where the pointer is: a tinted glow plus a 1 pt border light.
- **Border beam.** A conic light travels around the live task every 4.5 s while its glow breathes. It turns grey when paused, red at Time's Up and green on a break.
- **Focus dial.** A 60-tick radar sweep, a progress arc with a comet head and a rotating halo, all driven by wall-clock time so it never drifts.
- **Odometer digits.** Timer digits roll like a mechanical counter, in tabular figures that never jitter.

## Built with

| Layer | Choice |
| --- | --- |
| App | Swift 6 with complete strict concurrency, SwiftUI, AppKit panels |
| Platform | macOS 14 Sonoma or later, Apple silicon only |
| Storage | SQLite on your Mac, no server |
| Core logic | `KomodoCore` Swift package, tested with Swift Testing |
| Project | Generated with XcodeGen, linted with swift-format |

## Getting started

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme Komodo -destination 'platform=macOS,arch=arm64' build
(cd KomodoCore && swift test)
```

In a Debug build, **Debug → Design System Gallery** (⌥⇧⌘G) opens the gallery. You can also launch straight into it at any section (`principles`, `neutrals`, `accents`, `temperature`, `type`, `spotlight`, `motion`, `controls`, `cards`, `components`):

```bash
open Komodo.app --args -design-gallery -galleryScrollTo motion
```

The Board runs on sample data for now. To see it exactly as designed (Saturday, Sep 26 at 2:14 PM), launch with:

```bash
open Komodo.app --args -sampleTime artboard
```

## Roadmap

- [x] Design tokens and asset-catalog color sets
- [x] Signature effects: spotlight, border beam, focus dial, odometer digits
- [x] Design system gallery
- [x] Components: buttons, chips, fields, task card, live task card, control bar, day meter, toasts, banners
- [ ] Menu bar app, Settings, Gmail → Calendar, backup
- [x] Board: columns, drag and drop, quick add with estimates, the live task and its queue (in-memory for now)
- [x] Inspector, scheduling and repeats, and the Quick add panel
- [ ] Saving to SQLite
- [x] Focus Panel and its states
- [x] Floating timer, celebrations, day summary, command palette
- [ ] Reports and Trash

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the commit conventions and how this README is kept up to date, and
[CHANGELOG.md](CHANGELOG.md) for everything that has landed so far.
