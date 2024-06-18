#!/bin/bash

VERSION=$(grep '^version =' ../Cargo.toml | awk '{print $3}' | tr -d '"')
TARGET="./target"
ROOT="Library/Application Support/EDAMAME/EDAMAME-Helper"

# Warning !
rm -rf "$TARGET/ROOT/"
mkdir -p "$TARGET/ROOT/Library/LaunchDaemons"

cp com.edamametechnologies.edamame-helper.plist "$TARGET/ROOT/Library/LaunchDaemons/"

mkdir -p "$TARGET/ROOT/$ROOT"
cp ./target/edamame_helper "$TARGET/ROOT/$ROOT"

# Sign + hardened runtime
codesign --timestamp --options=runtime -s "Developer ID Application: Edamame Technologies (WSL782B48J)" -v "$TARGET/ROOT/$ROOT"/edamame_helper

# Include the most recent uninstall script
cp uninstall.sh "$TARGET/ROOT/$ROOT"

rm -rf "$TARGET/scripts/"
mkdir -p "$TARGET/scripts"

cp postinstall "$TARGET/scripts/"
cp preinstall "$TARGET/scripts/"

cd "$TARGET"
mkdir -p pkg
pkgbuild --identifier com.edamametechnologies.edamame-helper --root ./ROOT/ --scripts ./scripts --version "$VERSION" pkg/edamame-helper-unsigned.pkg
productsign --sign WSL782B48J pkg/edamame-helper-unsigned.pkg pkg/edamame-helper.pkg
