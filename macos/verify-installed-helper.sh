#!/bin/bash
set -euo pipefail

MODE="all"
case "${1:-}" in
  "")
    ;;
  --structure-only)
    MODE="structure"
    ;;
  --launch-only)
    MODE="launch"
    ;;
  *)
    echo "Usage: $0 [--structure-only|--launch-only]" >&2
    exit 1
    ;;
esac

HELPER_ROOT="/Library/Application Support/EDAMAME/EDAMAME-Helper"
BUNDLE_PATH="$HELPER_ROOT/edamame_helper.app"
CONTENTS_DIR="$BUNDLE_PATH/Contents"
EXECUTABLE_PATH="$CONTENTS_DIR/MacOS/edamame_helper"
PROFILE_PATH="$CONTENTS_DIR/embedded.provisionprofile"
UNINSTALL_PATH="$HELPER_ROOT/uninstall.sh"
PLIST_PATH="/Library/LaunchDaemons/com.edamametechnologies.edamame-helper.plist"
LABEL="system/com.edamametechnologies.edamame-helper"
LEGACY_PROFILE="/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile"
LOG_DIR="$CONTENTS_DIR/MacOS"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

info() {
  echo "[INFO] $1"
}

run_root() {
  if [ -n "$SUDO" ]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

dump_diagnostics() {
  info "Bundle root listing:"
  ls -la "$HELPER_ROOT" 2>&1 || true

  info "Bundle contents listing:"
  ls -la "$CONTENTS_DIR" 2>&1 || true

  info "Executable directory listing:"
  ls -la "$LOG_DIR" 2>&1 || true

  info "LaunchDaemon state:"
  run_root launchctl print "$LABEL" 2>&1 || true

  info "Helper process list:"
  pgrep -lf edamame_helper 2>&1 || true

  shopt -s nullglob
  helper_logs=("$HELPER_ROOT"/edamame_helper_* "$LOG_DIR"/edamame_helper_*)
  if ((${#helper_logs[@]} > 0)); then
    info "Helper log output:"
    cat "${helper_logs[@]}" 2>&1 || true
  fi

  info "Recent unified logs:"
  run_root log show --style compact --last 2m --predicate 'process == "edamame_helper"' 2>&1 || true
}

fail() {
  echo "[ERROR] $1" >&2
  dump_diagnostics
  exit 1
}

verify_structure() {
  info "Checking installed helper bundle layout..."

  [ -d "$BUNDLE_PATH" ] || fail "Helper bundle missing at $BUNDLE_PATH"
  [ -d "$CONTENTS_DIR/MacOS" ] || fail "Bundle executable directory missing"
  [ -f "$EXECUTABLE_PATH" ] || fail "Bundled helper executable missing"
  [ -f "$PROFILE_PATH" ] || fail "Embedded provisioning profile missing"
  [ -f "$UNINSTALL_PATH" ] || fail "Helper uninstall script missing"
  [ -f "$PLIST_PATH" ] || fail "LaunchDaemon plist missing"

  if [ -e "$LEGACY_PROFILE" ]; then
    fail "Legacy provisioning profile path still populated at $LEGACY_PROFILE"
  fi

  if ! grep -qF "$EXECUTABLE_PATH" "$PLIST_PATH"; then
    fail "LaunchDaemon plist does not point to bundled helper executable"
  fi

  if ! codesign --verify --strict --verbose=2 "$EXECUTABLE_PATH"; then
    fail "codesign verification failed for bundled helper executable"
  fi

  if ! codesign -d --entitlements :- "$EXECUTABLE_PATH" 2>/dev/null | grep -q "com.apple.developer.endpoint-security.client"; then
    fail "Bundled helper is missing the Endpoint Security entitlement"
  fi

  decoded_profile=$(mktemp /tmp/edamame-helper-profile-XXXXXX.plist)
  security cms -D -i "$PROFILE_PATH" > "$decoded_profile"

  if ! /usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.endpoint-security.client" "$decoded_profile" 2>/dev/null | grep -qx "true"; then
    rm -f "$decoded_profile"
    fail "Embedded provisioning profile does not authorize Endpoint Security"
  fi

  if ! grep -q "com.edamametechnologies.edamame-helper" "$decoded_profile"; then
    rm -f "$decoded_profile"
    fail "Embedded provisioning profile does not match the helper identifier"
  fi

  rm -f "$decoded_profile"
  info "Static helper bundle verification passed"
}

verify_launch() {
  info "Checking launchd startup for helper..."

  run_root launchctl kickstart -k "$LABEL" 2>/dev/null || true

  for _ in $(seq 1 30); do
    if pgrep -lf "$EXECUTABLE_PATH" >/dev/null 2>&1 || pgrep -lf "[e]damame_helper" >/dev/null 2>&1; then
      info "Helper process is running"
      pgrep -lf "[e]damame_helper" 2>&1 || true
      run_root launchctl print "$LABEL" 2>&1 || true
      return 0
    fi
    sleep 2
  done

  fail "Helper process did not start under launchd"
}

case "$MODE" in
  structure)
    verify_structure
    ;;
  launch)
    verify_launch
    ;;
  all)
    verify_structure
    verify_launch
    ;;
esac
