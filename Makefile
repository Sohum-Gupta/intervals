# Intervals — terminal build helpers. Xcode is not the active developer dir on
# this Mac, so every xcodebuild call pins DEVELOPER_DIR explicitly.
SHELL := /bin/zsh
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
DERIVED = build/DerivedData
XCB = xcodebuild -scheme Intervals -derivedDataPath $(DERIVED) -destination 'platform=macOS'
QUIET = 2>&1 | grep -vE 'linkd|appintentsmetadata|^builtin|^ {4}|^$$' | grep -E 'error:|error|warning:|✔|✘|Executed|\*\*|Suite|Test run'

.PHONY: project build test run clean icon sounds install

project:            ## regenerate Intervals.xcodeproj from project.yml
	xcodegen generate

build: project      ## Debug build, warnings are errors
	mkdir -p $(DERIVED) && touch $(DERIVED)/.metadata_never_index
	set -o pipefail; $(XCB) -configuration Debug build $(QUIET)

test: project       ## run unit tests
	set -o pipefail; $(XCB) -configuration Debug test $(QUIET)

run: build          ## launch the menu bar app
	pkill -x Intervals || true
	open $(DERIVED)/Build/Products/Debug/Intervals.app

clean:
	rm -rf build

install: project    ## Release build copied to /Applications (Spotlight and Raycast find it there)
	set -o pipefail; $(XCB) -configuration Release build $(QUIET)
	pkill -x Intervals || true
	rm -rf /Applications/Intervals.app
	cp -R $(DERIVED)/Build/Products/Release/Intervals.app /Applications/Intervals.app
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Intervals.app
	touch $(DERIVED)/.metadata_never_index
	open /Applications/Intervals.app

icon:               ## redraw the app icon layers inside the Icon Composer package
	swiftc -O -o build/make_icon Tools/make_icon.swift && build/make_icon Intervals/Resources/AppIcon.icon/Assets

sounds:             ## regenerate the bundled alert sounds
	python3 Tools/make_sounds.py

