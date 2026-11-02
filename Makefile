APP := build/TrackEdge.app
CONFIG ?= release
SIGN_IDENTITY ?= -
# Set by the release workflow. Local builds keep the version in Support/Info.plist.
VERSION ?=
BUILD_NUMBER ?=
# Pass "--arch arm64 --arch x86_64" for a universal binary.
SWIFT_FLAGS ?=

.PHONY: build test app run icon clean

build:
	swift build -c $(CONFIG) $(SWIFT_FLAGS)

test:
	swift test

# Wraps the SwiftPM binary in an app bundle. Signs ad hoc unless SIGN_IDENTITY is set.
app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$$(swift build -c $(CONFIG) $(SWIFT_FLAGS) --show-bin-path)/TrackEdge" $(APP)/Contents/MacOS/TrackEdge
	cp Support/Info.plist $(APP)/Contents/Info.plist
	cp Support/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	@if [ -n "$(VERSION)" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist; fi
	@if [ -n "$(BUILD_NUMBER)" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" $(APP)/Contents/Info.plist; fi
	codesign --force --options runtime --sign "$(SIGN_IDENTITY)" $(APP)

run: app
	open $(APP)

# Redraws Support/AppIcon.icns and Support/AppIcon.png from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
