# Intervals — terminal build helpers. Xcode is not the active developer dir on
# this Mac, so every xcodebuild call pins DEVELOPER_DIR explicitly.
SHELL := /bin/zsh
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
DERIVED = build/DerivedData
XCB = xcodebuild -scheme Intervals -derivedDataPath $(DERIVED) -destination 'platform=macOS'
QUIET = 2>&1 | grep -vE 'linkd|appintentsmetadata|^builtin|^ {4}|^$$' | grep -E 'error:|error|warning:|✔|✘|Executed|\*\*|Suite|Test run'

.PHONY: project build test run clean icon sounds

project:            ## regenerate Intervals.xcodeproj from project.yml
	xcodegen generate

build: project      ## Debug build, warnings are errors
	set -o pipefail; $(XCB) -configuration Debug build $(QUIET)

test: project       ## run unit tests
	set -o pipefail; $(XCB) -configuration Debug test $(QUIET)

run: build          ## launch the menu bar app
	pkill -x Intervals || true
	open $(DERIVED)/Build/Products/Debug/Intervals.app

clean:
	rm -rf build

icon:               ## redraw the app icon into the asset catalog
	swiftc -O -o build/make_icon Tools/make_icon.swift && build/make_icon Intervals/Resources/Assets.xcassets/AppIcon.appiconset

sounds:             ## regenerate the bundled alert sounds
	python3 Tools/make_sounds.py

