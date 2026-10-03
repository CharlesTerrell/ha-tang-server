# Tang Server: Network-Bound Disk Encryption for Home Assistant

Run a **Tang** Network-Bound Disk Encryption (NBDE) server directly inside Home Assistant.

Tang allows client computers, NAS systems, and servers on your local trusted network to automatically unlock encrypted filesystems at boot time without requiring manual passphrase entry. Client devices use **Clevis** to communicate with the Tang server and reconstruct the decryption key.

If an encrypted machine is disconnected from your local network (e.g. lost or stolen), it cannot reach the Tang server and remains securely locked.

---

## Highlights

- **Theft Protection & Strict LAN Isolation**: Binds strictly to your physical LAN IP address. Connections arriving over Tailscale (`100.64.0.0/10` CGNAT range) or external networks are explicitly rejected to prevent stolen devices from unlocking remotely.
- **Debian 13 (Trixie)**: Clean, lightweight Debian base running upstream `tang`.
- **LUKS & Native ZFS Support**: Supports both block-level LUKS partitions (`clevis luks bind`) and native ZFS dataset encryption with systemd unlock scripts.
- **High Availability Ready**: Easily paired with a backup Tang node (e.g. Raspberry Pi, laptop, or NAS) using Shamir's Secret Sharing (`sss`) for 1-of-2 automatic failover.
- **Automatic Key Generation & Persistence**: Cryptographic keys are generated automatically on initial startup and safely stored in `/data/tang` (persisted across updates and included in Home Assistant backups).
- **Fully Local**: No cloud dependencies, no accounts, and no telemetry.

---

## Important Security Note

This app is designed to unlock **client devices** on the same local network as Home Assistant. It is **not** designed to encrypt Home Assistant OS itself.

---

## Limitations

- **No VPN / Tailscale Access**: By design. Remote decryption undermines the location-based security guarantees of NBDE.
- **IPv4 Only**: IPv6 binding is not currently implemented.
- **Single Interface**: Automatically detects and binds to the primary physical LAN interface.

---

## Getting Started

1. **Start the App**: Click **Start** and ensure the app is running.
2. **Find Your Server Info**: Check the **Log** tab to retrieve your server's **LAN Bind IP** and cryptographic **SHA-256 Thumbprint** (`thp`).
3. **Configure Clients**: Switch to the **Documentation** tab above for full client enrollment guides:
   - Enrolling LUKS block devices (`clevis luks bind`)
   - Enrolling native ZFS datasets
   - Setting up dual-server failover policies
   - Thumbprint pinning vs. Trust On First Use (TOFU)
