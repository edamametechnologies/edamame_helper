# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EDAMAME Helper is a privileged daemon/service that extends the EDAMAME Security application with elevated capabilities. It executes security checks requiring admin/root access, performs remediation actions, and communicates with the main app via gRPC.

Part of the EDAMAME ecosystem - see `../edamame_core/CLAUDE.md` for full ecosystem documentation.

## Build Commands

```bash
# Debug build
cargo build

# Release build
cargo build --release

# macOS universal binary + package
cargo build --release --target x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin
# Then: lipo -create ... && ./macos/make-pkg.sh

# Windows MSI
cargo build --release
cargo wix --nocapture --no-build

# Run (requires privileges)
sudo ./target/release/edamame_helper
```

## Testing

```bash
make test  # Runs cargo test
```

CI runs on macOS and Windows with code signing and installer validation.

## Architecture

### Source Files
- `main.rs` - Entry point with platform-specific configurations
- `server.rs` - gRPC server and mDNS discovery initialization
- `windows.rs` - Windows Service integration

### Platform Behavior
- **Windows (Release)**: Runs as Windows Service via `windows_service` crate
- **Windows (Debug)**: Direct executable mode
- **macOS/Linux**: Standard daemon via `start_server()`

### Key Components
- gRPC server for IPC with main application
- mDNS discovery for network services
- TLS certificate configuration from environment variables

### macOS Installation
Installed as LaunchDaemon:
- Label: `com.edamametechnologies.edamame-helper`
- Location: `/Library/Application Support/EDAMAME/EDAMAME-Helper/edamame_helper`
- Logs: `/var/log/edamame_helper.log`

## Dependencies

- `edamame_foundation` - Core security functionality
- `flodbadd` - Packet capture utilities
- `tonic` + `prost` - gRPC
- `tokio` - Async runtime
- `windows-service` - Windows Service integration

## Environment Variables

- `EDAMAME_HELPER_SENTRY` - Error tracking
- `EDAMAME_SERVER`, `EDAMAME_SERVER_PEM`, `EDAMAME_SERVER_KEY` - TLS config
- `EDAMAME_CLIENT_CA_PEM` - Client certificate authority

## Local Development

Use `../edamame_app/flip.sh local` to switch to local path dependencies.
