PACKAGES := Packages/CodeCore Packages/CodeStore Packages/CodeBarUI Packages/CodePlatform

.PHONY: bootstrap project build test typecheck layering check clean

## Everything CI would run.
check: test typecheck layering

## Install XcodeGen if missing, then generate CodeBar.xcodeproj.
bootstrap:
	@command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
	@$(MAKE) project

## Regenerate the Xcode project from project.yml.
project:
	xcodegen generate

## Build every local package.
build:
	@for pkg in $(PACKAGES); do \
		echo "==> building $$pkg"; \
		( cd $$pkg && swift build ) || exit 1; \
	done

## Run every package's tests.
test:
	@for pkg in $(PACKAGES); do \
		echo "==> testing $$pkg"; \
		( cd $$pkg && swift test ) || exit 1; \
	done

## Typecheck the app target without generating an Xcode project.
typecheck: build
	@zsh Tools/typecheck-app.sh

## Assert the module dependency rules from docs/ARCHITECTURE.md §3.
layering:
	@zsh Tools/check-layering.sh

clean:
	@for pkg in $(PACKAGES); do rm -rf $$pkg/.build; done
	rm -rf CodeBar.xcodeproj DerivedData
