# Intervals — Spec

A native macOS menu bar Pomodoro timer. Author: Sohum. As of 2026-11-02. This file is the source of truth for the implementing session; the living copy is a Claude Doc but this Markdown is what lives in the repo.

## Goals and non-goals

Intervals is a native macOS menu bar Pomodoro timer for one person, with no paywall, no nags, no account and no network. It replaces Be Focused and Flow for daily use on one Mac.

Goals, in order: the timer always works and never loses state; every session is recorded locally; history can be tagged, corrected and exported; and it looks and feels as polished as a paid app, so using it is a pleasure rather than a chore. Everything else is a non-goal.

Explicitly out of scope, so nothing is designed for it: iCloud or any sync, iPhone, iPad or Watch versions, app or website blocking, a task manager, global hotkeys, Shortcuts, Calendar or Health integration, streaks or gamification, notarization or App Store distribution, multiple users or profiles, localization.

## Features

Eleven features, all v1. Nothing here is optional and nothing is deferred to a later tier.

| # | Feature | Detail |
| --- | --- | --- |
| F1 | Configurable intervals | Work, short break, long break lengths (1–120 min each) and sessions-before-long-break (1–10). Defaults 25 / 5 / 15 / 4. |
| F2 | Menu bar countdown | Remaining time shown as text in the menu bar item (`24:59`), with a glyph that distinguishes work from break and a paused state. |
| F3 | Timer controls | Start, pause, resume, skip, reset. A setting to auto-start the next interval, default off. |
| F4 | End-of-interval alerts | macOS user notification at every transition; a chosen sound from a built-in set (or none); volume slider. Optional ticking during work, default off. |
| F5 | Timer survives restart and sleep | State is derived from stored timestamps, not a running counter. Quitting, crashing or sleeping the Mac never loses the current interval. |
| F6 | Session history | Every completed or skipped work interval is stored locally with start, end, planned length, tag and whether it was completed. A break is stored as the real gap between one work session's end and the next one's start, so idle time between sessions counts as break time. Breaks are hidden in lists by default but always tracked. |
| F7 | Titles and tags | A session can have a free-text title and one tag. Tags are user-created with a name and colour. The current tag is picked from the popover before or during a session. |
| F8 | Basic stats | Today, this week, this month: completed sessions and total focus minutes, overall and per tag. A simple bar per day for the last 14 days. |
| F9 | Manual session edits | Add a session by hand, edit start, end, title or tag of any session, delete a session. |
| F10 | Export | Export all sessions as CSV or JSON to a file the user picks. No import in v1. |
| F11 | Appearance | Light, dark or follow system. One accent colour used for the work state. |

## UI

Three surfaces: the menu bar item, a popover under it, and one window for history, stats and settings. No Dock icon, no main window. Polish is a requirement, not a finish step: native SwiftUI controls, system typography, animated transitions, and keyboard shortcuts in the popover.

### Menu bar item

A status item showing a small SF Symbol and the countdown as monospaced-digit text, e.g. `● 24:59` during work, `○ 04:30` on a break, `‖ 12:10` when paused, and just the symbol before the first session of the day. Once a break's planned length has passed, the item counts up instead (○ +03:12) until the next work session starts, so the gap between sessions is always visible. The symbol is tinted with the accent colour during work. Clicking opens the popover. The time is always shown; there is no icon-only mode.

### Popover

A compact card roughly 300 × 380 pt, rendered with the system material background and rounded corners.

- Top: a large ring progress indicator that empties as the interval runs, with the remaining time in the centre in a large rounded font and the phase name ("Focus", "Short break", "Long break") above it. The ring animates smoothly rather than ticking once a second.
- Under the ring: a session-dot row showing progress toward the long break (e.g. ● ● ○ ○).
- Title field and tag picker: a single-line text field with placeholder "What are you working on?" and a tag menu showing the tag's colour dot. Both editable before and during a session.
- Controls: one primary button (Start / Pause / Resume) and two secondary icon buttons (Skip, Reset). Space toggles start/pause, ⌘. resets, ⌘→ skips.
- Footer: today's total ("3 sessions · 1h 15m"), a button that opens the History window, and a gear that opens Settings. ⌘Q quits.
- Transitions between work and break crossfade the colour and ring; the phase change plays the chosen sound once.

