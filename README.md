# komordo-quicktasks

Komodo is a native macOS to-do list and focus timer: Swift 6, SwiftUI, macOS 14+, Apple silicon, local-only.
See `CLAUDE.md` and `docs/` for the specs.

## Building

```bash
xcodegen generate
xcodebuild -scheme Komodo -destination 'platform=macOS,arch=arm64' build
swift format lint --strict --recursive Komodo KomodoCore
(cd KomodoCore && swift test)
```

## Commit conventions

- Commits are made from the maintainer's own account in their local terminal. No co-author or tool
  attribution trailers.
- Commit small and often: a typical task lands as roughly 20–25 commits, each one a single logical change
  that builds on its own.
- Messages follow the usual Git norms:
  - Subject in the imperative mood ("Add focus dial", not "Added"), capitalized, no trailing period,
    72 characters at most.
  - A blank line, then a body wrapped at 72 characters that explains *why* the change was made and
    anything a reviewer would not see from the diff.
- Commits stay local; the maintainer pushes when a task is finished.
