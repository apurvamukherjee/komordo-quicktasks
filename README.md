<div align="center">

<img src="Komodo/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="The Komodo app icon: a glowing stopwatch ring with a check inside, on black" width="128">

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
| ⏱️ | **Focus mode** | Work top-down through Today with a live focus dial, Pomodoro sprints, breaks and a docked Focus Panel | 🚧 In development |
| 💊 | **Floating timer** | A 40 pt pill that stays above every app and every Space, and expands on hover | 🚧 In development |
| 🎉 | **Celebrations and day summary** | A burst on every Done, and "You won the day." when the queue is clear | 🚧 In development |
| ✉️ | **Gmail → Calendar** | Finds meetings and deadlines in your email and adds them to Google Calendar. Never sends, deletes or changes email | 🚧 In development |
| 📅 | **Scheduling and repeats** | Schedules, due dates and recurring tasks with deterministic IDs, so nothing duplicates | 🚧 In development |
| 📊 | **Reports** | Estimated vs. actual time, punctuality, time spent and full session history | 🚧 In development |
| ⌨️ | **Keyboard first** | Command palette, quick add from anywhere and a shortcut for every action | 🚧 In development |
| 💾 | **Backup and restore** | One-click zip export and a verified restore, all on your Mac | 🚧 In development |

## The Board

<p align="center"><img src="docs/media/board.png" alt="The Board: sidebar with lists and today's focus, Backlog and This week columns, and Today with the day meter, the live task and the Up next queue" width="100%"></p>

- **Time has temperature.** Backlog is cold violet, This week is warm blue with a seven-day strip, and Today is hot, on its own stage.
- **Plan in seconds.** Type `Write spec 45m` and the estimate is filled in. Drag cards between columns, or use Space, ⌥↑ and ⌥↓.
- **Know when you'll be done.** Every queued task shows when it should start, and the day meter shows when the day ends.
- **One live task.** Start, pause, skip, take a break, or use the bolt on any card to switch. The dial and digits never drift, because time comes from the clock, not from counting ticks.

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
- [ ] Inspector, scheduling, and saving to SQLite
- [ ] Focus Panel, floating timer, celebrations, day summary, command palette
- [ ] Reports, Trash, recurring tasks

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the commit conventions and how this README is kept up to date, and
[CHANGELOG.md](CHANGELOG.md) for everything that has landed so far.
