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
EXECUTABLE_PATH="$HELPER_ROOT/edamame_helper"
UNINSTALL_PATH="$HELPER_ROOT/uninstall.sh"
PLIST_PATH="/Library/LaunchDaemons/com.edamametechnologies.edamame-helper.plist"
PROFILE_PATH="/Library/MobileDevice/Provisioning Profiles/EDAMAME_Helper.provisionprofile"
LABEL="system/com.edamametechnologies.edamame-helper"

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
  info "Helper root listing:"
  ls -la "$HELPER_ROOT" 2>&1 || true

  info "LaunchDaemon listing:"
  ls -la /Library/LaunchDaemons 2>&1 || true

  info "LaunchDaemon plist:"
  run_root plutil -p "$PLIST_PATH" 2>&1 || true

  info "LaunchDaemon state:"
  run_root launchctl print "$LABEL" 2>&1 || true

  info "Helper process list:"
  pgrep -lf edamame_helper 2>&1 || true

  shopt -s nullglob
  helper_logs=("$HELPER_ROOT"/edamame_helper* /var/log/edamame_helper*)
  if ((${#helper_logs[@]} > 0)); then
    info "Helper log output:"
    for log_path in "${helper_logs[@]}"; do
      echo "[LOG] $log_path"
      sed -n '1,200p' "$log_path" 2>&1 || true
    done
  fi

  info "Recent unified logs:"
  run_root log show --style compact --last 5m --predicate 'process == "edamame_helper"' 2>&1 || true
}

fail() {
  echo "[ERROR] $1" >&2
  dump_diagnostics
  exit 1
}

verify_structure() {
  info "Checking installed helper layout..."

  [ -d "$HELPER_ROOT" ] || fail "Helper root missing at $HELPER_ROOT"
  [ -f "$EXECUTABLE_PATH" ] || fail "Helper executable missing at $EXECUTABLE_PATH"
  [ -f "$UNINSTALL_PATH" ] || fail "Helper uninstall script missing at $UNINSTALL_PATH"
  [ -f "$PLIST_PATH" ] || fail "LaunchDaemon plist missing at $PLIST_PATH"
  [ -f "$PROFILE_PATH" ] || fail "Provisioning profile missing at $PROFILE_PATH"

  if ! grep -qF "$EXECUTABLE_PATH" "$PLIST_PATH"; then
    fail "LaunchDaemon plist does not point to the installed helper executable"
  fi

  if ! codesign --verify --strict --verbose=2 "$EXECUTABLE_PATH"; then
    fail "codesign verification failed for installed helper executable"
  fi

  if ! codesign -d --entitlements :- "$EXECUTABLE_PATH" 2>/dev/null | grep -q "com.apple.developer.endpoint-security.client"; then
    fail "Installed helper is missing the Endpoint Security entitlement"
  fi

  decoded_profile=$(mktemp /tmp/edamame-helper-profile-XXXXXX.plist)
  security cms -D -i "$PROFILE_PATH" > "$decoded_profile"

  if ! /usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.endpoint-security.client" "$decoded_profile" 2>/dev/null | grep -qx "true"; then
    rm -f "$decoded_profile"
    fail "Installed provisioning profile does not authorize Endpoint Security"
  fi

  if ! grep -q "com.edamametechnologies.edamame-helper" "$decoded_profile"; then
    rm -f "$decoded_profile"
    fail "Provisioning profile does not match the helper identifier"
  fi

  rm -f "$decoded_profile"
  info "Static helper verification passed"
}

start_helper() {
  run_root launchctl print "$LABEL" >/dev/null 2>&1 || true
  run_root launchctl kickstart -k "$LABEL" 2>/dev/null || true

  if ! pgrep -lf "[e]damame_helper" >/dev/null 2>&1; then
    run_root launchctl bootstrap system "$PLIST_PATH" 2>/dev/null || true
    run_root launchctl enable "$LABEL" 2>/dev/null || true
    run_root launchctl kickstart -k "$LABEL" 2>/dev/null || true
  fi
}

verify_launch() {
  info "Checking launchd startup for helper..."

  start_helper

  for _ in $(seq 1 30); do
    if pgrep -lf "[e]damame_helper" >/dev/null 2>&1; then
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
