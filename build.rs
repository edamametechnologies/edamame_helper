use vergen_gitcl::{Build, Cargo, Emitter, Gitcl, Rustc, Sysinfo};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Windows-specific linking/runtime assistance
    #[cfg(target_os = "windows")]
    flodbadd::windows_npcap::configure_build_linking_from_metadata();

    // Emit the instructions with idempotent() for cross-compilation support
    let build = Build::all_build();
    let cargo = Cargo::all_cargo();
    let gitcl = Gitcl::all_git();
    let rustc = Rustc::all_rustc();
    let si = Sysinfo::all_sysinfo();

    Emitter::default()
        .idempotent()
        .add_instructions(&build)?
        .add_instructions(&cargo)?
        .add_instructions(&gitcl)?
        .add_instructions(&rustc)?
        .add_instructions(&si)?
        .emit()?;

    Ok(())
}
