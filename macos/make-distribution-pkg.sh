#!/bin/bash

VERSION=$(grep '^version =' ../Cargo.toml | awk '{print $3}' | tr -d '"')
TARGET="./target"

mkdir -p "$TARGET/resources"
cp welcome.html "$TARGET/resources/"
cp license.txt "$TARGET/resources/"
cp conclusion.html "$TARGET/resources/"
cp banner.png "$TARGET/resources/"

cp distribution.xml "$TARGET/"

cd "$TARGET"
productbuild --distribution distribution.xml --resources resources --package-path pkg --version "$VERSION" edamame-helper-unsigned.pkg
productsign --sign WSL782B48J edamame-helper-unsigned.pkg edamame-helper.pkg
