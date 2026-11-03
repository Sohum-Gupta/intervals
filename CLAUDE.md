# Intervals

A native macOS menu bar Pomodoro timer for one user. No paywall, no sync, no network, no extra devices.

## Source of truth

`SPEC.md` at the repo root. Read it fully before any work. The Features table is the whole scope; the Decisions table is settled; the Build order is the sequence. Do not add features outside the table, and do not reopen decisions.

## Stack

- Swift 6, SwiftUI, SwiftData, Swift Charts, UserNotifications. No third-party packages.
- Deployment target: the macOS version this Mac is running (`sw_vers -productVersion`).
- Menu-bar-only app (`LSUIElement = YES`), `MenuBarExtra` with `.window` style.
- Bundle id `com.sohum.intervals`.

## Commands

The project file is generated: edit `project.yml`, never `Intervals.xcodeproj` by hand. Xcode is not the active developer directory on this Mac, so the Makefile pins `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

- Regenerate project: `make project` (runs `xcodegen generate`)
- Build: `make build` (`xcodebuild -scheme Intervals -configuration Debug -derivedDataPath build/DerivedData build`)
- Test: `make test` (`xcodebuild -scheme Intervals test`, same derived data path)
- Run: `make run` — kills any running copy and opens `build/DerivedData/Build/Products/Debug/Intervals.app`. The app lives in the menu bar, not the Dock.

Treat warnings as failures (the project sets `SWIFT_TREAT_WARNINGS_AS_ERRORS`). Run the tests before every commit.

## Layout

```
Intervals/
  App/        IntervalsApp.swift, AppDelegate.swift
  Engine/     TimerEngine.swift, TimerState.swift, Clock.swift
  Models/     Session.swift, Tag.swift, Phase.swift, Exporter.swift
  Views/      MenuBar/, History/, Stats/, Settings/
  Resources/  Sounds/*.aiff, Assets.xcassets
IntervalsTests/
```

## Rules of the road

- The timer engine is a pure state machine on wall-clock timestamps (`endsAt - now`). Never trust a running counter. The engine has no SwiftUI imports and takes an injected clock so tests can jump time.
- Work one milestone at a time, in the order in `SPEC.md`. Finish, test, try it by hand, commit (`Milestone N: <name>`), push, then move on.
- Polish is part of every milestone: native controls, system fonts, animated state changes, no placeholder UI.
- A question the spec does not answer gets the simplest reasonable choice, noted in the commit message. Do not stop to ask unless the choice is irreversible.
- Keep this file and `SPEC.md` current when a decision changes.

## Engine notes (choices the spec left open)

- The engine does not settle deadlines in `init`. The app attaches `sessionSink` and `transitionHandler`, then calls `refresh()`, so an interval that ended while the app was closed is recorded instead of lost.
- `TimerSnapshot` carries `plannedSeconds`, set when an interval starts, so pause/resume cannot change it.
- Auto-start after a long sleep: work auto-starts at the break's planned end only if that work would still be in progress now. Otherwise the break stays in overtime; the engine never invents sessions nobody was present for.
- Fresh day: a break in overtime that crosses local midnight is written up to midnight and the engine goes `idle(.work)` with the cycle zeroed. Running work and paused timers are left alone.
- Pause is a no-op during break overtime; the primary button reads Start there.
- `completedWorkInCycle` returns to 0 the moment a long break starts.
- Reset keeps the current title and tag.
- The clock protocol is `WallClock` (`SystemClock`, `ManualClock`) because `Clock` collides with the standard library.
- Sandboxed preferences live in `~/Library/Containers/com.sohum.intervals/Data/Library/Preferences/`; plain `defaults read com.sohum.intervals` shows a different, empty domain.

