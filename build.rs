use vergen_gitcl::*;

#[cfg(target_os = "windows")]
use flodbadd::windows_npcap;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Windows-specific linking/runtime assistance
    #[cfg(target_os = "windows")]
    configure_npcap_for_windows();

    // Emit the instructions
    let build = BuildBuilder::all_build()?;
    let cargo = CargoBuilder::all_cargo()?;
    let gitcl = GitclBuilder::all_git()?;
    let rustc = RustcBuilder::all_rustc()?;
    let si = SysinfoBuilder::all_sysinfo()?;

    match Emitter::default()
        .add_instructions(&build)?
        .add_instructions(&cargo)?
        .add_instructions(&gitcl)?
        .add_instructions(&rustc)?
        .add_instructions(&si)?
        .emit()
    {
        Ok(_) => (),
        Err(e) => {
            eprintln!("Error emitting: {}", e);
            panic!("Error emitting: {}", e);
        }
    }

    Ok(())
}

#[cfg(target_os = "windows")]
fn configure_npcap_for_windows() {
    use std::env;
    const LIB_ENV: &str = "DEP_FLODBADD_NPCAP_NPCAP_LIB_DIR";
    const RUNTIME_ENV: &str = "DEP_FLODBADD_NPCAP_NPCAP_RUNTIME_DIR";

    let mut sdk_path_available = false;

    if let Ok(lib_dir) = env::var(LIB_ENV) {
        println!("cargo:rustc-link-search=native={lib_dir}");
        sdk_path_available = true;
    } else {
        println!(
            "cargo:warning=Npcap SDK library path missing ({}). wpcap.lib may be unresolved.",
            LIB_ENV
        );
    }

    if let Ok(runtime_dir) = env::var(RUNTIME_ENV) {
        println!("cargo:rustc-link-search=native={runtime_dir}");
        println!("cargo:rustc-env=NPCAP_DLL_PATH={runtime_dir}");
    }

    #[cfg(target_env = "msvc")]
    {
        println!("cargo:rustc-link-arg=/DELAYLOAD:wpcap.dll");
        println!("cargo:rustc-link-arg=/DELAYLOAD:Packet.dll");
        println!("cargo:rustc-link-lib=dylib=delayimp");
    }

    let npcap_dir = windows_npcap::get_npcap_dir();
    if npcap_dir.exists() {
        let _ = windows_npcap::copy_npcap_dlls_next_to_binaries();
        println!("cargo:rustc-link-search=native={}", npcap_dir.display());
        if env::var(RUNTIME_ENV).is_err() {
            println!("cargo:rustc-env=NPCAP_DLL_PATH={}", npcap_dir.display());
        }
    } else if !sdk_path_available {
        println!("cargo:warning=Npcap runtime not found; packet capture features will be disabled.");
    }
}
