# Intervals

A native macOS menu bar Pomodoro timer for one person. No paywall, no account,
no sync, no network. The full design is in [SPEC.md](SPEC.md); it is built one
milestone at a time with Claude Code, following [CLAUDE.md](CLAUDE.md).

## Requirements

Intervals is only built and tested on the machine it was written on. It should
work on any Mac with the same setup, and no other setup is supported:

- macOS 26.5 or later, Apple silicon
- Xcode 26.6 (the Command Line Tools alone are not enough)
- [Homebrew](https://brew.sh) with `xcodegen` (`brew install xcodegen`)

## Build and run

```sh
git clone https://github.com/Sohum-Gupta/intervals.git
cd intervals
make run
```

`make run` regenerates the Xcode project from `project.yml`, builds a Debug
copy, and opens it. The app lives in the menu bar, not the Dock. Look for a
small circle near the clock. Other targets:

```sh
make build   # build only, warnings are errors
make test    # run the unit tests
make clean   # delete the build folder
```

If Xcode is installed somewhere other than `/Applications/Xcode.app`, set
`DEVELOPER_DIR` to its `Contents/Developer` folder before running `make`.

The project signs with an Apple Development certificate (team in
`project.yml`); macOS refuses notifications to ad-hoc signed apps. If no
permission prompt appears on first launch, turn Intervals on in System
Settings > Notifications. Without a certificate the end-of-interval alert is
sound only.

The build is signed ad hoc and not notarized, so a copy built on your own Mac
runs without any prompts. A copy downloaded from elsewhere would be blocked by
Gatekeeper; building from source is the supported path.

## Status

| Milestone | What it adds | Done |
| --- | --- | --- |
| 1 | Timer engine, persistence, unit tests | yes |
| 2 | Menu bar countdown, popover, notifications, sounds | yes |
| 3 | Session history and tags in SwiftData | yes |
| 4 | History window with editing | |
| 5 | Stats and CSV/JSON export | |
| 6 | Appearance setting and polish pass | |

## License

[MIT](LICENSE).
