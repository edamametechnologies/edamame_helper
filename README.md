# edamame_helper
This is the Helper application for the EDAMAME Security application. 
It's used to execute security checks, remediation and rollback actions that require elevated privileges beyond the application sandboxed environment.
All the actions performed through the Helper strictly follow the threat models defined in the threat model repo (https://github.com/edamametechnologies/threatmodels).
The Helper relies on edamame_foundation, an open source library that contains the foundation for EDAMAME threat management (https://github.com/edamametechnologies/edamame_foundation).

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
- **EDAMAME Security**: Desktop security application with full UI and enhanced capabilities (closed source)
- **[EDAMAME Foundation](https://github.com/edamametechnologies/edamame_foundation)**: Foundation library providing security assessment functionality
- **[EDAMAME Posture](https://github.com/edamametechnologies/edamame_posture_cli)**: CLI tool for security posture assessment and remediation
- **[EDAMAME Helper](https://github.com/edamametechnologies/edamame_helper)**: Helper application for executing privileged security checks
- **[EDAMAME CLI](https://github.com/edamametechnologies/edamame_cli)**: Interface to EDAMAME core services
- **[GitHub Integration](https://github.com/edamametechnologies/edamame_posture_action)**: GitHub Action for integrating posture checks in CI/CD
- **[GitLab Integration](https://gitlab.com/edamametechnologies/edamame_posture_action)**: Similar integration for GitLab CI/CD workflows
- **[Threat Models](https://github.com/edamametechnologies/threatmodels)**: Threat model definitions used throughout the system
- **[EDAMAME Hub](https://hub.edamame.tech)**: Web portal for centralized management when using these components in team environments
