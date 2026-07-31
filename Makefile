SHELL     := /bin/bash

PROJECT   := callReminder.xcodeproj
SCHEME    := callReminder
CONFIG    := Debug
DEST      := platform=macOS,arch=arm64
SOURCES   := Sources Tests

.DEFAULT_GOAL := build
.PHONY: gen build test fmt fmt-check lint lint-fix check clean run

gen: $(PROJECT)
$(PROJECT): project.yml
	xcodegen generate
	@touch $@

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -quiet build

test: gen
	set -o pipefail; xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' test 2>&1 | grep -E '✔|✘|passed|failed|error:|\*\* TEST'

fmt:
	swift format format --in-place --recursive --parallel $(SOURCES)

fmt-check:
	swift format lint --recursive --parallel --strict $(SOURCES)

lint:
	swiftlint lint --quiet --strict

lint-fix:
	swiftlint lint --fix --quiet
	$(MAKE) fmt

check: fmt-check lint test

clean:
	rm -rf $(PROJECT) build

run: build
	@APP=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	  -showBuildSettings 2>/dev/null \
	  | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$$2} / FULL_PRODUCT_NAME /{n=$$2} END{print d"/"n}'); \
	  echo "open $$APP"; open "$$APP"
