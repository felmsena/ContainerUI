APP  = ContainerUI
BUNDLE = $(APP).app

.PHONY: build run release clean icon clear-cache

build:
	swift build
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp .build/debug/$(APP) $(BUNDLE)/Contents/MacOS/
	@cp Info.plist $(BUNDLE)/Contents/
	@cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	@rm -rf $(BUNDLE)/Contents/Resources/$(APP)_$(APP).bundle
	@cp -R .build/debug/$(APP)_$(APP).bundle $(BUNDLE)/Contents/Resources/
	@codesign --force --deep --sign - $(BUNDLE) 2>/dev/null || true
	@echo "✓  $(BUNDLE) ready"

run: build
	@pkill -x $(APP) 2>/dev/null || true
	@open $(BUNDLE)

release:
	swift build -c release
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp .build/release/$(APP) $(BUNDLE)/Contents/MacOS/
	@cp Info.plist $(BUNDLE)/Contents/
	@cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	@rm -rf $(BUNDLE)/Contents/Resources/$(APP)_$(APP).bundle
	@cp -R .build/release/$(APP)_$(APP).bundle $(BUNDLE)/Contents/Resources/
	@codesign --force --deep --sign - $(BUNDLE)
	@pkill -x $(APP) 2>/dev/null || true
	@open $(BUNDLE)

icon:
	@mkdir -p Resources/AppIcon.iconset
	@for size in 16 32 64 128 256 512 1024; do \
	  rsvg-convert -w $$size -h $$size Resources/AppIcon.svg -o Resources/AppIcon.iconset/tmp_$${size}.png; \
	done
	@cp Resources/AppIcon.iconset/tmp_16.png   Resources/AppIcon.iconset/icon_16x16.png
	@cp Resources/AppIcon.iconset/tmp_32.png   Resources/AppIcon.iconset/icon_16x16@2x.png
	@cp Resources/AppIcon.iconset/tmp_32.png   Resources/AppIcon.iconset/icon_32x32.png
	@cp Resources/AppIcon.iconset/tmp_64.png   Resources/AppIcon.iconset/icon_32x32@2x.png
	@cp Resources/AppIcon.iconset/tmp_128.png  Resources/AppIcon.iconset/icon_128x128.png
	@cp Resources/AppIcon.iconset/tmp_256.png  Resources/AppIcon.iconset/icon_128x128@2x.png
	@cp Resources/AppIcon.iconset/tmp_256.png  Resources/AppIcon.iconset/icon_256x256.png
	@cp Resources/AppIcon.iconset/tmp_512.png  Resources/AppIcon.iconset/icon_256x256@2x.png
	@cp Resources/AppIcon.iconset/tmp_512.png  Resources/AppIcon.iconset/icon_512x512.png
	@cp Resources/AppIcon.iconset/tmp_1024.png Resources/AppIcon.iconset/icon_512x512@2x.png
	@rm Resources/AppIcon.iconset/tmp_*.png
	@iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "✓  AppIcon.icns regenerated"

clean:
	swift package clean
	rm -rf $(BUNDLE)

clear-cache:
	@./clear-icon-cache.sh
