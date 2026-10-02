use edamame_foundation::helper_rx::*;
use edamame_foundation::helper_rx_utility::*;
use edamame_foundation::logger::*;
use envcrypt::envc;
use flodbadd::mdns::*;
use lazy_static::lazy_static;
use tracing::{error, info};

// This server runs threat-model scripts as root / SYSTEM from the helper's
// own copy of the model: it must load only models an Ed25519-signed manifest
// covers. The app reads a helper at or above
// FIRST_VERIFYING_HELPER_VERSION as a verifying one and warns about an older
// helper; a build without the feature would break that silently.
const _: () = assert!(
    edamame_foundation::model_authenticity::ENFORCED,
    "edamame_helper must be built with edamame_foundation's model-signatures feature (Cargo.toml)"
);

lazy_static! {
    // No lock around it: `start_server` borrows it for as long as the server
    // runs, and the Windows Stop control must reach `stop_server` meanwhile.
    // Behind a mutex the serving call held the guard, the stop waited for it,
    // and a stop through the SCM never completed.
    static ref SERVER_CONTROL: ServerControl = ServerControl::new();
}

lazy_static! {
    pub static ref EDAMAME_HELPER_SENTRY: String = envc!("EDAMAME_HELPER_SENTRY").to_string();
    pub static ref EDAMAME_SERVER: String = envc!("EDAMAME_SERVER").trim_matches('"').to_string();
    pub static ref EDAMAME_SERVER_PEM: String =
        envc!("EDAMAME_SERVER_PEM").trim_matches('"').to_string();
    pub static ref EDAMAME_SERVER_KEY: String =
        envc!("EDAMAME_SERVER_KEY").trim_matches('"').to_string();
    pub static ref EDAMAME_CLIENT_CA_PEM: String =
        envc!("EDAMAME_CLIENT_CA_PEM").trim_matches('"').to_string();
}

pub fn start_server(branch: &str, url: &str, release: &str, info_string: &str) {
    // The helper runs as root / SYSTEM and cannot read the user's settings:
    // it sends nothing to Sentry until the app's core tells it the user's
    // crash-report setting (`set_error_reporting` utility order, 2.0.3).
    init_logger("helper", url, release, "", &[]);
    info!("{}", info_string);

    // Must be after sentry
    edamame_foundation::runtime::init();

    // mDNS discovery
    edamame_foundation::runtime::block_on(async { mdns_start().await });

    // Interface monitor
    start_interface_monitor();

    let branch = branch.to_string();
    edamame_foundation::runtime::block_on(async move {
        // RPC server
        match SERVER_CONTROL
            .start_server(
                &EDAMAME_SERVER_PEM,
                &EDAMAME_SERVER_KEY,
                &EDAMAME_CLIENT_CA_PEM,
                &EDAMAME_SERVER,
                &branch,
            )
            .await
        {
            Ok(_) => info!("Server started"),
            Err(e) => error!("Server start error: {}", e),
        }
    });
}

#[cfg(target_os = "windows")]
pub fn stop_server() {
    mdns_stop();

    // Bounded by a wall-clock budget, not a tokio timer: a service stop that
    // waited on a wedged runtime would hold the Windows service in
    // STOP_PENDING indefinitely (same class as the 2026-09-28 posture hang).
    edamame_foundation::runtime::block_on(async {
        let stop = async {
            match SERVER_CONTROL.stop_server().await {
                Ok(_) => info!("Server stopped"),
                Err(e) => error!("Server stop error: {}", e),
            }
        };
        if edamame_foundation::runtime::wall_clock_timeout(std::time::Duration::from_secs(15), stop)
            .await
            .is_err()
        {
            error!("Server stop did not complete within 15s; continuing the service stop");
        }
    });
}
