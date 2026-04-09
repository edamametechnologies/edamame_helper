// Endpoint Security entitlement validation for the helper daemon.
//
// These tests verify that the helper binary, when codesigned with
// com.apple.developer.endpoint-security.client and running as root,
// can successfully create an ES client and receive kernel events.
//
// Run via: make macos_es_test
// Or manually:
//   cargo test --test es_entitlement_test --no-run
//   codesign --force --sign - --entitlements ./macos/edamame_helper.entitlements target/debug/deps/es_entitlement_test-*
//   sudo -E target/debug/deps/es_entitlement_test-* --nocapture
#![cfg(target_os = "macos")]

use flodbadd::l7_es;
use std::time::Duration;

fn is_root() -> bool {
    std::process::Command::new("id")
        .arg("-u")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim() == "0")
        .unwrap_or(false)
}

fn binary_has_es_entitlement() -> bool {
    let exe = std::env::current_exe().unwrap_or_default();
    std::process::Command::new("codesign")
        .args(["-d", "--entitlements", "-"])
        .arg(&exe)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.contains("endpoint-security.client"))
        .unwrap_or(false)
}

#[test]
fn es_client_initializes() {
    if !is_root() {
        eprintln!("SKIP: es_client_initializes requires root (run via `make macos_es_test`)");
        return;
    }

    l7_es::init_and_log_status();

    let available = l7_es::is_available();
    let support = l7_es::es_support();
    let has_entitlement = binary_has_es_entitlement();

    eprintln!("ES available:    {}", available);
    eprintln!("ES support:      {}", support);
    eprintln!("ES entitlement:  {}", has_entitlement);

    if !has_entitlement {
        eprintln!(
            "SKIP: binary not signed with ES entitlement (SIP enabled + no Developer ID cert). \
             ES validation will run in CI."
        );
        return;
    }

    assert!(
        available,
        "ES client failed to initialize despite having entitlement. Status: {}",
        support
    );
}

#[test]
fn es_receives_process_events() {
    if !is_root() {
        eprintln!("SKIP: es_receives_process_events requires root (run via `make macos_es_test`)");
        return;
    }

    l7_es::init_and_log_status();

    if !l7_es::is_available() {
        eprintln!("SKIP: ES not available (not entitled or not root)");
        return;
    }

    // Wait for the process table to populate from system FORK/EXEC events
    std::thread::sleep(Duration::from_secs(2));

    let count = l7_es::process_count();
    eprintln!("ES process table: {} entries", count);

    assert!(
        count > 0,
        "ES initialized but process table is empty after 2s -- \
         FORK/EXEC/EXIT events not being delivered"
    );
}

#[test]
fn es_receives_file_events() {
    if !is_root() {
        eprintln!("SKIP: es_receives_file_events requires root (run via `make macos_es_test`)");
        return;
    }

    l7_es::init_and_log_status();

    if !l7_es::is_available() {
        eprintln!("SKIP: ES not available (not entitled or not root)");
        return;
    }

    // Wait for some file events to accumulate from normal system activity
    std::thread::sleep(Duration::from_secs(3));

    let (cr, _cds, _cdn, clr, _clm, rn, ul, _oth) = l7_es::file_event_stats();
    let total_file_events = cr + clr + rn + ul;

    eprintln!(
        "ES file events: create={} close={} rename={} unlink={} total={}",
        cr, clr, rn, ul, total_file_events
    );

    assert!(
        total_file_events > 0,
        "ES initialized but no file events received after 3s -- \
         CREATE/CLOSE/RENAME/UNLINK subscription may have failed"
    );

    let file_table_size = l7_es::file_attribution_count();
    eprintln!("ES file attribution table: {} entries", file_table_size);

    assert!(
        file_table_size > 0,
        "ES received file events but attribution table is empty -- \
         file attribution recording may be broken"
    );
}
