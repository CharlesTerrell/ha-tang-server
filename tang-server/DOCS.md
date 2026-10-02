# Tang Server: Network-Bound Disk Encryption Server for Home Assistant

**Tang** is an automated encryption key server providing Network-Bound Disk Encryption (NBDE). It allows LUKS-encrypted disks as well as natively encrypted ZFS datasets running on client machines with **Clevis** to automatically unlock upon booting, provided they are connected to your trusted local network.

**Important**: This is for encrypting devices that share a network with Home Assistant. It is *not* for encrypting Home Assistant OS itself. Security of your Home Assistant machine (including physical access) is your responsibility.

*(NOTE: Replace the network addresses shown in this document with the actual addresses for Home Assistant / your Tang servers, or with their names if you have mDNS or DHCP reservations.)*

---

## Security Model: Local LAN Isolation

This app is hardened against device theft:
- **LAN-Only Binding**: The Tang server binds specifically to your physical LAN IP (e.g. `192.168.x.x` or `10.x.x.x`). It does **not** listen on `0.0.0.0` or Tailscale/CGNAT (`100.64.0.0/10`).
- **Theft Protection**: If an encrypted laptop, workstation, or NAS is stolen and plugged into an ethernet jack elsewhere (or if Tailscale connects over the internet), the stolen machine **cannot** reach the Tang server. The disk/dataset remains locked and requires the manual passphrase.

---

## Server Installation

### Option 1: Home Assistant App Repository (Recommended once published)

Once published to GitHub, you can add this repository directly to Home Assistant:
1. In Home Assistant, navigate to **Settings** → **Apps** (or **Add-ons**) → **App Store**.
2. Click the top-right menu (three dots) and select **Repositories**.
3. Add the repository URL: `https://github.com/CharlesTerrell/ha-tang-server` and click **Add**.
4. Under **Tang Server Repository**, click **Tang Server**.
5. Click **Install**, then click **Start**.

---

### Option 2: Home Assistant Local Add-on Build (via `/addons`)

#### 1. Prerequisite: File Access to `/addons`
Fresh Home Assistant OS installations might not include file transfer tools by default. To copy this app onto your Home Assistant machine, first install **at least one** of the following from the App / Add-on Store:
- **Samba share** (Official Add-on): Exposes the `/addons` folder as a standard Windows/SMB network share (`\\homeassistant.local\addons`).
- **Advanced SSH & Web Terminal** (Community Add-on): Enables SSH, SCP, and SFTP access into Home Assistant.

#### 2. Copy App Files
Copy the `tang-server` folder into `/addons/tang-server` on your Home Assistant system:
- **Via Samba**: Copy the `tang-server` folder to `\\homeassistant.local\addons\tang-server`
- **Via SCP/SFTP**:
  ```bash
  scp -r /path/to/ha-tang-server/tang-server root@homeassistant.local:/addons/tang-server
  ```

#### 3. Install & Start
1. In Home Assistant, go to **Settings** → **Apps** (or **Add-ons**) → **App Store**.
2. Click the top-right three dots menu and select **Check for updates**.
3. Under **Local apps**, click **Tang Server**.
4. Click **Install**, then click **Start**.

---

### Option 3: Standalone Docker (Laptop / Testing / Backup Node)

You can also run the container directly on a laptop, desktop, or Raspberry Pi using Docker for testing, development, or as a secondary/backup Tang server:

#### 1. Build the Image
From the repository directory:
```bash
docker build -t tang-server tang-server/
```
*(Or inside the `tang-server/` directory: `docker build -t tang-server .`)*

#### 2. Run the Container
- **Interactive / Testing** (runs in foreground, press <kbd>Ctrl</kbd>+<kbd>C</kbd> to stop):
  ```bash
  docker run --rm -it --name tang-server --net=host -v tang-data:/data tang-server
  ```
- **Background Daemon** (runs detached, restarts automatically):
  ```bash
  docker run -d --name tang-server --restart unless-stopped --net=host -v tang-data:/data tang-server
  ```

