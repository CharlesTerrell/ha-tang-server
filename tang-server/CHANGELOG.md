# Changelog

## 1.0.0

- Initial release of the Tang Server app for Home Assistant.
- Powered by Debian 13 (Trixie) and upstream Tang v15.
- Implemented strict LAN binding to prevent exposure over Tailscale (`100.64.0.0/10`).
- Integrated automated cryptographic key initialization in `/data/tang`.
- Added automatic SHA-256 thumbprint discovery and Clevis command generation on startup.
- Implemented real-time client IP resolution and date/time stamps for all incoming request logs.
- Full local build support in Home Assistant without VS Code devcontainers.
- Comprehensive user documentation for LUKS, native ZFS dataset encryption, and dual-server (SSS) high availability.