### History & Stats window

A single resizable window, about 760 × 520 pt, with a sidebar of three items: Today, History, Stats.

- Today: list of today's sessions, newest first, each row showing time range, duration, title and tag chip. Inline edit on double-click. Breaks hidden unless a toggle shows them.
- History: the same list grouped by day, with a date range picker and a tag filter. Toolbar buttons for "Add session" and "Export…". Swipe or ⌫ deletes with an undo toast.
- Stats: three summary tiles (Today, This week, This month) with sessions and focus minutes, a 14-day bar chart built with Swift Charts, and a per-tag breakdown table for the selected range.

### Settings

A standard macOS Settings window (⌘,) with tabs: Timer (lengths, sessions before long break, auto-start), Sounds (alert sound, volume, ticking), Appearance (light / dark / system), Tags (add, rename, recolour, delete), Data (export, show database location).

## Timer engine

The engine is a pure state machine driven by wall-clock timestamps. Remaining time is always `endsAt - now`; no running counter is ever trusted, which is what makes F5 free.

State is one value, persisted to UserDefaults on every change:

```swift
enum Phase { case work, shortBreak, longBreak }

enum TimerState {
    case idle(nextPhase: Phase)
    case running(phase: Phase, startedAt: Date, endsAt: Date)
    case paused(phase: Phase, startedAt: Date, remaining: TimeInterval)
}

struct TimerSnapshot: Codable {
    var state: TimerState
    var completedWorkInCycle: Int   // 0..<sessionsBeforeLongBreak
    var currentTitle: String
    var currentTagID: UUID?
}
```

Rules:

- Start from idle: `running(phase, now, now + length(phase))`.
- Pause: store `remaining = endsAt - now`. Resume: `endsAt = now + remaining`. A pause never expires; a paused timer waits until you come back.
- Complete (`now >= endsAt`): if phase is work, write a Session row with `completed = true` and bump `completedWorkInCycle`; pick the next phase (long break when the cycle count reaches the setting, else short break; after any break, work). Post the notification and play the sound.
- Breaks always start by themselves when work ends. Auto-start only governs whether work begins by itself when the planned break ends.
- Break overtime: when a break's `endsAt` passes and auto-start is off, the engine stays in the break phase and counts up past zero instead of going idle. The next work session starts when you press Start. At that moment one break Session is written spanning the previous work's `endedAt` to now, whatever the planned break length was.
- Skip: if phase is work and at least 60 s elapsed, write the Session with `completed = false`; otherwise write nothing. A skipped work session still advances the long-break cycle. Skipping a break starts work immediately and writes the break Session as above.
- Reset: discard the current interval, write nothing, go to `idle(.work)` and zero the cycle count. Idle is reachable only by reset or on a fresh day.
- Tick: a 1 Hz timer redraws the UI and checks for completion. It is a display concern only. On wake from sleep (`NSWorkspace.didWakeNotification`) and on launch, the engine re-evaluates immediately: if `endsAt` has passed, complete as if it fired at `endsAt`, not at `now`, so the recorded session has the right end time.
- Launch: load the snapshot; if it was `running`, the ring resumes from the correct remaining (or overtime) value with no visible jump.

The drawing below shows the transitions; paused and idle are the only states with no deadline.

Transitions, in words (the original doc has this as a diagram):

```
idle(next) --start--> running(endsAt) <--pause/resume--> paused(remaining)
running --now >= endsAt, or skip--> complete/skip: write Session, pick next phase
paused  --reset or skip-----------> complete/skip (reset writes nothing)
complete/skip --reset only--> idle(.work)
complete/skip --> running(next): a break starts itself; work waits for Start
                  unless auto-start is on. A break past endsAt keeps running
                  in overtime (counting up) until Start.
```

## Data model

