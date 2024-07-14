use tracing::{error, info};
// For objects
use envcrypt::envc;
use lazy_static::lazy_static;
use std::sync::Arc;
use tokio::sync::Mutex;

use edamame_foundation::foundation::FOUNDATION_VERSION;
use edamame_foundation::helper_rx::*;
use edamame_foundation::lanscan_mdns::*;
use edamame_foundation::logger::*;
use edamame_foundation::runtime::*;
use edamame_foundation::threat::*;

lazy_static! {
    // This is our local copy of the threats
    static ref THREATS: Arc<Mutex<ThreatMetrics>> = Arc::new(Mutex::new(ThreatMetrics::new("")));
    static ref SERVER_CONTROL: Arc<Mutex<ServerControl>> =  Arc::new(Mutex::new(ServerControl::new()));
}

lazy_static! {
    pub static ref EDAMAME_HELPER_SENTRY: String = envc!("EDAMAME_HELPER_SENTRY").to_string();
    pub static ref EDAMAME_SERVER: String = envc!("EDAMAME_SERVER").to_string();
    pub static ref EDAMAME_SERVER_PEM: String = envc!("EDAMAME_SERVER_PEM").to_string();
    pub static ref EDAMAME_SERVER_KEY: String = envc!("EDAMAME_SERVER_KEY").to_string();
    pub static ref EDAMAME_CLIENT_CA_PEM: String = envc!("EDAMAME_CLIENT_CA_PEM").to_string();
}

// Return a string with the helper info
pub fn get_helper_info() -> String {
    format!(
        "Helper has version {}, is using Foundation version {} and has been built on {} with branch {} and signature {} on {} by {}",
        env!("CARGO_PKG_VERSION"),
        FOUNDATION_VERSION,
        envc!("VERGEN_BUILD_TIMESTAMP"),
        envc!("VERGEN_GIT_BRANCH"),
        envc!("VERGEN_GIT_SHA"),
        envc!("VERGEN_SYSINFO_OS_VERSION"),
        envc!("VERGEN_SYSINFO_USER")
    )
}

pub fn start_server() {
    let url = envc!("EDAMAME_HELPER_SENTRY");
    let release = envc!("CARGO_PKG_VERSION");

    init_logger("helper", url, release);
    info!("{}", get_helper_info());

    // Must be after sentry
    async_init();

    // mDNS discovery
    async_exec(async { mdns_start().await });

    // Branch (needs to be gathered within the target executable's crate)
    let branch = envc!("VERGEN_GIT_BRANCH");

    // RPC server
    async_exec(async {
        match SERVER_CONTROL
            .lock()
            .await
            .start_server(
                &EDAMAME_SERVER_PEM,
                &EDAMAME_SERVER_KEY,
                &EDAMAME_CLIENT_CA_PEM,
                &EDAMAME_SERVER,
                branch,
            )
            .await
        {
            Ok(_) => info!("Server started"),
            Err(e) => error!("Server start error: {}", e),
        }
    });
}

pub fn stop_server() {
    mdns_stop();

    async_exec(async {
        match SERVER_CONTROL.lock().await.stop_server().await {
            Ok(_) => info!("Server stopped"),
            Err(e) => error!("Server stop error: {}", e),
        }
    });
}

// Only macOS
#[cfg(target_os = "macos")]
#[no_mangle]
pub extern "C" fn rust_main() {
    start_server();
}
