APP      := Pounce
BUNDLE   := $(APP).app
# The signing identity of one team, on every Mac and for every build: releases and local installs
# must look like the same app to macOS, or the granted permissions fall away and the app refuses to
# update itself. signing-identity.sh picks by the certificate's team, falling back to ad-hoc.
# Override with `make install IDENTITY=<hash>` or `RELEASE_TEAM=<team> make install`.
RELEASE_TEAM ?= VXR4D4G8N4
IDENTITY ?= $(shell ./signing-identity.sh $(RELEASE_TEAM))
SRC      := $(wildcard src/*.swift)

all: build

build:
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp src/Info.plist $(BUNDLE)/Contents/
	@cp src/assets/Pounce.icns $(BUNDLE)/Contents/Resources/
	@cp src/assets/paw-mask.png $(BUNDLE)/Contents/Resources/paw.png
	@cp src/assets/tungsten.jpg $(BUNDLE)/Contents/Resources/
	swiftc $(SRC) -o $(BUNDLE)/Contents/MacOS/$(APP) -O -parse-as-library -target arm64-apple-macos14.0
	codesign -fs "$(IDENTITY)" $(BUNDLE)

# Synced in place rather than deleted and copied: the bundle keeps its identity, so the notification
# and accessibility permissions the user granted stay attached to it.
install: build
	@pkill -x $(APP) || true
	@rsync -a --delete $(BUNDLE)/ /Applications/$(BUNDLE)/
	@echo "installed /Applications/$(BUNDLE)"

run: install
	@open -a /Applications/$(BUNDLE)

clean:
	@rm -rf $(BUNDLE)

# Regenerates the app icon and the menu bar paw from src/assets/paw-source.png.
icon:
	swift src/assets/make-icon.swift $(DIST)/Pounce.iconset
	iconutil -c icns $(DIST)/Pounce.iconset -o src/assets/Pounce.icns
	@rm -rf $(DIST)/Pounce.iconset

# ---- Distribution -------------------------------------------------------------
# Needs a Developer ID Application certificate (paid Apple Developer Program) and,
# for notarization, a notarytool keychain profile:
#   xcrun notarytool store-credentials pounce --apple-id <id> --team-id <team> --password <app-specific>
VERSION        := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' src/Info.plist)
DIST_IDENTITY  ?= Developer ID Application
NOTARY_PROFILE ?= pounce
DIST           := dist
ZIP            := $(DIST)/Pounce-$(VERSION).zip
DMG            := $(DIST)/Pounce-$(VERSION).dmg

# Universal (Apple silicon + Intel) build, hardened runtime, Developer ID signature, zip.
dist:
	@rm -rf $(BUNDLE) $(DIST) && mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources $(DIST)
	@cp src/Info.plist $(BUNDLE)/Contents/
	@cp src/assets/Pounce.icns $(BUNDLE)/Contents/Resources/
	@cp src/assets/paw-mask.png $(BUNDLE)/Contents/Resources/paw.png
	@cp src/assets/tungsten.jpg $(BUNDLE)/Contents/Resources/
	swiftc $(SRC) -o $(DIST)/$(APP)-arm64  -O -parse-as-library -target arm64-apple-macos14.0
	swiftc $(SRC) -o $(DIST)/$(APP)-x86_64 -O -parse-as-library -target x86_64-apple-macos14.0
	lipo -create -output $(BUNDLE)/Contents/MacOS/$(APP) $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	@rm $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	codesign --force --options runtime --timestamp -s "$(DIST_IDENTITY)" $(BUNDLE)
	codesign --verify --deep --strict $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	@echo "built $(ZIP)"

# Hand-off without notarization: universal build, signed with whatever identity this Mac has, zipped.
# The receiver's Gatekeeper objects once; System Settings > Privacy & Security > "Open Anyway" clears it.
package:
	@rm -rf $(BUNDLE) $(DIST) && mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources $(DIST)
	@cp src/Info.plist $(BUNDLE)/Contents/
	@cp src/assets/Pounce.icns $(BUNDLE)/Contents/Resources/
	@cp src/assets/paw-mask.png $(BUNDLE)/Contents/Resources/paw.png
	@cp src/assets/tungsten.jpg $(BUNDLE)/Contents/Resources/
	swiftc $(SRC) -o $(DIST)/$(APP)-arm64  -O -parse-as-library -target arm64-apple-macos14.0
	swiftc $(SRC) -o $(DIST)/$(APP)-x86_64 -O -parse-as-library -target x86_64-apple-macos14.0
	lipo -create -output $(BUNDLE)/Contents/MacOS/$(APP) $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	@rm $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	codesign -fs "$(IDENTITY)" --timestamp $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	@echo "packaged $(ZIP)"
	@shasum -a 256 $(ZIP)

# Submit to Apple, staple the ticket, re-zip, and also produce a DMG.
notarize: dist
	xcrun notarytool submit $(ZIP) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	@rm -rf $(DIST)/dmg && mkdir -p $(DIST)/dmg && cp -R $(BUNDLE) $(DIST)/dmg/ && ln -s /Applications $(DIST)/dmg/Applications
	hdiutil create -volname "Pounce" -srcfolder $(DIST)/dmg -ov -format UDZO $(DMG)
	@rm -rf $(DIST)/dmg
	spctl -a -vv $(BUNDLE)
	@shasum -a 256 $(ZIP) $(DMG)

.PHONY: all build install run clean icon package dist notarize
