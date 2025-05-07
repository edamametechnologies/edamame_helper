use edamame_foundation::helper_rx::*;
use edamame_foundation::helper_rx_utility::*;
use edamame_foundation::lanscan::mdns::*;
use edamame_foundation::logger::*;
use edamame_foundation::runtime::*;
use envcrypt::envc;
use lazy_static::lazy_static;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{error, info};

lazy_static! {
    static ref SERVER_CONTROL: Arc<Mutex<ServerControl>> =
        Arc::new(Mutex::new(ServerControl::new()));
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
    init_logger("helper", url, release, "", &[]);
    info!("{}", info_string);

    // Must be after sentry
    async_init();

    // mDNS discovery
    async_exec(async { mdns_start().await });

    // Interface monitor
    start_interface_monitor();

    let branch = branch.to_string();
    async_exec(async move {
        // RPC server
        match SERVER_CONTROL
            .lock()
            .await
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

    async_exec(async {
        match SERVER_CONTROL.lock().await.stop_server().await {
            Ok(_) => info!("Server stopped"),
            Err(e) => error!("Server stop error: {}", e),
        }
    });
}
