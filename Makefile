SCHEME       := VideoWallpaper
DERIVED_DATA := build
APP_NAME     := VideoWallpaper.app
INSTALL_DIR  := /Applications
BUILT_APP    := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME)

.PHONY: build install run uninstall dock stop test lint clean

# --- Safety helpers -----------------------------------------------------------

define assert-non-empty
$(if $(strip $(1)),,$(error $(2) is empty — refusing destructive operation))
endef

define stop-app
@PID=$$(pgrep -x "$(SCHEME)" 2>/dev/null); \
if [ -n "$$PID" ]; then \
    echo "Stopping running $(SCHEME) (PID $$PID)..."; \
    kill "$$PID" 2>/dev/null || true; \
    sleep 1; \
fi
endef

# --- Core targets -------------------------------------------------------------

build:
	xcodegen generate
	xcodebuild -scheme $(SCHEME) \
	           -configuration Release \
	           -derivedDataPath $(DERIVED_DATA) \
	           -quiet \
	           build

install: build
	$(call stop-app)
	$(call assert-non-empty,$(INSTALL_DIR),INSTALL_DIR)
	$(call assert-non-empty,$(APP_NAME),APP_NAME)
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	cp -R "$(BUILT_APP)" "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME)"

run: install
	open "$(INSTALL_DIR)/$(APP_NAME)"

stop:
	$(call stop-app)

uninstall: stop
	$(call assert-non-empty,$(INSTALL_DIR),INSTALL_DIR)
	$(call assert-non-empty,$(APP_NAME),APP_NAME)
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME)" ]; then \
	    rm -rf "$(INSTALL_DIR)/$(APP_NAME)"; \
	    echo "Uninstalled $(INSTALL_DIR)/$(APP_NAME)"; \
	else \
	    echo "$(INSTALL_DIR)/$(APP_NAME) not found"; \
	fi

# --- Additional targets -------------------------------------------------------

test:
	xcodegen generate
	xcodebuild test -scheme $(SCHEME) \
	           -destination 'platform=macOS' \
	           -derivedDataPath $(DERIVED_DATA) \
	           -quiet

lint:
	@./scripts/run-swiftlint-from-spm.sh

clean:
	$(call assert-non-empty,$(DERIVED_DATA),DERIVED_DATA)
	rm -rf "$(DERIVED_DATA)"
	@echo "Cleaned $(DERIVED_DATA)"

# Add VideoWallpaper to the Dock (persistent-apps).
# Run after `make install`. Requires the app to be in /Applications.
dock:
	@defaults write com.apple.dock persistent-apps -array-add \
	    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$(INSTALL_DIR)/$(APP_NAME)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
	@echo "Added $(APP_NAME) to Dock — restart Dock manually if needed"
