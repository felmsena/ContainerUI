#!/bin/bash
sudo rm -rf /Library/Caches/com.apple.iconservices.store
sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} \; 2>/dev/null
killall Dock
killall Finder
echo "✓ Icon cache cleared"
