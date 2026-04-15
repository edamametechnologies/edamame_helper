#!/bin/bash
set -e

PROVISIONING_PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provisioning-profile) PROVISIONING_PROFILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

VERSION=$(grep '^version =' ./Cargo.toml | awk '{print $3}' | tr -d '"')
TARGET="./target/pkg"
ROOT="Library/Application Support/EDAMAME/EDAMAME-Helper"
APP_NAME="EDAMAME Helper"
APP_DIR="$TARGET/ROOT/$ROOT/edamame_helper.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
EXECUTABLE_NAME="edamame_helper"
EXECUTABLE_PATH="$MACOS_DIR/$EXECUTABLE_NAME"
BUNDLE_IDENTIFIER="com.edamametechnologies.edamame-helper"

rm -rf "$TARGET/ROOT/"

mkdir -p "$TARGET/ROOT/Library/LaunchDaemons"

cp ./macos/com.edamametechnologies.edamame-helper.plist "$TARGET/ROOT/Library/LaunchDaemons/"

mkdir -p "$MACOS_DIR"
cp ./target/release/edamame_helper "$EXECUTABLE_PATH"
chmod 755 "$EXECUTABLE_PATH"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_IDENTIFIER</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSBackgroundOnly</key>
  <true/>
</dict>
</plist>
EOF
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

mkdir -p "$TARGET/ROOT/$ROOT"
cp ./macos/uninstall.sh "$TARGET/ROOT/$ROOT"

# Restricted entitlements like Endpoint Security must be authorized by an
# embedded provisioning profile inside an app-like bundle. A loose Mach-O in
# Application Support is still subject to AMFI policy and may be killed on exec.
if [ -n "$PROVISIONING_PROFILE" ] && [ -f "$PROVISIONING_PROFILE" ]; then
  cp "$PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
  echo "Provisioning profile embedded in bundle"
else
  echo "No provisioning profile provided -- bundle will not include ES authorization"
fi

# Sign + hardened runtime + Endpoint Security entitlement
codesign --force --timestamp --options=runtime \
  --entitlements ./macos/edamame_helper.entitlements \
  -i "$BUNDLE_IDENTIFIER" \
  -s "Developer ID Application: Edamame Technologies (WSL782B48J)" \
  -v "$APP_DIR"

rm -rf "$TARGET/scripts/"
mkdir -p "$TARGET/scripts"

cp ./macos/postinstall "$TARGET/scripts/"
cp ./macos/preinstall "$TARGET/scripts/"

pkgbuild --analyze --root "$TARGET/ROOT" "$TARGET/components.plist"
python3 - "$TARGET/components.plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as f:
    data = plistlib.load(f)

updated = False

if isinstance(data, list):
    for entry in data:
        if isinstance(entry, dict):
            entry["BundleIsRelocatable"] = False
            updated = True
elif isinstance(data, dict):
    if "BundleIsRelocatable" in data:
        data["BundleIsRelocatable"] = False
        updated = True

    child_bundles = data.get("ChildBundles", [])
    if isinstance(child_bundles, list):
        for entry in child_bundles:
            if isinstance(entry, dict):
                entry["BundleIsRelocatable"] = False
                updated = True
else:
    raise SystemExit(f"Unexpected plist root type: {type(data)!r}")

if not updated:
    raise SystemExit("No bundle components found in pkgbuild analysis plist")

with open(path, "wb") as f:
    plistlib.dump(data, f)
PY

cd "$TARGET"
mkdir -p pkg
pkgbuild \
  --identifier "$BUNDLE_IDENTIFIER" \
  --root ./ROOT/ \
  --component-plist ./components.plist \
  --scripts ./scripts \
  --version "$VERSION" \
  pkg/edamame-helper-unsigned.pkg
