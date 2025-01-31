#!/bin/bash
set -e

VERSION=$(grep '^version =' ./Cargo.toml | awk '{print $3}' | tr -d '"')
TARGET="./target/pkg"

mkdir -p "$TARGET/resources"
cp ./macos/welcome.html "$TARGET/resources/"
cp ./macos/license.txt "$TARGET/resources/"
cp ./macos/conclusion.html "$TARGET/resources/"
cp ./macos/banner.png "$TARGET/resources/"

cat ./macos/distribution.xml \
  | sed "s|xxxVERSIONxxx|$VERSION|g" \
  > "$TARGET/distribution.xml"
  
cd "$TARGET"
productbuild --distribution distribution.xml --resources resources --package-path pkg --version "$VERSION" edamame-helper-unsigned.pkg
productsign --sign WSL782B48J edamame-helper-unsigned.pkg edamame-helper.pkg
