#!/usr/bin/make

APP_NAME := HiraginoPatch
BUNDLE_NAME := Patch.app
VOL_NAME := $(APP_NAME)
VERSION := $(shell head -n 1 version)
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 0)

TAG_EXISTS := $(shell git rev-parse -q --verify refs/tags/v$(VERSION) >/dev/null && echo yes || echo no)

ifeq ($(TAG_EXISTS),yes)
GIT_SUFFIX =
else
GIT_SUFFIX = -$(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
endif

DMG_FILENAME := $(APP_NAME)_$(VERSION)$(GIT_SUFFIX).dmg

WORK_DIR := Work
APP_DIR := $(WORK_DIR)/hiragino-patch
APP_PATH := $(APP_DIR)/$(BUNDLE_NAME)

all: clean app

.PHONY: clean
clean:
	rm -f *~
	rm -rf $(WORK_DIR)
	rm -f *.dmg

.PHONY: app
app $(APP_PATH):
	mkdir -p $(APP_DIR)
	osacompile -o $(APP_PATH) patchapp.applescript
	cp -a Patch.sh $(APP_PATH)/Contents/Resources/
	cp -a ptex-fontmaps $(APP_PATH)/Contents/Resources/
	cp -a cjk-gs-support $(APP_PATH)/Contents/Resources/
	## replace icon: remove Assets.car (macOS 26 osacompile embeds default
	## icon there, which takes priority over applet.icns)
	rm -f $(APP_PATH)/Contents/Resources/Assets.car
	cp -a artwork/bibunsho7.icns $(APP_PATH)/Contents/Resources/applet.icns
	touch $(APP_PATH)
	## copy some documents as plain text files
	cp -a README.md $(APP_DIR)/README.txt

.PHONY: codesign
codesign: app
	@if [ -n "$(CODE_SIGN_IDENTITY)" ]; then \
	    echo "Signing $(BUNDLE_NAME) with identity: $(CODE_SIGN_IDENTITY)"; \
	    codesign --force --deep --options runtime \
	        --sign "$(CODE_SIGN_IDENTITY)" $(APP_PATH); \
	    codesign --verify --deep $(APP_PATH); \
	    echo "Code signing complete."; \
	else \
	    echo "CODE_SIGN_IDENTITY not set, skipping codesign."; \
	fi

.PHONY: dmg
dmg: app
	@echo "Creating disk image ($(DMG_FILENAME)) in ULMO format..."
	@rm -f $(DMG_FILENAME)
	hdiutil create -volname $(VOL_NAME) -srcfolder $(APP_DIR) -ov -format ULMO $(DMG_FILENAME)
	@echo "Done! $(DMG_FILENAME) created."

.PHONY: notarize
notarize: dmg
	xcrun notarytool submit $(DMG_FILENAME) \
	    --keychain-profile "$(NOTARIZE_PROFILE)" --wait
	xcrun stapler staple $(DMG_FILENAME)
	@echo "Notarization complete."

.PHONY: notarized-dmg
notarized-dmg: codesign dmg notarize

TLNET_REPO := /opt/texlive/repos/tlnet

.PHONY: test
test: app
	TLNET_REPO=$(TLNET_REPO) bash test/test-current.sh $(CURDIR)

.PHONY: test-clean
test-clean:
	rm -rf /tmp/hiragino-patch-test

## end of file
