APP_NAME    := CodeBar
PROJECT     := $(APP_NAME).xcodeproj
BUILD_DIR   := DerivedData
RELEASE_APP := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
DEBUG_APP   := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app
INSTALL_DIR := /Applications
INSTALLED   := $(INSTALL_DIR)/$(APP_NAME).app
# Read from project.yml rather than repeated here, so a release cannot be named
# one version while the bundle inside it claims another. Anchored to the
# definition line and stopping there: a looser match also finds
# `CFBundleShortVersionString: $(MARKETING_VERSION)`, whose $(...) the shell then
# tries to run as a command, and the DMG comes out named `CodeBar-.dmg`.
VERSION     := $(shell awk -F'"' '/^ *MARKETING_VERSION:/ {print $$2; exit}' project.yml)
PACKAGES    := Packages/SQLiteKit Packages/CodeCore Packages/CodeStore \
               Packages/CodeLibrary Packages/CodeBarUI Packages/CodePlatform

.DEFAULT_GOAL := help

.PHONY: help install run uninstall release project bootstrap \
        build test test-scripts typecheck layering check check-all uitest clean icon dist

## ---------------------------------------------------------------- using it

help: ## Show this help
	@echo "CodeBar"
	@echo
	@echo "  Install it (what you want most of the time):"
	@echo "    make install      build a Release copy, put it in /Applications, launch it"
	@echo
	@echo "  Everything else:"
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "    %-14s %s\n", $$1, $$2}'
	@echo

install: release ## Build Release, install to /Applications, and launch
	@echo "==> stopping any running $(APP_NAME)"
	@osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || true
	@sleep 1
	@echo "==> installing to $(INSTALL_DIR)"
	@rm -rf "$(INSTALLED)"
	@ditto "$(RELEASE_APP)" "$(INSTALLED)"
	@echo "==> launching"
	@open "$(INSTALLED)"
	@echo
	@echo "$(APP_NAME) is installed and running. Press ⌥⌘C from anywhere."
	@echo "Turn on 'Open at Login' from the menu bar icon so it survives a restart."

## -------------------------------------------------------------- releasing

# Signing and notarising are opt-in through these two, so the same target works
# before and after enrolling in the Developer Program. Set them and the DMG is
# something a stranger can open; leave them and it is a DMG that Gatekeeper will
# refuse, which is still the right thing to build and test.
#
#   make dist SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#             NOTARY_PROFILE=codebar
#
# NOTARY_PROFILE is a keychain profile made once with:
#   xcrun notarytool store-credentials codebar --apple-id … --team-id … --password …
SIGN_IDENTITY  ?=
NOTARY_PROFILE ?=
DIST_DIR       := dist
DMG            := $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg

dist: release ## Build a distributable DMG (signs and notarises if configured)
	@rm -rf "$(DIST_DIR)/stage" "$(DMG)"
	@mkdir -p "$(DIST_DIR)/stage"
	@ditto "$(RELEASE_APP)" "$(DIST_DIR)/stage/$(APP_NAME).app"
	@if [ -n "$(SIGN_IDENTITY)" ]; then \
		echo "==> signing with $(SIGN_IDENTITY)"; \
		codesign --force --deep --options runtime --timestamp \
			--sign "$(SIGN_IDENTITY)" "$(DIST_DIR)/stage/$(APP_NAME).app"; \
		codesign --verify --strict --verbose=2 "$(DIST_DIR)/stage/$(APP_NAME).app"; \
	else \
		echo "==> SIGN_IDENTITY not set — building an unsigned DMG"; \
	fi
	@ln -sf /Applications "$(DIST_DIR)/stage/Applications"
	@echo "==> building $(DMG)"
	@hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DIST_DIR)/stage" \
		-ov -format UDZO -quiet "$(DMG)"
	@if [ -n "$(SIGN_IDENTITY)" ]; then \
		codesign --force --sign "$(SIGN_IDENTITY)" "$(DMG)"; \
	fi
	@if [ -n "$(NOTARY_PROFILE)" ]; then \
		echo "==> notarising (this waits on Apple)"; \
		xcrun notarytool submit "$(DMG)" --keychain-profile "$(NOTARY_PROFILE)" --wait; \
		xcrun stapler staple "$(DMG)"; \
		xcrun stapler validate "$(DMG)"; \
	else \
		echo "==> NOTARY_PROFILE not set — not notarised, Gatekeeper will refuse it"; \
	fi
	@rm -rf "$(DIST_DIR)/stage"
	@echo
	@echo "built $(DMG)"

