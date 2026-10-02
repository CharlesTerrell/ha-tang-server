# Tang Server: Network-Bound Disk Encryption Server for Home Assistant

Run a **Tang** Network-Bound Disk Encryption (NBDE) server as an app inside Home Assistant.

Tang allows computers (and other devices with encrypted filesystems) on your local network to unlock themselves at boot time. The encrypted device uses **Clevis** to communicate with the Tang server, reconstructing the necessary decryption information. Thus the encrypted filesystem is unlocked without requiring someone to go to the device and enter its password manually.

If someone removes the encrypted device from the local network, it will be unable to reach the Tang server. That leaves the encrypted filesystem unusable until it returns to the network, or until someone enters the password or decryption key in some other way.

This system supports both **LUKS** and **native ZFS encryption**. It also supports **dual-server mode** (coexisting with another Tang server) for higher availability. It refuses to work on Tailscale's address range, because Tailscale would allow a device to decrypt itself in potentially hostile locations.

**Important**: This is for encrypted devices that share a network with Home Assistant. It is *not* for encrypting Home Assistant OS itself. Security of your Home Assistant machine (including physical access) is your responsibility.

Note: This project is intended to improve security of home networks by making location-bound device encryption more convenient for Home Assistant users. The maintainer is not directly affiliated with upstream Tang or Clevis. For more detailed information about these services:
- [https://github.com/latchset/tang](https://github.com/latchset/tang)
- [https://github.com/latchset/clevis](https://github.com/latchset/clevis)

---

## Highlights

- **Debian 13 (Trixie)**: Modern Debian base running upstream `tang` server.
- **Strict LAN Isolation**: Binds only to your LAN IP address. Connections arriving over Tailscale (`100.64.0.0/10` CGNAT address space) or outside networks are unable to reach the service, preventing stolen devices from decrypting off-site.
- **LUKS & Native ZFS Support**: Supports both block-level LUKS disk encryption and native ZFS dataset encryption.
- **Dual Server Ready**: Supports seamless failover using a secondary server (e.g. Raspberry Pi or laptop) via Shamir's Secret Sharing (`sss`) in Clevis.
- **Automatic Key Generation**: Cryptographic keys are generated automatically on first start and persisted in `/data/tang` across updates and Home Assistant backups.
- **No Cloud / No Telemetry**: Fully local and self-contained.

---

## Limitations

- **No VPN interfaces**: This is by design. Remote access is useful, but not if it helps hostile parties decrypt your personal information on stolen devices.
- **IPv4 only**: Does not yet work with IPv6 addresses.
- **First address only**: Does not yet bind to multiple IPv4 interfaces; only the first LAN detected is used. This could be a problem if a slower wifi interface is detected before faster ethernet, or if routing interferes with mDNS address resolution.

---

## Documentation

Full installation, configuration, and client setup instructions are available in **[DOCS.md](tang-server/DOCS.md)** (and rendered inside the Home Assistant app's **Documentation** tab):

- **[Server Installation](tang-server/DOCS.md#server-installation)**:
  - Option 1: Home Assistant App Repository (via App Store Repositories)
  - Option 2: Home Assistant Local Add-on Build (via `/addons`)
  - Option 3: Standalone Docker on laptop / Raspberry Pi (for testing or backup node, including log viewing)
- **[Configuration Options](tang-server/DOCS.md#configuration-options)**: Port and IP binding options
- **[Client Setup Guides](tang-server/DOCS.md#client-setup-prerequisites)**:
  - Use Case 1: LUKS block-device encryption (`clevis luks bind`)
  - Use Case 2: Native ZFS dataset encryption with systemd unlock service
  - Use Case 3: Dual-server high availability (1-of-2 failover with Clevis `sss`)
  - Server thumbprint pinning (`thp`) vs. Trust On First Use (TOFU)
- **[Backups & Key Persistence](tang-server/DOCS.md#backups--key-persistence)**
