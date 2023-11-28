use log::{error, info};
// For objects
use lazy_static::lazy_static;
use std::sync::Arc;
use tokio::sync::Mutex;

use edamame_foundation::runtime::*;
use edamame_foundation::threat::*;
use edamame_foundation::logger::*;
use edamame_foundation::lanscan_mdns::*;
use edamame_foundation::helper_rx::*;
use edamame_foundation::foundation::FOUNDATION_VERSION;

lazy_static! {
    // This is our local copy of the threats
    static ref THREATS: Arc<Mutex<ThreatMetrics>> = Arc::new(Mutex::new(ThreatMetrics::new("")));
    static ref SERVER_CONTROL: Arc<Mutex<ServerControl>> =  Arc::new(Mutex::new(ServerControl::new()));
}

pub static EDAMAME_HELPER_SENTRY: &str = env!("EDAMAME_HELPER_SENTRY");

pub static EDAMAME_SERVER: &str = env!("EDAMAME_SERVER");
pub static EDAMAME_SERVER_PEM: &str = env!("EDAMAME_SERVER_PEM");
pub static EDAMAME_SERVER_KEY: &str = env!("EDAMAME_SERVER_KEY");
pub static EDAMAME_CLIENT_CA_PEM: &str = env!("EDAMAME_CLIENT_CA_PEM");

// Return a string with the helper info
pub fn get_helper_info() -> String {
    format!(
        "Helper is using Foundation version is {} and has been built on {} with branch {} and signature {} on {} by {}",
        FOUNDATION_VERSION,
        env!("VERGEN_BUILD_TIMESTAMP"),
        env!("VERGEN_GIT_BRANCH"),
        env!("VERGEN_GIT_SHA"),
        env!("VERGEN_SYSINFO_OS_VERSION"),
        env!("VERGEN_SYSINFO_USER")
    )
}

pub fn start_server() {

    init_helper_logger();
    info!("Logger initialized");

    info!("{}", get_helper_info());

    // Init sentry
    let sentry = sentry::init((EDAMAME_HELPER_SENTRY, sentry::ClientOptions {
        release: sentry::release_name!(),
        traces_sample_rate: 1.0,
        ..Default::default()
    }));

    if sentry.is_enabled() {
        info!("Sentry initialized");
    } else {
        error!("Sentry initialization failed");
    }
    // Forget the sentry object to prevent it from being dropped
    std::mem::forget(sentry);

    async_init();

    // mDNS discovery
    async_exec(async {
        mdns_start().await
    });

    // Branch (needs to be gathered within the target executable's crate)
    let branch = env!("VERGEN_GIT_BRANCH");

    // RPC server
    async_exec(async {

        match SERVER_CONTROL.lock().await.start_server(EDAMAME_SERVER_PEM, EDAMAME_SERVER_KEY, EDAMAME_CLIENT_CA_PEM, EDAMAME_SERVER, branch).await {
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


