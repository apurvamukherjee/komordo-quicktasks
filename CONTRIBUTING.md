# Contributing to Komodo

## Quality gates

Every commit must pass these checks:

```bash
xcodegen generate
xcodebuild -scheme Komodo -destination 'platform=macOS,arch=arm64' build   # zero warnings
swift format lint --strict --recursive Komodo KomodoCore
(cd KomodoCore && swift test)
```

## Commits

Komodo follows [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<scope>): <summary>

<body: what changed and why, wrapped at 72 columns>
```

- **Type:** `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`, `style`.
- **Scope:** the area touched, for example `core`, `app`, `design-system`, `effects`, `gallery`, `board`, `focus`,
  `readme`. Leave the scope out only when a change spans the whole repo.
- **Summary:** imperative mood ("add focus dial", not "added"), lowercase, no trailing period, at most
  72 characters including the prefix.
- **Body:** explain *why*, and anything a reviewer won't see in the diff. Reference spec sections where they
  apply (for example `DESIGN_SYSTEM 10.2`).
- **Size:** one logical change per commit, and every commit builds on its own. A typical feature lands as
  roughly 20–25 commits.
- **Authorship:** commits come from the maintainer's own account in their local terminal, with no co-author or
  tool attribution trailers.
- **Publishing:** commits stay local until the maintainer pushes at the end of a task.

## Keeping the README current

The README is Komodo's front page, so it must always show the product as it is today.

1. **Whenever a feature lands**, update `README.md` in the same task:
   - Move the feature's row in **Features** from 🚧 to ✅ and tick it off in **Roadmap**.
   - Add or refresh screenshots in `docs/media/`, captured from the running app.
   - Re-record the demo video when the feature moves or animates.
2. **Screenshots** come from a Debug build, captured with the window's own bounds:
   ```bash
   open Komodo.app --args -design-gallery -galleryScrollTo <section>
   screencapture -x -o -l <window-id> docs/media/<name>.png
   ```
   For the Board, launch with `-sampleTime artboard -homeWindowSize 1440x820 -ApplePersistenceIgnoreState YES` so
   the sample day and window size match every time. Crop the title bar where it adds nothing, and scale to
   1600 px wide. Move the pointer off the window before recording.
3. **Video:** record with `screencapture -v -V 8 -R <x,y,w,h> motion.mov`, then export a GIF for inline playback
   and an MP4 for full quality:
   ```bash
   ffmpeg -i motion.mov -vf "fps=20,scale=1200:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse" docs/media/motion.gif
   ffmpeg -i motion.mov -vf "scale=1440:-2" -c:v libx264 -pix_fmt yuv420p -crf 23 -movflags +faststart -an docs/media/motion.mp4
   ```
4. **Only real captures.** Never pass off the design canvas PNGs in `design/previews/` as app screenshots.
5. **Keep it about the product.** The README describes Komodo and how to build it. It never credits the tools
   used to write it.
6. Commit the README update as `docs(readme): …`.
