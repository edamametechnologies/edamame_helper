use vergen::EmitBuilder;

fn main() {
    // Emit the instructions
    let _ = EmitBuilder::builder()
        .all_build()
        .all_git()
        .all_sysinfo()
        .emit();
}
