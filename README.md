# Intervals

A native macOS menu bar Pomodoro timer for one person. No account, no sync, no
network, no paywall. It replaces apps like Be Focused and Flow for daily use on
a single Mac.

## What it does

- **Timer in the menu bar.** The countdown sits next to the clock
  (`● 24:59` while focusing, `○ 04:30` on a break, `‖` when paused). Clicking
  it opens a popover with a progress ring, the phase name, a title field and a
  tag picker, and Start / Pause / Skip / Reset. Space, ⌘→ and ⌘. drive it from
  the keyboard.
- **Configurable intervals.** Focus, short break and long break lengths, how
  many sessions come before a long break, and optional auto-start of the next
  focus session. Breaks always start on their own; when a break's time is up
  the timer counts up until you start the next session, so the real gap is
  recorded.
- **Never loses state.** The engine works from stored timestamps, not a
  running counter. Quit, crash, sleep the Mac, or leave it paused for a day:
  the interval picks up exactly where it should.
- **Alerts.** A macOS notification and one of four bundled sounds (or the
  system beep, or none) at the end of every interval, with a volume slider and
  an optional soft tick during focus.
- **History.** Every session is stored locally. A History window lists today
  and any date range, grouped by day, with a tag filter. Double-click a row to
  edit its start, end, title or tag; ⌘N adds one by hand; ⌫ deletes with a
  six-second undo.
- **Tags.** Create tags with a name and colour, pick one before or during a
  session, and see focus time broken down by tag.
- **Stats.** Today, this week and this month at a glance, a 14-day focus
  chart, and a per-tag table. Paused time never counts as focus.
- **Export.** All sessions as CSV or JSON, from the History toolbar or
  Settings > Data.
- **Appearance.** Light, dark or follow the system.

## Requirements

Intervals is built and tested on one machine, and only that setup is
supported:

- macOS 26.5 or later on Apple silicon
- Xcode 26.6 (the Command Line Tools alone are not enough)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Install

```sh
git clone https://github.com/Sohum-Gupta/intervals.git
cd intervals
make install
```

`make install` generates the Xcode project, builds a Release copy, puts it in
`/Applications`, and launches it. After that, open it from Spotlight or
Raycast like any other app. It has no Dock icon; look for a small circle near
the clock in the menu bar.

Other targets:

| Target | What it does |
| --- | --- |
| `make run` | Debug build, launched from the build folder |
| `make test` | Unit tests |
| `make build` | Debug build only; warnings are errors |
| `make icon` | Redraw the app icon layers |
| `make sounds` | Regenerate the alert sounds |
| `make clean` | Delete the build folder |

If Xcode lives somewhere other than `/Applications/Xcode.app`, set
`DEVELOPER_DIR` to its `Contents/Developer` folder first.

### Signing and notifications

The project signs with an Apple Development certificate; the team id is in
`project.yml`. Change it to your own team, or to `-` for ad-hoc signing if you
have no certificate. macOS only delivers notifications to apps signed with a
real certificate, and even then it may not show the permission prompt; if no
banner appears when an interval ends, switch Intervals on in System Settings >
Notifications. The sound still plays either way.

The app is not notarized, so only copies you build yourself run without
Gatekeeper prompts.

## How it is built

Swift 6, SwiftUI, SwiftData, Swift Charts and UserNotifications, with no
third-party packages. The timer is a pure state machine with an injected clock,
covered by unit tests that jump time to simulate sleep and relaunch. The full
design, including every decision, is in [SPEC.md](SPEC.md); notes for working
on the code are in [CLAUDE.md](CLAUDE.md).

```
Intervals/
  App/        app entry, settings, sounds, notifications
  Engine/     timer state machine, clock, persistence
  Models/     Session, Tag, stats, export
  Views/      MenuBar, History, Stats, Settings
  Resources/  sounds, app icon, accent colour
IntervalsTests/
Tools/        icon and sound generators
```

Data lives in `~/Library/Containers/com.sohum.intervals/Data/Library/Application Support/Intervals/`.

## License

[MIT](LICENSE).
