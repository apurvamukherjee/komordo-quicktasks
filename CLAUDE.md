# Komodo

A native macOS to-do list and focus timer. Swift 6, SwiftUI, macOS 14+, Apple silicon only. Local-only: SQLite (GRDB), no server.

## Start here
- `docs/HANDOFF.md`: where the work stands, the next task, decisions made, gotchas, and open questions. Update it at the end of every milestone.
- `CHANGELOG.md`: everything that has landed. Add to it with every milestone.

## Source of truth
- Behavior: `docs/FEATURES.md`
- Implementation: `docs/ARCHITECTURE.md` (stack, data model, project layout §12, conventions §13, quality gates §14)
- UI: `docs/DESIGN_SYSTEM.md` (tokens §2–5, components §9–10, screens §11–15, Swift tokens §16)
- Start here for design work: `docs/DESIGN_HANDOFF.md`
- Pixels: `design/previews/<Screen>.png` (what it must look like) and `design/screens/<Screen>.dc.html` (exact values: colors, sizes, radii, copy, hover and motion). The HTML files are specs, never code to ship.

If the docs disagree: FEATURES wins on behavior, the canvas PNGs and HTML win on pixels.

## Rules
- Use only the tokens in `DesignSystem/` (`Palette`, `Typography`, `Space`, `Radius`, `Layout`, `Motion`). No hard-coded hex values or sizes in feature views.
- Every card, tile, sheet group, menu and notification gets `.spotlight(tint)` (DESIGN_HANDOFF §4.1). This is Komodo's signature effect. Never skip it.
- The live task always uses `BeamBorder` + `FocusDial`, and timers always use monospaced digits.
- Honor Reduce Motion everywhere (DESIGN_SYSTEM §5).
- Product name is **Komodo**. The only person name used in sample data and copy is **Apurva**.
- Copy comes from DESIGN_SYSTEM §7 and each screen's section. Don't invent new strings when the spec has one.
- Every view file has a `#Preview` with realistic sample data. After building a screen, compare its preview with the matching PNG and fix any differences.
- Follow ARCHITECTURE §13: no force unwraps, typed errors, derived values as computed properties, comments explain why.
- Before saying a task is done: `xcodebuild … build` has zero warnings, `swift format lint --strict` is clean, and `swift test` in KomodoCore passes.

## Commits and README (see CONTRIBUTING.md)
- Commit as the maintainer's own git identity. Never add Co-Authored-By or any tool attribution trailer, and never mention AI in commit messages.
- Conventional Commits with a scope (`feat(effects): …`, `fix(core): …`, `docs(readme): …`), a lowercase imperative summary of at most 72 characters, then a wrapped body that explains why.
- Commit small and often: roughly 20–25 commits per task, each one building on its own. Never push; the maintainer pushes.
- Whenever a feature lands, update `README.md` in the same task: flip its row from 🚧 to ✅, tick the roadmap, and add fresh screenshots and a demo video captured from the running app into `docs/media/` (steps in CONTRIBUTING.md). Never use the canvas PNGs as screenshots.
- The README is a product showcase. It never mentions AI, AI tools or AI features.
- At the end of every milestone, update `CHANGELOG.md` and `docs/HANDOFF.md` (status, next task, gaps, decisions, and the prompt for the next session).