uninstall: ## Quit and remove /Applications/CodeBar.app
	@osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || true
	@sleep 1
	@rm -rf "$(INSTALLED)"
	@echo "removed $(INSTALLED) — your codes and pins are untouched"

run: project ## Build Debug and launch it, without installing
	@xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) build | grep -E "error:|BUILD" || true
	@osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || true
	@sleep 1
	@open "$(DEBUG_APP)"

## ---------------------------------------------------------------- building

# A failed build must stop the pipeline. Piping xcodebuild into grep hides its
# exit status, and `|| true` discarded what was left — so a build that failed to
# compile still went on to install and launch the *previous* binary, reporting
# success. A fix that is silently not installed is worse than a visible failure.
release: project ## Build a Release copy without installing it
	@mkdir -p $(BUILD_DIR)
	@xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) build > $(BUILD_DIR)/release.log 2>&1 || { \
			grep -E "error:" $(BUILD_DIR)/release.log | head -20; \
			echo "==> build failed, see $(BUILD_DIR)/release.log"; \
			exit 1; \
		}
	@grep -E "^\*\* BUILD" $(BUILD_DIR)/release.log || true

bootstrap: ## Install XcodeGen if missing, then generate the Xcode project
	@command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
	@$(MAKE) project

icon: ## Regenerate the app icon from Tools/make-app-icon.swift
	@swift Tools/make-app-icon.swift CodeBar/Assets.xcassets/AppIcon.appiconset

project: ## Regenerate CodeBar.xcodeproj from project.yml
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen not found — run 'make bootstrap' first"; exit 1; }
	@xcodegen generate --quiet
	@echo "generated $(PROJECT)"

build: ## Build every local Swift package
	@for pkg in $(PACKAGES); do \
		echo "==> building $$pkg"; \
		( cd $$pkg && swift build ) || exit 1; \
	done

## ---------------------------------------------------------------- checking

check: test test-scripts typecheck layering ## Everything CI would run
	@echo
	@echo "Interaction tests are not in here — they take ~25s and quit a running"
	@echo "CodeBar. Run 'make uitest', or 'make check-all' for both."

check-all: check uitest ## check, plus the interaction tests

# These drive the real app: they launch it, close its window, and reopen it.
# A copy already running under the same bundle identifier makes the run
# non-deterministic, so the tests quit it first — including the one in
# /Applications. Relaunch it with 'make install' or from Spotlight afterwards.
uitest: project ## Interaction tests: window, reopen and panel behaviour
	@mkdir -p $(BUILD_DIR)
	@xcodebuild test -project $(PROJECT) -scheme $(APP_NAME) \
		-destination 'platform=macOS' -derivedDataPath $(BUILD_DIR) \
		-only-testing:CodeBarUITests > $(BUILD_DIR)/uitest.log 2>&1 || { \
			grep -E "error:|Test Case .* failed" $(BUILD_DIR)/uitest.log | head -20; \
			echo "==> interaction tests failed, see $(BUILD_DIR)/uitest.log"; \
			exit 1; \
		}
	@grep -cE "Test Case .* passed" $(BUILD_DIR)/uitest.log \
		| xargs printf "interaction tests passed: %s\n"

# CI sets SWIFT_TEST_FLAGS='--skip SnapshotTests'. The snapshot references are
# recorded on one Mac, and fonts, appearance and OS version all move the pixels,
# so they assert nothing on a runner except that it is a different machine. They
# stay a local gate; everything else runs everywhere.
SWIFT_TEST_FLAGS ?=

test: ## Swift tests across the four packages
	@for pkg in $(PACKAGES); do \
		echo "==> testing $$pkg"; \
		( cd $$pkg && swift test $(SWIFT_TEST_FLAGS) ) || exit 1; \
	done

test-scripts: ## Python tests for the code-set converters
	@python3 -m unittest discover -s Scripts/tests

typecheck: build ## Typecheck the app target without generating a project
	@zsh Tools/typecheck-app.sh

layering: ## Assert the module boundaries in docs/ARCHITECTURE.md §3
	@zsh Tools/check-layering.sh

clean: ## Remove build products and the generated project
	@for pkg in $(PACKAGES); do rm -rf $$pkg/.build; done
	@rm -rf $(PROJECT) $(BUILD_DIR)
	@echo "cleaned — $(INSTALLED) and your data are untouched"
