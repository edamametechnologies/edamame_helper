mod server;
#[cfg(target_os = "windows")]
mod windows;

#[cfg(target_os = "windows")]
fn main() -> windows_service::Result<()> {
    windows::run()
}

#[cfg(not(target_os = "windows"))]
fn main() {
    server::start_server();
}
