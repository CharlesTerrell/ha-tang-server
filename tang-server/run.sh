#!/usr/bin/env bash
set -e

CONFIG_PATH="/data/options.json"
KEY_DIR="/data/tang"

mkdir -p /data "${KEY_DIR}"

PORT=7500
LISTEN_IP="auto"

if [ -f "${CONFIG_PATH}" ]; then
  PORT=$(jq -r '.port // 7500' "${CONFIG_PATH}")
  LISTEN_IP=$(jq -r '.listen_ip // "auto"' "${CONFIG_PATH}")
fi

is_tailscale_ip() {
  local ip="$1"
  if [[ "$ip" =~ ^100\.([0-9]{1,3})\. ]]; then
    local second_octet="${BASH_REMATCH[1]}"
    if (( second_octet >= 64 && second_octet <= 127 )); then
      return 0
    fi
  fi
  return 1
}

BIND_IP=""
DEF_IFACE=""

if [ -n "${LISTEN_IP}" ] && [ "${LISTEN_IP}" != "auto" ]; then
  if is_tailscale_ip "${LISTEN_IP}"; then
    echo "[-] ERROR: Configured listen_ip '${LISTEN_IP}' belongs to the Tailscale CGNAT range (100.64.0.0/10)." >&2
    echo "[-] Tang Server is configured to refuse Tailscale binding to prevent remote decryption." >&2
    exit 1
  fi
  BIND_IP="${LISTEN_IP}"
else
  # Auto-detect default route interface
  DEF_IFACE=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)

  # Verify default interface is not a VPN or Tailscale interface
  if [[ "${DEF_IFACE}" =~ ^(tailscale|wg|tun|tap) ]]; then
    echo "[!] Notice: Default route interface '${DEF_IFACE}' is a VPN/Tailscale interface. Searching physical LAN interfaces..."
    DEF_IFACE=""
  fi

  if [ -n "${DEF_IFACE}" ]; then
    CANDIDATE_IP=$(ip -4 addr show dev "${DEF_IFACE}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    if [ -n "${CANDIDATE_IP}" ] && ! is_tailscale_ip "${CANDIDATE_IP}"; then
      BIND_IP="${CANDIDATE_IP}"
    fi
  fi

  # Fallback: scan all non-virtual, non-tailscale interfaces
  if [ -z "${BIND_IP}" ]; then
    for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -vE '^(lo|docker|veth|br-|tailscale|wg|tun|tap)'); do
      CANDIDATE_IP=$(ip -4 addr show dev "${iface}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
      if [ -n "${CANDIDATE_IP}" ] && ! is_tailscale_ip "${CANDIDATE_IP}"; then
        BIND_IP="${CANDIDATE_IP}"
        DEF_IFACE="${iface}"
        break
      fi
    done
  fi
fi

if [ -z "${BIND_IP}" ]; then
  echo "[-] ERROR: Could not identify a valid physical LAN IPv4 address." >&2
  echo "[-] Please configure 'listen_ip' explicitly in the app configuration tab." >&2
  exit 1
fi

if is_tailscale_ip "${BIND_IP}"; then
  echo "[-] ERROR: Resolved IP address '${BIND_IP}' is a Tailscale address (100.64.0.0/10)!" >&2
  echo "[-] Refusing to bind. Tang must only be accessible over your local LAN." >&2
  exit 1
fi

# Ensure key storage directory exists with restricted permissions
mkdir -p "${KEY_DIR}"
chmod 700 "${KEY_DIR}"

# Initialize keys if missing
KEY_COUNT=$(find "${KEY_DIR}" -maxdepth 1 -name '*.jwk' 2>/dev/null | wc -l)
if [ "${KEY_COUNT}" -eq 0 ]; then
  echo "[+] No cryptographic keys found in ${KEY_DIR}."
  echo "[+] Generating initial keys with /usr/libexec/tangd-keygen..."
  /usr/libexec/tangd-keygen "${KEY_DIR}"
  chmod 600 "${KEY_DIR}"/*
  echo "[+] Keys generated successfully."
else
  echo "[+] Found ${KEY_COUNT} existing key file(s) in ${KEY_DIR}."
fi

# Start socat in background and handle shutdown signals
cleanup() {
  echo "[*] Stopping Tang service..."
  if [ -n "${SOCAT_PID}" ] && kill -0 "${SOCAT_PID}" 2>/dev/null; then
    kill -TERM "${SOCAT_PID}" 2>/dev/null || true
    wait "${SOCAT_PID}" 2>/dev/null || true
  fi
  exit 0
}

trap cleanup SIGTERM SIGINT

socat TCP4-LISTEN:${PORT},bind=${BIND_IP},reuseaddr,fork EXEC:"/usr/libexec/tangd ${KEY_DIR}" &
SOCAT_PID=$!

# Wait briefly for listener to be active
sleep 1

# Retrieve active advertised keys and compute SHA-256 thumbprint
THUMBPRINT=""
ADV=$(curl -sSf "http://${BIND_IP}:${PORT}/adv" 2>/dev/null || true)
if [ -n "${ADV}" ]; then
  THUMBPRINT=$(jose fmt --json "${ADV}" -g payload -y -o- | jose jwk use -i- -r -u verify -o- | jose jwk thp -i- -a S256 2>/dev/null || true)
fi

echo "======================================================================"
echo " Tang Server is active and listening"
echo "----------------------------------------------------------------------"
echo " LAN Bind IP   : ${BIND_IP}"
echo " Port          : ${PORT}"
if [ -n "${DEF_IFACE}" ]; then
echo " Interface     : ${DEF_IFACE}"
fi
echo " Key Directory : ${KEY_DIR}"
if [ -n "${THUMBPRINT}" ]; then
echo " SHA-256 Thumbprint: ${THUMBPRINT}"
echo ""
echo " Command to enroll a LUKS encrypted client with Clevis:"
echo "   clevis luks bind -d <DEVICE> tang '{\"url\":\"http://${BIND_IP}:${PORT}\",\"thp\":\"${THUMBPRINT}\"}'"
fi
echo "======================================================================"
echo "[i] Protection active: This server is bound only to ${BIND_IP}."
echo "[i] Connections from Tailscale or foreign subnets will not be answered."

wait "${SOCAT_PID}"
