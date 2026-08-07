SHELL     := /bin/bash

# Личная identity для подписи — в signing.local, он не в гите.
# Без него сборка идёт с ad-hoc подписью: работает, но macOS будет
# переспрашивать доступ к Календарю после каждой пересборки.
-include signing.local
SIGN_ARGS  = $(if $(CODE_SIGN_IDENTITY),CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)",)

PROJECT   := callReminder.xcodeproj
SCHEME    := callReminder
APP_NAME  := Call Reminder
CONFIG    := Debug
DEST      := platform=macOS,arch=arm64
SOURCES   := Sources Tests

.DEFAULT_GOAL := build
.PHONY: gen build release install uninstall test fmt fmt-check lint lint-fix check clean run

# xcodegen отрабатывает за 25 мс, поэтому генерируем всегда, а не по timestamp:
# любая файловая зависимость врёт при УДАЛЕНИИ файла (нет файла — нет времени),
# и проект остаётся со ссылкой на несуществующий исходник. Проверено.
gen:
	@xcodegen generate --quiet

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -quiet $(SIGN_ARGS) build

release: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -quiet $(SIGN_ARGS) build

# Ставим в /Applications: оттуда работает автозапуск через SMAppService,
# и приложение переживает очистку DerivedData.
install: release
	@BUILT=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
	  -showBuildSettings 2>/dev/null \
	  | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$$2} / FULL_PRODUCT_NAME /{n=$$2} END{print d"/"n}'); \
	  pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true; sleep 1; \
	  rm -rf "/Applications/$(APP_NAME).app"; \
	  cp -R "$$BUILT" /Applications/; \
	  codesign --verify --deep --strict "/Applications/$(APP_NAME).app" && echo "подпись цела"; \
	  echo "установлено: /Applications/$(APP_NAME).app"; \
	  open "/Applications/$(APP_NAME).app"

uninstall:
	pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	rm -rf "/Applications/$(APP_NAME).app"

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
	@BUILT=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	  -showBuildSettings 2>/dev/null \
	  | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$$2} / FULL_PRODUCT_NAME /{n=$$2} END{print d"/"n}'); \
	  echo "open $$APP"; open "$$APP"
