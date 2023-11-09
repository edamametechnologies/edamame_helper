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

pub fn start_server() {

    // Init sentry
    let _guard = sentry::init((EDAMAME_HELPER_SENTRY, sentry::ClientOptions {
        release: sentry::release_name!(),
        ..Default::default()
    }));

    init_helper_logger();
    info!("Logger initialized");

    async_init();

    // mDNS discovery
    async_exec(async {
        mdns_start().await
    });

    // RPC server
    async_exec(async {

        match SERVER_CONTROL.lock().await.start_server(EDAMAME_SERVER_PEM, EDAMAME_SERVER_KEY, EDAMAME_CLIENT_CA_PEM, EDAMAME_SERVER).await {
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