#### 3. View Container Logs
The container logs output the detected LAN IP, listening port, and the cryptographic SHA-256 thumbprint needed for Clevis clients:
```bash
# View startup banner and thumbprint
docker logs tang-server

# Follow live output
docker logs -f tang-server
```

#### 4. Stop the Container
```bash
docker stop tang-server
```

---

## Configuration Options

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `port` | integer | `7500` | The TCP port Tang listens on. |
| `listen_ip` | string | `auto` | Set to `auto` to automatically detect your primary physical LAN interface IPv4 address. You can also specify an exact static IP (e.g. `192.168.1.50`). Binding to any Tailscale address (`100.64.0.0/10`) is explicitly rejected. |

---

## Client Setup: Prerequisites

Install Clevis on your client system:

- **Debian / Ubuntu / Proxmox**:
  ```bash
  sudo apt update
  sudo apt install -y clevis clevis-luks clevis-initramfs
  ```
- **Fedora / RHEL / CentOS**:
  ```bash
  sudo dnf install -y clevis clevis-luks clevis-dracut
  ```
- **Arch Linux**:
  ```bash
  sudo pacman -S clevis
  ```
- **Other OS / other use cases**: Discussion and contributions are welcome.

---

## Use Case 1: LUKS Disk Encryption (Single Tang Server)

### 1. Identify your Encrypted LUKS Partition
```bash
lsblk -f
```
Find the partition with `FSTYPE="crypto_LUKS"`, for example `/dev/nvme0n1p3` or `/dev/sda3`.

### 2. Check App Logs for Server Info
In Home Assistant, go to **Settings** → **Apps** → **Tang Server** → **Logs**. Copy the **LAN Bind IP** and **SHA-256 Thumbprint**.

### 3. Enroll the LUKS Partition
```bash
sudo clevis luks bind -d /dev/nvme0n1p3 tang \
  '{"url":"http://192.168.1.50:7500","thp":"<HA_THUMBPRINT>"}'
```
Enter your existing LUKS passphrase when prompted to authorize the new keyslot.

### 4. Update Initramfs
- **Debian / Ubuntu**: `sudo update-initramfs -u -k all`
- **Fedora / RHEL / Arch**: `sudo dracut -f --regenerate-all`

---

## Use Case 2: ZFS Native Encryption (Single Tang Server)

For clients booting from an unencrypted drive and unlocking a natively encrypted ZFS dataset (`encryption=on`):

### 1. Encrypt your ZFS Passphrase with Tang
Use Clevis to encrypt your dataset passphrase against the Home Assistant Tang server:
```bash
echo -n "YOUR_ZFS_PASSPHRASE" | clevis encrypt tang \
  '{"url":"http://192.168.1.50:7500","thp":"<HA_THUMBPRINT>"}' \
  | sudo tee /etc/zfs/zfs_key.jwe > /dev/null

sudo chmod 600 /etc/zfs/zfs_key.jwe
```

Verify you can decrypt it manually:
```bash
clevis decrypt < /etc/zfs/zfs_key.jwe | sudo zfs load-key -a
```

### 2. Create Systemd Service for Boot Unlock
Create `/etc/systemd/system/zfs-load-key-tang.service`:
```ini
[Unit]
Description=Load ZFS encryption keys via Tang NBDE
DefaultDependencies=no
After=network-online.target zfs-import.target
Wants=network-online.target
Before=zfs-mount.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "clevis decrypt < /etc/zfs/zfs_key.jwe | zfs load-key -a"

[Install]
WantedBy=zfs-mount.service
```

