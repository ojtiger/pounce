APP      := CentreGrowl
BUNDLE   := $(APP).app
# Apple Development identity when the Mac has one (keeps TCC permissions stable across builds),
# otherwise ad-hoc so `make install` works on any Mac with Xcode.
IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development" && echo "Apple Development" || echo "-")
SRC      := $(wildcard src/*.swift)

all: build

build:
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp src/Info.plist $(BUNDLE)/Contents/
	@cp src/assets/CentreGrowl.icns $(BUNDLE)/Contents/Resources/
	swiftc $(SRC) -o $(BUNDLE)/Contents/MacOS/$(APP) -O -parse-as-library -target arm64-apple-macos14.0
	codesign -fs "$(IDENTITY)" $(BUNDLE)

install: build
	@pkill -x $(APP) || true
	@rm -rf /Applications/$(BUNDLE)
	@cp -R $(BUNDLE) /Applications/
	@echo "installed /Applications/$(BUNDLE)"

run: install
	@open -a /Applications/$(BUNDLE)

clean:
	@rm -rf $(BUNDLE)

# ---- Distribution -------------------------------------------------------------
# Needs a Developer ID Application certificate (paid Apple Developer Program) and,
# for notarization, a notarytool keychain profile:
#   xcrun notarytool store-credentials centre-growl --apple-id <id> --team-id <team> --password <app-specific>
VERSION        := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' src/Info.plist)
DIST_IDENTITY  ?= Developer ID Application
NOTARY_PROFILE ?= centre-growl
DIST           := dist
ZIP            := $(DIST)/CentreGrowl-$(VERSION).zip
DMG            := $(DIST)/CentreGrowl-$(VERSION).dmg

# Universal (Apple silicon + Intel) build, hardened runtime, Developer ID signature, zip.
dist:
	@rm -rf $(BUNDLE) $(DIST) && mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources $(DIST)
	@cp src/Info.plist $(BUNDLE)/Contents/
	@cp src/assets/CentreGrowl.icns $(BUNDLE)/Contents/Resources/
	swiftc $(SRC) -o $(DIST)/$(APP)-arm64  -O -parse-as-library -target arm64-apple-macos14.0
	swiftc $(SRC) -o $(DIST)/$(APP)-x86_64 -O -parse-as-library -target x86_64-apple-macos14.0
	lipo -create -output $(BUNDLE)/Contents/MacOS/$(APP) $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	@rm $(DIST)/$(APP)-arm64 $(DIST)/$(APP)-x86_64
	codesign --force --options runtime --timestamp -s "$(DIST_IDENTITY)" $(BUNDLE)
	codesign --verify --deep --strict $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	@echo "built $(ZIP)"

# Submit to Apple, staple the ticket, re-zip, and also produce a DMG.
notarize: dist
	xcrun notarytool submit $(ZIP) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	@rm -rf $(DIST)/dmg && mkdir -p $(DIST)/dmg && cp -R $(BUNDLE) $(DIST)/dmg/ && ln -s /Applications $(DIST)/dmg/Applications
	hdiutil create -volname "CentreGrowl" -srcfolder $(DIST)/dmg -ov -format UDZO $(DMG)
	@rm -rf $(DIST)/dmg
	spctl -a -vv $(BUNDLE)
	@shasum -a 256 $(ZIP) $(DMG)

.PHONY: all build install run clean dist notarize
