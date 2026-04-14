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

rm -rf "$TARGET/ROOT/"

mkdir -p "$TARGET/ROOT/Library/LaunchDaemons"

cp ./macos/com.edamametechnologies.edamame-helper.plist "$TARGET/ROOT/Library/LaunchDaemons/"

mkdir -p "$TARGET/ROOT/$ROOT"
cp ./target/release/edamame_helper "$TARGET/ROOT/$ROOT"

# Sign + hardened runtime + Endpoint Security entitlement
codesign --timestamp --options=runtime \
  --entitlements ./macos/edamame_helper.entitlements \
  -i com.edamametechnologies.edamame-helper \
  -s "Developer ID Application: Edamame Technologies (WSL782B48J)" \
  -v "$TARGET/ROOT/$ROOT"/edamame_helper

cp ./macos/uninstall.sh "$TARGET/ROOT/$ROOT"

# Embed the ES provisioning profile so AMFI can authorize the entitlement at runtime.
# Without the profile, macOS kills the binary with SIGKILL (signal 9).
if [ -n "$PROVISIONING_PROFILE" ] && [ -f "$PROVISIONING_PROFILE" ]; then
  PROFILE_DIR="$TARGET/ROOT/Library/MobileDevice/Provisioning Profiles"
  mkdir -p "$PROFILE_DIR"
  cp "$PROVISIONING_PROFILE" "$PROFILE_DIR/EDAMAME_Helper.provisionprofile"
  echo "Provisioning profile embedded in package"
else
  echo "No provisioning profile provided -- package will not include ES authorization"
fi

rm -rf "$TARGET/scripts/"
mkdir -p "$TARGET/scripts"

cp ./macos/postinstall "$TARGET/scripts/"
cp ./macos/preinstall "$TARGET/scripts/"

cd "$TARGET"
mkdir -p pkg
pkgbuild --identifier com.edamametechnologies.edamame-helper --root ./ROOT/ --scripts ./scripts --version "$VERSION" pkg/edamame-helper-unsigned.pkg