Enable the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable zfs-load-key-tang.service
```

---

## Use Case 3: Dual Server / High Availability (Home Assistant + Backup Node)

If you run a primary Tang server on Home Assistant and a secondary backup server (e.g. Raspberry Pi, laptop, or second server), use Clevis's **SSS (Shamir's Secret Sharing)** pin with a threshold of `t: 1`.

This creates a **1-of-2 failover policy**: if Home Assistant is rebooting, down for updates, or unreachable, the backup node fulfills the request instantly.

> [!NOTE]
> Each Tang server maintains its own independent keys and thumbprints. No key synchronization between servers is needed!

### Dual Server: LUKS Binding
```bash
sudo clevis luks bind -d /dev/nvme0n1p3 sss \
  '{"t": 1, "pins": {"tang": [
      {"url": "http://192.168.1.50:7500", "thp": "<HA_THUMBPRINT>"},
      {"url": "http://192.168.1.60:7500", "thp": "<BACKUP_PI_THUMBPRINT>"}
  ]}}'
```

### Dual Server: ZFS Native Encryption
Encrypt the passphrase with the SSS policy:
```bash
echo -n "YOUR_ZFS_PASSPHRASE" | clevis encrypt sss \
  '{"t": 1, "pins": {"tang": [
      {"url": "http://192.168.1.50:7500", "thp": "<HA_THUMBPRINT>"},
      {"url": "http://192.168.1.60:7500", "thp": "<BACKUP_PI_THUMBPRINT>"}
  ]}}' | sudo tee /etc/zfs/zfs_key.jwe > /dev/null

sudo chmod 600 /etc/zfs/zfs_key.jwe
```

The systemd service (`zfs-load-key-tang.service`) remains the same. It simply executes `clevis decrypt < /etc/zfs/zfs_key.jwe`, which queries both Tang servers in parallel and unlocks as soon as either responds.

---

## Server Thumbprint Pinning (`thp`) vs. TOFU

When enrolling clients (with either single or dual Tang servers), specifying the server thumbprint (`thp`) is **optional**:

- **With Thumbprint (Recommended for MITM Protection)**:
  Specifying `"thp": "<THUMBPRINT>"` cryptographically pins the server's public signing key. This guarantees the server responding at that address is your authentic Tang server and protects against network spoofing. Enrollment runs completely silently without terminal prompts.
- **Without Thumbprint (Trust On First Use - TOFU)**:
  If you omit `"thp"`, Clevis uses a TOFU model and asks in your terminal:
  ```text
  Do you wish to trust these keys? [ynYN]
  ```
  In non-interactive scripts or automated workflows, pass the `-y` flag to accept the keys automatically:
  ```bash
  echo -n "YOUR_PASSPHRASE" | clevis encrypt sss \
    '{"t": 1, "pins": {"tang": [
        {"url": "http://192.168.1.50:7500"},
        {"url": "http://192.168.1.60:7500"}
    ]}}' -y | sudo tee /etc/zfs/zfs_key.jwe > /dev/null
  ```
- **Boot Unlocking**: Once enrolled, the verified public keys are sealed directly into the LUKS keyslot or `.jwe` file. At boot time, `clevis decrypt` **never** prompts for confirmation or thumbprints.

### Pro-Tip: Querying the Thumbprint from the Client
If you want to look up the server's thumbprint directly from the client machine where `clevis` is installed (using `curl` and `jose`):
```bash
curl -sSf http://<SERVER_IP>:7500/adv \
  | jose fmt --json=- -g payload -y -o- \
  | jose jwk use -i- -r -u verify -o- \
  | jose jwk thp -i- -a S256
```

---

## Backups & Key Persistence

- Tang cryptographic keys are persisted in `/data/tang/`.
- Home Assistant backups (full or partial backup of this app) protect `/data/tang`.
- If you restore Home Assistant from a backup or migrate hardware, your existing enrolled clients will continue to unlock seamlessly.

---

## AI Disclosure

The maintainer used Gemini 3.8 Flash via Antigravity CLI to plan the project, and then allowed Gemini to generate config files, documentation, and support scripts. The human reviewed and tested the AI's output and edited (or rewrote) large parts of the documentation. This work flow greatly reduced the time from idea to working add-on. You are welcome to inspect the code and offer suggestions for improvement.
