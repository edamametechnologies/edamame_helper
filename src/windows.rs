use crate::server::{start_server, stop_server};
use lazy_static::lazy_static;
use std::sync::Arc;
use std::sync::Mutex;
use std::{ffi::OsString, time::Duration};
use windows_service::{
    define_windows_service,
    service::{
        ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
        ServiceType,
    },
    service_control_handler::{self, ServiceControlHandlerResult},
    service_dispatcher, Result,
};

const SERVICE_NAME: &str = "edamame_helper";
const SERVICE_TYPE: ServiceType = ServiceType::OWN_PROCESS;

lazy_static! {
    static ref BRANCH: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    static ref URL: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    static ref RELEASE: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    static ref INFO_STRING: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
}

pub fn run(branch: &str, url: &str, release: &str, info_string: &str) -> Result<()> {
    // Store the params
    BRANCH.lock().unwrap().push_str(branch);
    URL.lock().unwrap().push_str(url);
    RELEASE.lock().unwrap().push_str(release);
    INFO_STRING.lock().unwrap().push_str(info_string);

    // Register generated `ffi_service_main` with the system and start the service, blocking
    // this thread until the service is stopped.
    service_dispatcher::start(SERVICE_NAME, ffi_service_main)
}

// Generate the windows service boilerplate.
// The boilerplate contains the low-level service entry function (ffi_service_main) that parses
// incoming service arguments into Vec<OsString> and passes them to user defined service
// entry (my_service_main).
define_windows_service!(ffi_service_main, my_service_main);

// Service entry function which is called on background thread by the system with service
// parameters. There is no stdout or stderr at this point so make sure to configure the log
// output to file if needed.
pub fn my_service_main(_arguments: Vec<OsString>) {
    let branch = BRANCH.lock().unwrap().clone();
    let url = URL.lock().unwrap().clone();
    let release = RELEASE.lock().unwrap().clone();
    let info_string = INFO_STRING.lock().unwrap().clone();
    if let Err(_e) = run_service(&branch, &url, &release, &info_string) {
        // Handle the error, by logging or something.
    }
}

pub fn run_service(branch: &str, url: &str, release: &str, info_string: &str) -> Result<()> {
    // Define system service event handler that will be receiving service events.
    let event_handler = move |control_event| -> ServiceControlHandlerResult {
        match control_event {
            // Notifies a service to report its current status information to the service
            // control manager. Always return NoError even if not implemented.
            ServiceControl::Interrogate => ServiceControlHandlerResult::NoError,

            // Handle stop
            ServiceControl::Stop => {
                // Stop the server
                stop_server();

                ServiceControlHandlerResult::NoError
            }

            _ => ServiceControlHandlerResult::NotImplemented,
        }
    };

    // Register system service event handler.
    // The returned status handle should be used to report service status changes to the system.
    let status_handle = service_control_handler::register(SERVICE_NAME, event_handler)?;

    // Tell the system that service is running
    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Running,
        controls_accepted: ServiceControlAccept::STOP,
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    // Launch service, returns only when stopped
    start_server(branch, url, release, info_string);

    // Tell the system that service has stopped.
    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Stopped,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    Ok(())
}
