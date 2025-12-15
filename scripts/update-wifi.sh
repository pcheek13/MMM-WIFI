#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <SSID> <PASSWORD>" >&2
  exit 1
fi

SSID="$1"
PASSWORD="$2"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
BACKUP_SUFFIX=$(date +%Y%m%d%H%M%S)
BACKUP_PATH="${WPA_CONF}.${BACKUP_SUFFIX}.bak"
TMP_NETWORK=$(mktemp)

# Ensure the configuration file exists and is writable
sudo install -d -m 755 /etc/wpa_supplicant
if [[ ! -f "$WPA_CONF" ]]; then
  echo "Creating missing $WPA_CONF with defaults"
  sudo tee "$WPA_CONF" >/dev/null <<'CFG'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US
CFG
fi

# Create a hashed network block from the provided credentials
if ! command -v wpa_passphrase >/dev/null 2>&1; then
  echo "wpa_passphrase command not found. Please install wpa_supplicant." >&2
  exit 2
fi

wpa_passphrase "$SSID" "$PASSWORD" > "$TMP_NETWORK"

# Backup existing configuration and append the new network block
sudo cp "$WPA_CONF" "$BACKUP_PATH"

echo "# Added by MMM-WIFI on $(date)" | sudo tee -a "$WPA_CONF" >/dev/null
sudo tee -a "$WPA_CONF" < "$TMP_NETWORK" >/dev/null

rm -f "$TMP_NETWORK"

# Reconfigure Wi-Fi and restart MagicMirror
sudo wpa_cli -i wlan0 reconfigure || sudo systemctl restart wpa_supplicant.service
sudo pm2 restart mm

echo "Wi-Fi credentials for '$SSID' applied. Backup saved to $BACKUP_PATH"
