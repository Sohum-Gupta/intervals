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

- Build: `xcodebuild -scheme Intervals -configuration Debug build`
- Test: `xcodebuild -scheme Intervals test`
- Run: `open build/Debug/Intervals.app` after a build, or `xcodebuild ... && open` — the app lives in the menu bar, not the Dock.

Treat warnings as failures. Run the tests before every commit.

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
