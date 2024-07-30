#!/bin/bash
set -e

VERSION=$(grep '^version =' ./Cargo.toml | awk '{print $3}' | tr -d '"')
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Exception for main branch
if [ "${BRANCH}" == "main" ]; then
  aws s3 cp ./target/pkg/edamame-helper.pkg s3://edamame-helper/macos/edamame-helper-"${VERSION}".pkg --acl public-read
else
  aws s3 cp ./target/pkg/edamame-helper.pkg s3://edamame-helper/"${BRANCH}"/macos/edamame-helper-"${VERSION}".pkg --acl public-read
fi
