use vergen_gitcl::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Windows-specific linking/runtime assistance
    #[cfg(target_os = "windows")]
    npcap_link::configure();

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
mod npcap_link {
    use std::env;
    use std::fs;
    use std::path::{Path, PathBuf};

    const LIB_ENV: &str = "DEP_FLODBADD_NPCAP_NPCAP_LIB_DIR";
    const RUNTIME_ENV: &str = "DEP_FLODBADD_NPCAP_NPCAP_RUNTIME_DIR";

    pub fn configure() {
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

        let npcap_dir = get_npcap_dir();
        if npcap_dir.exists() {
            let _ = copy_npcap_runtime_dlls(&npcap_dir);
            println!("cargo:rustc-link-search=native={}", npcap_dir.display());
            if env::var(RUNTIME_ENV).is_err() {
                println!("cargo:rustc-env=NPCAP_DLL_PATH={}", npcap_dir.display());
            }
        } else if !sdk_path_available {
            println!(
                "cargo:warning=Npcap runtime not found; packet capture features will be disabled."
            );
        }
    }

    fn get_npcap_dir() -> PathBuf {
        let system_root = env::var("SystemRoot").unwrap_or_else(|_| "C:\\Windows".to_string());
        let candidates = [
            Path::new(&system_root).join("System32").join("Npcap"),
            Path::new(&system_root).join("SysWOW64").join("Npcap"),
            Path::new(&system_root).join("Sysnative").join("Npcap"),
            Path::new(&system_root).join("System32"),
            Path::new(&system_root).join("SysWOW64"),
        ];
        for dir in candidates {
            let wpcap = dir.join("wpcap.dll");
            let packet = dir.join("Packet.dll");
            if wpcap.is_file() && packet.is_file() {
                return dir;
            }
        }
        Path::new(&system_root).join("System32").join("Npcap")
    }

    fn copy_npcap_runtime_dlls(npcap_runtime: &Path) -> Result<(), String> {
        let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
        let profile = env::var("PROFILE").unwrap_or_else(|_| "debug".to_string());
        let target_dir = env::var("CARGO_TARGET_DIR")
            .unwrap_or_else(|_| format!("{}{}target", manifest_dir, std::path::MAIN_SEPARATOR));

        let profile_dir = Path::new(&target_dir).join(&profile);
        let deps_dir = profile_dir.join("deps");

        let wpcap = npcap_runtime.join("wpcap.dll");
        let packet = npcap_runtime.join("Packet.dll");
        if !wpcap.is_file() || !packet.is_file() {
            return Err("Npcap runtime DLLs not found".into());
        }

        fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
        fs::create_dir_all(&deps_dir).map_err(|e| e.to_string())?;

        let targets = [
            profile_dir.join("wpcap.dll"),
            profile_dir.join("Packet.dll"),
            deps_dir.join("wpcap.dll"),
            deps_dir.join("Packet.dll"),
        ];

        for dest in targets.iter() {
            let src = if dest
                .file_name()
                .unwrap()
                .to_string_lossy()
                .eq_ignore_ascii_case("wpcap.dll")
            {
                &wpcap
            } else {
                &packet
            };

            let do_copy = match (fs::metadata(dest), fs::metadata(src)) {
                (Ok(dest_meta), Ok(src_meta)) => {
                    src_meta.modified().ok() > dest_meta.modified().ok()
                }
                (Err(_), Ok(_)) => true,
                _ => true,
            };

            if do_copy {
                fs::copy(src, dest).map_err(|e| e.to_string())?;
            }
        }

        println!(
            "cargo:warning=Npcap DLLs copied to {} and {}",
            profile_dir.display(),
            deps_dir.display()
        );

        Ok(())
    }
}

#[cfg(not(target_os = "windows"))]
mod npcap_link {
    #[allow(dead_code)]
    pub fn configure() {}
}
