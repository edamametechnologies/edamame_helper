# edamame_helper
This is the Helper application for the EDAMAME Security application. 
It's used to execute security checks, remediation and rollback actions that require elevated privileges beyond the application sandboxed environment.
All the actions performed through the Helper strictly follow the threat models defined in the threat model repo (https://github.com/edamametechnologies/threatmodels).
The Helper relies on edamame_foundation, an open source library that contains the foundation for EDAMAME threat management (https://github.com/edamametechnologies/edamame_foundation).

## Installation

### macOS

#### Homebrew Installation (Recommended)
```bash
# Add the EDAMAME tap
brew tap edamametechnologies/tap

# Install EDAMAME Helper
brew install --cask edamame-helper

# Verify installation
/Library/Application\ Support/EDAMAME/EDAMAME-Helper/edamame_helper --version
```

To update to the latest version:
```bash
brew upgrade --cask edamame-helper
```

#### Manual PKG Installation
Download the macOS installer from the [releases page](https://github.com/edamametechnologies/edamame_helper/releases):
- **Universal (Intel + Apple Silicon)**: `edamame-helper-macos-VERSION.pkg`

Double-click the PKG file to install, or use:
```bash
sudo installer -pkg edamame-helper-macos-VERSION.pkg -target /
```

### Windows

#### Chocolatey Installation (Recommended)
```powershell
# Install EDAMAME Helper
choco install edamame-helper

# Verify installation
edamame_helper --version
```

To update to the latest version:
```powershell
choco upgrade edamame-helper
```

#### Manual MSI Installation
Download the Windows installer from the [releases page](https://github.com/edamametechnologies/edamame_helper/releases):
- **x86_64**: `edamame-helper-windows-VERSION.msi`

Double-click the MSI file to install, or use:
```powershell
msiexec /i edamame-helper-windows-VERSION.msi /qn
```

### Linux

#### APT Repository (Debian/Ubuntu)

The EDAMAME Helper is built into the EDAMAME Posture package on Linux:

```bash
# Add the EDAMAME repository (if not already added)
wget -O - https://edamame.s3.eu-west-1.amazonaws.com/repo/public.key | sudo gpg --dearmor -o /usr/share/keyrings/edamame.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/edamame.gpg] https://edamame.s3.eu-west-1.amazonaws.com/repo stable main" | sudo tee /etc/apt/sources.list.d/edamame.list

# Update package list
sudo apt update

# Install EDAMAME Posture (CLI tool with built-in helper)
sudo apt install edamame-posture

# OR install EDAMAME Security (GUI app - uses edamame-posture which has built-in helper)
sudo apt install edamame-security
```

**Package Architecture on Linux**:
- `edamame-posture`: CLI tool with **built-in helper functionality**
- `edamame-security`: GUI app that **depends on and uses** `edamame-posture`
- No separate helper package needed - helper is integrated into `edamame-posture`

#### APK Repository (Alpine)

The EDAMAME Helper is also built into the EDAMAME Posture package on Alpine:

```bash
# Import the public key
wget -O /tmp/edamame.rsa.pub https://edamame.s3.eu-west-1.amazonaws.com/repo/alpine/v3.15/x86_64/edamame.rsa.pub
sudo cp /tmp/edamame.rsa.pub /etc/apk/keys/

# Add the repository
echo "https://edamame.s3.eu-west-1.amazonaws.com/repo/alpine/v3.15/main" | sudo tee -a /etc/apk/repositories

# Install EDAMAME Posture (includes built-in helper)
sudo apk update
sudo apk add edamame-posture
```

**Note**: On Alpine, `edamame-posture` includes the built-in helper functionality. The GUI app (`edamame-security`) is not available as an APK package.

## Overview

The edamame_helper is designed with privilege separation in mind, allowing the main EDAMAME Security application to perform operations that require elevated permissions while maintaining security. This helper runs with administrative privileges and communicates with the main application through a secure channel.

## Key Features

- Secure privilege separation architecture
- Ability to execute security checks that require administrative access
- Implementation of remediation actions for identified security issues
- Support for rolling back remediation actions if needed
- Cross-platform support for Windows, macOS, and Linux

## Architecture

The helper follows a client-server model:

1. The helper runs as a privileged process (daemon/service)
2. The main EDAMAME Security application communicates with the helper through a secure local channel
3. All communications are authenticated and validated
4. Operations are strictly limited to those defined in the threat models

## EDAMAME Ecosystem

This helper is part of the broader EDAMAME security ecosystem:

- **EDAMAME Core**: The core implementation used by all EDAMAME components (closed source)
- **[EDAMAME Security](https://github.com/edamametechnologies/edamame_security)**: Desktop/mobile security application with full UI and enhanced capabilities (closed source)
- **[EDAMAME Foundation](https://github.com/edamametechnologies/edamame_foundation)**: Foundation library providing security assessment functionality
- **[EDAMAME Posture](https://github.com/edamametechnologies/edamame_posture_cli)**: CLI tool for security posture assessment and remediation
- **[EDAMAME Helper](https://github.com/edamametechnologies/edamame_helper)**: Helper application for executing privileged security checks
- **[EDAMAME CLI](https://github.com/edamametechnologies/edamame_cli)**: Interface to EDAMAME core services
- **[GitHub Action](https://github.com/edamametechnologies/edamame_posture_action)**: CI/CD integration to enforce posture and network controls
- **[GitLab Action](https://gitlab.com/edamametechnologies/edamame_posture_action)**: CI/CD integration to enforce posture and network controls
- **[Threat Models](https://github.com/edamametechnologies/threatmodels)**: Threat model definitions used throughout the system
- **[EDAMAME Hub](https://hub.edamame.tech)**: Web portal for centralized management when using these components in team environments
