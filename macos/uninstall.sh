#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

TARGET="/Library/Application Support/EDAMAME/EDAMAME-Helper"
PLIST="/Library/LaunchDaemons/com.edamametechnologies.edamame-helper.plist"
LEGACY_PROFILE="/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile"

echo "Uninstalling EDAMAME-Helper"

echo "Disabling EDAMAME-Helper"
/bin/launchctl bootout system "$PLIST" 2>/dev/null || true
/bin/launchctl unload "$PLIST" 2>/dev/null || true

echo "Killing processes"
killall edamame_helper 2>/dev/null || true
sleep 2
echo "Killing zombies"
killall -9 edamame_helper 2>/dev/null || true

# Warning !
echo "Deleting installed files and logs"
rm -rf "$TARGET"
rm -f /var/log/edamame_helper*
rm -f /var/log/edamame/edamame_helper*
rm -f "$PLIST"
rm -f "$LEGACY_PROFILE"

pkgutil --forget com.edamametechnologies.edamame-helper || true

echo "Done uninstalling EDAMAME-Helper"
