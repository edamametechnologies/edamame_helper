use vergen_gitcl::{Build, Cargo, Emitter, Gitcl, Rustc};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Windows-specific linking/runtime assistance
    #[cfg(target_os = "windows")]
    flodbadd::windows_npcap::configure_build_linking_from_metadata();

    // Emit the instructions (vergen-gitcl 10.x API)
    // Try without idempotent first to get real values on native builds.
    // Fall back to idempotent mode only if it fails (e.g., no git metadata).
    // No vergen sysinfo instructions: they refresh every process on the build
    // host (sysinfo's System::new_all), the enumeration the Windows CI
    // detection gates flag. The helper's info string takes the build host from
    // VERGEN_RUSTC_HOST_TRIPLE and the build user from EDAMAME_BUILD_USER below.
    let build = Build::all_build();
    let cargo = Cargo::all_cargo();
    let gitcl = Gitcl::all_git();
    let rustc = Rustc::all_rustc();

    if Emitter::default()
        .add_instructions(&build)?
        .add_instructions(&cargo)?
        .add_instructions(&gitcl)?
        .add_instructions(&rustc)?
        .emit()
        .is_err()
    {
        eprintln!(
            "cargo:warning=vergen failed to collect build metadata, using idempotent defaults"
        );
        Emitter::default()
            .idempotent()
            .add_instructions(&build)?
            .add_instructions(&cargo)?
            .add_instructions(&gitcl)?
            .add_instructions(&rustc)?
            .emit()?;
    }

    // The account that ran the build, from the environment.
    println!("cargo:rerun-if-env-changed=USER");
    println!("cargo:rerun-if-env-changed=USERNAME");
    let user = std::env::var("USER")
        .or_else(|_| std::env::var("USERNAME"))
        .unwrap_or_else(|_| "unknown".to_string());
    println!("cargo:rustc-env=EDAMAME_BUILD_USER={}", user);

    Ok(())
}
