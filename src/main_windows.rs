use crate::{start_server, stop_server};

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

pub fn run() -> Result<()> {
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
    if let Err(_e) = run_service() {
        // Handle the error, by logging or something.
    }
}

pub fn run_service() -> Result<()> {
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
    start_server();

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
