#!/bin/bash

# Capture the first command line argument
keychain_path="$1"

# Perform multiple attempts as this command sometimes fails
while true; do
  # Check if keychain path is provided and use the appropriate option
  if [ -n "$keychain_path" ]; then
    sub=$(xcrun notarytool submit ./target/edamame-helper.pkg --keychain "$keychain_path")
  else
    sub=$(xcrun notarytool submit ./target/edamame-helper.pkg --keychain-profile "Edamame")
  fi

  if [ $? -eq 0 ]; then
    break
  fi
  echo "Failed to submit notarization request, retrying in 5 seconds"
  sleep 5
done

id=$(echo "$sub" | grep "id:" | awk '{ print $2 }' | head -n1)
echo "$sub"
echo "Success requesting notarization for id $id"

# Use the appropriate option for notarytool wait
if [ -n "$keychain_path" ]; then
  wai=$(xcrun notarytool wait "$id" --keychain "$keychain_path")
else
  wai=$(xcrun notarytool wait "$id" --keychain-profile "Edamame")
fi

stat=$(echo "$wai" | grep status |  awk '{ print $2 }' | tail -n1)
echo "$wai"
if [ "$stat" = "Invalid" ]; then
  if [ -n "$keychain_path" ]; then
    xcrun notarytool log "$id" --keychain "$keychain_path"
  else
    xcrun notarytool log "$id" --keychain-profile "Edamame"
  fi
  echo "Notarization failed"
  exit 1
fi