Two SwiftData models in a single on-disk store under `~/Library/Application Support/Intervals/`. Settings and the live timer snapshot live in UserDefaults, not the database, because they are tiny and must load before the store does.

```swift
@Model final class Session {
    var id: UUID
    var phase: Phase            // work, shortBreak, longBreak (stored as String)
    var startedAt: Date
    var endedAt: Date
    var plannedSeconds: Int     // the interval length when it started
    var completed: Bool         // false = skipped early
    var title: String
    var tag: Tag?               // nullify on tag delete
    var isManual: Bool          // true when added or edited by hand
    var createdAt: Date
}

@Model final class Tag {
    var id: UUID
    var name: String            // unique, case-insensitive
    var colorHex: String
    var sortOrder: Int
    @Relationship(inverse: \Session.tag) var sessions: [Session]
}
```

Derived, never stored: `durationSeconds = endedAt - startedAt`. Stats query `Session` filtered by `phase == .work` and a date range; SwiftData predicates on `startedAt` are enough at a single user's scale (a few thousand rows a year).

Settings keys in UserDefaults: `workMinutes`, `shortBreakMinutes`, `longBreakMinutes`, `sessionsBeforeLongBreak`, `autoStartNext`, `alertSound`, `alertVolume`, `tickingEnabled`, `appearance`, plus the `TimerSnapshot` from the engine section encoded as JSON.

Deleting a tag sets `tag = nil` on its sessions rather than deleting them. Deleting a session is a hard delete after the undo toast expires.

## Stats and export

Stats are computed on demand from work sessions only; nothing is pre-aggregated. A "day" starts at local midnight, and a session belongs to the day it started.

| Figure | Definition | Shown in |
| --- | --- | --- |
| Sessions | Count of work sessions with `completed == true` | Tiles, popover footer, per-tag table |
| Focus time | Sum of `endedAt - startedAt` over all work sessions, completed or skipped | Tiles, popover footer, per-tag table, 14-day chart |
| Skipped | Count of work sessions with `completed == false` | Per-tag table only |
| Per day | Focus minutes per calendar day for the last 14 days, zero-filled | 14-day bar chart |

Export writes every session (breaks included) to a location chosen in a save panel. Both formats carry the same columns; timestamps are ISO 8601 with the local offset.

```csv
id,phase,started_at,ended_at,planned_seconds,duration_seconds,completed,title,tag,is_manual
4A1F...,work,2026-11-02T09:00:00-08:00,2026-11-02T09:25:00-08:00,1500,1500,true,Spec review,Deep work,false
```

The JSON export is an array of objects with the same keys plus the tag's colour, so the file is enough to rebuild the tag list later if import is ever added.

## Project structure and tech choices

One Xcode app target, Swift 6, SwiftUI, the current macOS release as the deployment target (whatever your Mac reports when the build starts; you plan to stay updated), so `MenuBarExtra`, SwiftData and Swift Charts are all available. No third-party packages. Sandboxed, with only the user-selected-file entitlement for export. `LSUIElement = YES` so there is no Dock icon.

| Concern | Choice | Why |
| --- | --- | --- |
| Menu bar item | `MenuBarExtra` with `.menuBarExtraStyle(.window)` | Gives the popover for free; the label is a `Text` + `Image(systemName:)` that updates on each tick |
| Timer engine | Plain `@Observable` class, no SwiftUI inside | Testable in isolation with injected clock |
| Storage | SwiftData `ModelContainer` | Already chosen; queries via `@Query` in views, `ModelContext` in the engine |
| Settings | `@AppStorage` | Trivial, survives without the database |
| Notifications | `UserNotifications` | Standard; request permission on first run |
| Sounds | `NSSound` for bundled `.aiff` files, `AVAudioPlayer` for the ticking loop | Simple, no AVFoundation session work needed |
| Charts | Swift Charts | Native, matches system appearance |
| Windows | `Window` scene for History, `Settings` scene for preferences | Standard macOS behaviour, ⌘, works |

File layout:

