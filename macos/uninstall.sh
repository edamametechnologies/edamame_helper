#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

TARGET="/Library/Application Support/EDAMAME/EDAMAME-Helper"

echo "Uninstalling EDAMAME-Helper"

echo "Disabling EDAMAME-Helper"
launchctl unload /Library/LaunchDaemons/com.edamametechnologies.edamame-helper.plist

echo "Killing processes"
killall edamame_helper
sleep 10
echo "Killing zombies"
killall -9 edamame_helper

# Warning !
echo "Deleting installed files and logs"
rm -rf "$TARGET"
rm /var/log/edamame_helper*
rm /Library/LaunchDaemons/com.edamametechnologies.edamame-helper.plist

pkgutil --forget com.edamametechnologies.edamame-helper

echo "Done uninstalling EDAMAME-Helper"
