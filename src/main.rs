mod server;
#[cfg(target_os = "windows")]
mod windows;
#[cfg(not(target_os = "windows"))]
use crate::server::start_server;
#[cfg(all(target_os = "windows", debug_assertions))]
use crate::server::start_server;
use edamame_foundation::version::FOUNDATION_VERSION;
use envcrypt::envc;

#[cfg(all(target_os = "windows", not(debug_assertions)))]
fn main() -> windows_service::Result<()> {
    let url = envc!("EDAMAME_HELPER_SENTRY");
    // Needs to be gathered within the target executable's crate
    let release = env!("CARGO_PKG_VERSION");
    let branch = envc!("VERGEN_GIT_BRANCH");
    let info_string = format!(
        "Helper has version {}, is using Foundation version {} and has been built on {} with branch {} and signature {} on {} by {}",
        env!("CARGO_PKG_VERSION"),
        FOUNDATION_VERSION,
        envc!("VERGEN_BUILD_TIMESTAMP"),
        branch,
        envc!("VERGEN_GIT_SHA"),
        envc!("VERGEN_SYSINFO_OS_VERSION"),
        envc!("VERGEN_SYSINFO_USER")
    );
    windows::run(branch, url, release, &info_string)
}

#[cfg(all(target_os = "windows", debug_assertions))]
fn main() {
    let url = envc!("EDAMAME_HELPER_SENTRY");
    // Needs to be gathered within the target executable's crate
    let release = env!("CARGO_PKG_VERSION");
    let branch = envc!("VERGEN_GIT_BRANCH");
    let info_string = format!(
        "Helper has version {}, is using Foundation version {} and has been built on {} with branch {} and signature {} on {} by {}",
        env!("CARGO_PKG_VERSION"),
        FOUNDATION_VERSION,
        envc!("VERGEN_BUILD_TIMESTAMP"),
        envc!("VERGEN_GIT_BRANCH"),
        envc!("VERGEN_GIT_SHA"),
        envc!("VERGEN_SYSINFO_OS_VERSION"),
        envc!("VERGEN_SYSINFO_USER")
    );
    start_server(branch, url, release, &info_string);
}

#[cfg(not(target_os = "windows"))]
fn main() {
    let url = envc!("EDAMAME_HELPER_SENTRY");
    // Needs to be gathered within the target executable's crate
    let release = env!("CARGO_PKG_VERSION");
    let branch = envc!("VERGEN_GIT_BRANCH");
    let info_string = format!(
        "Helper has version {}, is using Foundation version {} and has been built on {} with branch {} and signature {} on {} by {}",
        env!("CARGO_PKG_VERSION"),
        FOUNDATION_VERSION,
        envc!("VERGEN_BUILD_TIMESTAMP"),
        envc!("VERGEN_GIT_BRANCH"),
        envc!("VERGEN_GIT_SHA"),
        envc!("VERGEN_SYSINFO_OS_VERSION"),
        envc!("VERGEN_SYSINFO_USER")
    );
    start_server(branch, url, release, &info_string);
}