```
Intervals/
  App/            IntervalsApp.swift (scenes), AppDelegate.swift (wake, notifications)
  Engine/         TimerEngine.swift, TimerState.swift, Clock.swift
  Models/         Session.swift, Tag.swift, Phase.swift, Exporter.swift
  Views/
    MenuBar/      MenuBarLabel.swift, PopoverView.swift, RingView.swift
    History/      HistoryWindow.swift, SessionList.swift, SessionEditor.swift
    Stats/        StatsView.swift, FocusChart.swift
    Settings/     SettingsView.swift + one view per tab
  Resources/      Sounds/*.aiff, Assets.xcassets
IntervalsTests/  TimerEngineTests.swift, StatsTests.swift, ExporterTests.swift
```

## Build order

Six milestones, each one usable on its own. The engine comes first and gets tests before any UI exists, because every later milestone trusts it.

1. Engine and persistence. `TimerEngine` with an injectable clock, `TimerSnapshot` saved to UserDefaults, unit tests for start, pause, resume, skip, reset, completion, long-break cycling, and recovery after a simulated sleep. Covers F1, F3, F5.
2. Menu bar and popover. `MenuBarExtra` label with the countdown, the popover with ring, controls and keyboard shortcuts, notifications and sounds. Covers F2, F4. The app is a working timer at the end of this step.
3. Sessions and tags. SwiftData store, `Session` written on completion and skip, `Tag` model, title field and tag picker in the popover. Covers F6, F7.
4. History window. Today and History lists, inline edit, add and delete with undo. Covers F9.
5. Stats and export. Tiles, 14-day chart, per-tag table, CSV and JSON export. Covers F8, F10.
6. Polish pass. Appearance setting, animations and transitions tuned, empty states, first-run notification prompt, app icon, a pass through every screen against the UI section. Covers F11 and the polish goal.

## Decisions

All open questions are settled.

| Question | Decision |
| --- | --- |
| App name | **Intervals** — plain and descriptive; no tagline needed. Bundle id `com.sohum.intervals`. |
| Skipped work counts toward the long break | Yes. |
| Long pauses | Never expire; the timer waits. |
| Gap between sessions | Every break runs a visible timer, counts up past its planned length, and the full gap is recorded as a break Session. |
| Menu bar countdown | Always shown, in every phase. |
| Bundled sounds | Four short alerts (chime, bell, soft click, marimba) plus the system default; a separate soft tick loop. |
| Minimum macOS | The current release; you will keep the Mac updated. |

## Working agreement for the implementing session

This spec is the source of truth. The coding session in VS Code works through the build order above, one milestone at a time, and does not add features outside the Features table.

- Repo: the GitHub repo `intervals`, created with `gh repo create` on first run. Made public on 2026-11-02 with an MIT license; anyone on the same macOS and Xcode versions can build and run it from source, and no other setup is supported. `SPEC.md` (this document) and `CLAUDE.md` live at the root. Commit at the end of every milestone with a message naming it (`Milestone 1: timer engine and tests`).
- Toolchain: latest Xcode on the Mac, Swift 6 strict concurrency, deployment target = the macOS version the Mac is running. No third-party packages. Build and test from the terminal with `xcodebuild -scheme Intervals test` so the session can verify its own work; open Xcode only for things the CLI cannot do (signing, asset catalog edits if needed).
- Project file: generate it with Xcode once (`File > New > Project > macOS App`, SwiftUI, SwiftData, name `Intervals`, bundle id `com.sohum.intervals`), commit it, then let the session edit sources. If the session can create the project itself with a tool like XcodeGen or a hand-written `project.pbxproj`, that is fine too, as long as `xcodebuild` works.
- Definition of done per milestone: it builds with no warnings, its tests pass, the app launches and the milestone's features work when tried by hand, and the commit is pushed.
- Decisions already made are in the Decisions table; do not reopen them. A question the spec does not answer gets the simplest reasonable choice, noted in the commit message, rather than a pause.
- Polish is part of every milestone, not only the last: native controls, system fonts, sensible spacing, animations on state changes, and nothing that looks like a placeholder.
