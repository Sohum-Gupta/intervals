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

## App layer notes (Milestone 2)

- `AppController.shared` owns the engine, `AppSettings`, `SoundPlayer` and `Notifier`. Views get it passed in; nothing else is global.
- Sounds are synthesised by `Tools/make_sounds.py` (plain Python plus `afconvert`). Re-run it to regenerate `Resources/Sounds/*.aiff`; do not hand-edit the files.
- The sound and notification fire on automatic transitions only: focus complete, break over (once, via the engine's `breakEnded` event), and auto-started focus. Pressing Start, Skip or Reset is silent.
- The ticking loop uses the alert volume.
- The footer gear opens Settings on click and holds a small menu (Settings…, Quit Intervals) so ⌘Q has a home in the popover.
- Space toggles the timer only when the title field is not focused; Return blurs the field.
- **Notifications need a real signing identity and a manual switch on this Mac.** The project signs with the Apple Development certificate for team `SQH2L2PNM9` (set in `project.yml`). Ad-hoc builds get "Notifications are not allowed for this application". Even signed, this Mac never showed the permission prompt and the daemon reported the app as Denied; the fix was turning Intervals on by hand in System Settings > Notifications (done 2026-11-02). The authorization request logs its result under subsystem `com.sohum.intervals`, category `notifications`.
- Hand-testing: Screen Recording and Accessibility are granted to VS Code. `screencapture -R x,y,w,h` takes points (screen is 1512 pt wide); System Events can click `button N of group 1 of window 1` in the popover; `tell application "Intervals" to activate` brings the Settings window forward. zsh has a builtin `log`, so use `/usr/bin/log show` and `/usr/bin/log stream` for the unified log.

## Data notes (Milestone 3)

- `SessionStore` owns the `ModelContainer` and every write. Views read with `@Query`; the engine's `sessionSink` and the Settings tabs write through the store. It bumps `changeCount` after each write so views that fetch by hand (the popover footer) can refresh.
- `Session.phase` is stored as `phaseRaw: String` so `#Predicate` can filter on it.
- Tag names are unique ignoring case and whitespace; `addTag`/`rename` refuse duplicates instead of renaming around them. New tags take the least-used palette colour. There are no seeded tags.
- Tag colours in menus must be drawn as non-template `NSImage`s (`TagColor.dot`); SF Symbols tinted with `foregroundStyle` come out white inside `Menu`.
- The store file is `~/Library/Containers/com.sohum.intervals/Data/Library/Application Support/Intervals/Intervals.store`; `sqlite3 "file:...?mode=ro"` on it is a handy check (`ZSESSION`, `ZTAG`).
- If the on-disk store fails to open, the app falls back to an in-memory store so the timer still works; the file is left untouched.

