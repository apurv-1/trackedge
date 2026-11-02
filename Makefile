APP := build/TrackEdge.app
CONFIG ?= release
SIGN_IDENTITY ?= -

.PHONY: build test app run icon clean

build:
	swift build -c $(CONFIG)

test:
	swift test

# Wraps the SwiftPM binary in an app bundle. Signs ad hoc unless SIGN_IDENTITY is set.
app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$$(swift build -c $(CONFIG) --show-bin-path)/TrackEdge" $(APP)/Contents/MacOS/TrackEdge
	cp Support/Info.plist $(APP)/Contents/Info.plist
	cp Support/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --options runtime --sign "$(SIGN_IDENTITY)" $(APP)

run: app
	open $(APP)

# Redraws Support/AppIcon.icns and Support/AppIcon.png from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
