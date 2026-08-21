SHELL     := /bin/bash

# Личная identity для подписи — в signing.local, он не в гите.
# Без него сборка идёт с ad-hoc подписью: работает, но macOS будет
# переспрашивать доступ к Календарю после каждой пересборки.
#
# Team намеренно не в project.yml (в отличие от приватных проектов): репозиторий
# публичный, и с чужим DEVELOPMENT_TEAM сборка у постороннего упала бы на
# «No account for team».
-include signing.local
SIGN_ARGS  = $(if $(CODE_SIGN_IDENTITY),CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" $(if $(CODE_SIGN_STYLE),CODE_SIGN_STYLE="$(CODE_SIGN_STYLE)",),)
ARCHIVE_PATH ?= build/CallReminder.xcarchive
EXPORT_PATH  ?= build/export

PROJECT   := callReminder.xcodeproj
SCHEME    := callReminder
APP_NAME  := Call Reminder
CONFIG    := Debug
DEST      := platform=macOS,arch=arm64
SOURCES   := Sources Tests

.DEFAULT_GOAL := build
.PHONY: gen build release install uninstall test fmt fmt-check lint lint-fix check clean run archive package

# xcodegen отрабатывает за 25 мс, поэтому генерируем всегда, а не по timestamp:
# любая файловая зависимость врёт при УДАЛЕНИИ файла (нет файла — нет времени),
# и проект остаётся со ссылкой на несуществующий исходник. Проверено.
gen:
	@xcodegen generate --quiet

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -quiet $(SIGN_ARGS) build

release: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -quiet $(SIGN_ARGS) build

# Архив для App Store Connect. Подпись — автоматическая: Xcode сам заводит
# Apple Distribution и Mac Installer Distribution (для macOS их нужно два —
# .app и .pkg подписываются разными), сам создаёт профиль. Требует signing.local
# с DEVELOPMENT_TEAM; без него архив соберётся ad-hoc и стор его не примет.
archive: gen
ifndef DEVELOPMENT_TEAM
	$(error signing.local без DEVELOPMENT_TEAM — архив для стора собрать нечем)
endif
	rm -rf "$(ARCHIVE_PATH)"
	# -allowProvisioningUpdates обязателен: без него xcodebuild не имеет права
	# заводить профиль и Distribution-сертификат и молча подписывает ad-hoc,
	# а такой архив стор отвергает. Проверено — именно на этом всё и стояло.
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
	  -destination 'generic/platform=macOS' -archivePath "$(ARCHIVE_PATH)" \
	  -allowProvisioningUpdates \
	  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" archive
	@echo "архив: $(ARCHIVE_PATH)"

# .pkg для загрузки в App Store Connect. Приложение в архиве подписано
# Development — это норма: Distribution накладывается именно здесь, на экспорте,
# и пакет подписывается отдельным «3rd Party Mac Developer Installer».
package: archive
	rm -rf "$(EXPORT_PATH)"
	@mkdir -p "$(EXPORT_PATH)"
	@printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '<key>method</key><string>app-store</string>' \
	  '<key>teamID</key><string>$(DEVELOPMENT_TEAM)</string>' \
	  '<key>destination</key><string>export</string>' \
	  '</dict></plist>' > "$(EXPORT_PATH)/ExportOptions.plist"
	xcodebuild -exportArchive -archivePath "$(ARCHIVE_PATH)" \
	  -exportPath "$(EXPORT_PATH)" \
	  -exportOptionsPlist "$(EXPORT_PATH)/ExportOptions.plist" \
	  -allowProvisioningUpdates
	@echo "пакет: $(EXPORT_PATH)/$(APP_NAME).pkg"
	@pkgutil --check-signature "$(EXPORT_PATH)/$(APP_NAME).pkg" | head -3
	@echo "дальше: Xcode → Organizer → Distribute, либо Transporter.app"

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
