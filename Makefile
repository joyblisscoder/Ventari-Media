APP_NAME = Ventari Media
BUILD_APP = build/VentariRecorder.app
BIN = $(BUILD_APP)/Contents/MacOS/VentariRecorder
SOURCES = $(wildcard App/*.m)
HEADERS = $(wildcard App/*.h)
SIGN ?= -
CFLAGS = -fobjc-arc -O2 -mmacosx-version-min=14.0 -IApp
LIBS = -framework Cocoa \
	-framework ScreenCaptureKit \
	-framework AVFoundation \
	-framework CoreMedia \
	-framework CoreVideo \
	-framework CoreImage \
	-framework Vision \
	-framework CoreGraphics \
	-framework CoreFoundation \
	-framework CoreText \
	-framework QuartzCore

.PHONY: all app install run tests clean

all: app

app: $(BIN)

$(BIN): $(SOURCES) $(HEADERS) Info.plist
	mkdir -p "$(BUILD_APP)/Contents/MacOS" "$(BUILD_APP)/Contents/Resources"
	clang $(CFLAGS) -o "$(BIN)" $(SOURCES) $(LIBS)
	cp Info.plist "$(BUILD_APP)/Contents/Info.plist"
	printf 'APPL????' > "$(BUILD_APP)/Contents/PkgInfo"
	if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$(BUILD_APP)/Contents/Resources/AppIcon.icns"; fi
	if [ -f Resources/Logo.png ]; then cp Resources/Logo.png "$(BUILD_APP)/Contents/Resources/Logo.png"; fi
	if [ -f Resources/Horizon.otf ]; then cp Resources/Horizon.otf "$(BUILD_APP)/Contents/Resources/Horizon.otf"; fi
	chmod +x "$(BIN)"
	codesign --force --deep --sign "$(SIGN)" --identifier com.ventari.recorder "$(BUILD_APP)"
	@echo "Signed with $(SIGN)"
	@echo "Built $(BUILD_APP)"

install: app
	rm -rf "/Applications/Ventari Recorder.app" "$(HOME)/Desktop/Ventari Recorder.app"
	ditto "$(BUILD_APP)" "/Applications/$(APP_NAME).app"
	ditto "$(BUILD_APP)" "$(HOME)/Desktop/$(APP_NAME).app"
	xattr -cr "/Applications/$(APP_NAME).app" "$(HOME)/Desktop/$(APP_NAME).app"
	@echo "Installed to /Applications and Desktop"

run: install
	open "$(HOME)/Desktop/$(APP_NAME).app"

tests:
	mkdir -p build
	clang $(CFLAGS) -o build/CompositorTests Tests/CompositorTests.m App/Compositor.m $(LIBS)
	./build/CompositorTests
	clang $(CFLAGS) -o build/BlurProcessorTests Tests/BlurProcessorTests.m App/BlurProcessor.m App/Compositor.m $(LIBS)
	./build/BlurProcessorTests

clean:
	rm -rf build
