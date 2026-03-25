SCHEME       := VideoWallpaper
DERIVED_DATA := build
APP_NAME     := VideoWallpaper.app
INSTALL_DIR  := /Applications
BUILT_APP    := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME)

.PHONY: build install run uninstall dock

build:
	xcodegen generate
	xcodebuild -scheme $(SCHEME) \
	           -configuration Release \
	           -derivedDataPath $(DERIVED_DATA) \
	           -quiet \
	           clean build

install: build
	@if pgrep -x VideoWallpaper > /dev/null; then \
	    echo "Stopping running VideoWallpaper..."; \
	    pkill -x VideoWallpaper; \
	    sleep 1; \
	fi
	cp -Rf $(BUILT_APP) $(INSTALL_DIR)/$(APP_NAME)
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME)"

run: install
	open $(INSTALL_DIR)/$(APP_NAME)

uninstall:
	@if pgrep -x VideoWallpaper > /dev/null; then \
	    echo "Stopping running VideoWallpaper..."; \
	    pkill -x VideoWallpaper; \
	    sleep 1; \
	fi
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME)" ]; then \
	    rm -rf $(INSTALL_DIR)/$(APP_NAME); \
	    echo "Uninstalled $(INSTALL_DIR)/$(APP_NAME)"; \
	else \
	    echo "$(INSTALL_DIR)/$(APP_NAME) not found"; \
	fi

# Add VideoWallpaper to the Dock (persistent-apps).
# Run after `make install`. Requires the app to be in /Applications.
dock:
	@defaults write com.apple.dock persistent-apps -array-add \
	    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$(INSTALL_DIR)/$(APP_NAME)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
	killall Dock
	@echo "Added $(APP_NAME) to Dock"
