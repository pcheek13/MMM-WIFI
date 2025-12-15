# MMM-WIFI

Display a solid Wi‑Fi logo as network signal for MagicMirror² (and MorningMirror forks) and tap it to reconfigure your Wi‑Fi directly from the mirror.

![Signal icons: none, weak, normal, strong, loading](https://raw.githubusercontent.com/pcheek13/MMM-WIFI/master/icons.gif)

## Dependencies

-   [MagicMirror²](https://github.com/MichMich/MagicMirror) (works on Raspberry Pi 5; MorningMirror forks also work)
-   [NPM Ping](https://www.npmjs.com/package/ping)

## Installation (one copy/paste block)
On your Pi, paste the following into the terminal to install the module and its dependencies:
```bash
cd ~/MagicMirror/modules && \
git clone https://github.com/pcheek13/MMM-WIFI.git && \
cd MMM-WIFI && \
npm install
```
## Configuration
- Now use your editor `nano` or `vim` to edit the following file
```bash
nano ~/MagicMirror/config/config.js # change nano to your favorite editor
```
- Paste the following code into the `modules` section

```js
{
    module: "MMM-WIFI",
    position: "bottom_right",
    config: {
        // Configuration of the module goes here
    }
}
```

## Configuration Options

| **Option**         | **Default**                              | **Description**                         |
| ------------------ | ---------------------------------------- | --------------------------------------- |
| `updateInterval`   | `5000`                                   | Time in ms between connection tests     |
| `maxTimeout`       | `1000`                                   | Maximum timeout in ms for every pings   |
| `animationSpeed`   | `250`                                    | Icon change animation time in ms        |
| `initialLoadDelay` | `3000`                                   | Delay in ms for first ping              |
| `server`           | `8.8.8.8`                                | Pingable server IP address              |
| `thresholds`       | `{ strong: 50, medium: 150, weak: 500 }` | Tresholds for icons (ping answer in ms) |
| `showMessage`      | `true`                                   | Shows status messages depending on how good or bad is the connection |
| `flexDirection`    | `row`                                    | Sets the direction the module is displayed; `row` displays the row in left-to-right mode (default), `row-reverse` displays the row in right-to-left mode. |
| `scale`            | `0.45`                                   | How much to scale the ping icon. Must be greater than 0. |
| `touchTargetSize`  | `96`                                     | Minimum square size (px) of the tap target around the Wi‑Fi icon for easier touchscreen interaction. |
| `allowWifiUpdates` | `true`                                   | When enabled, tapping the Wi‑Fi icon on a touchscreen toggles a form to enter a new SSID and password. |
| `showVirtualKeyboard` | `true`                                | Displays a built-in on-screen keyboard beneath the form so you can type SSID and password without a hardware keyboard. |
| `wifiCommand`      | `/bin/bash /home/pi/MagicMirror/modules/MMM-WIFI/scripts/update-wifi.sh {ssid} {password}` | Command executed to update Wi‑Fi (defaults to the provided shell script). Customize if your Pi uses a different path or interface name. |
| `useSudoForWifiCommand` | `true`                              | Run the Wi‑Fi command with `sudo`. Disable only if your MagicMirror user already has permission to manage networking. |

### Updating Wi‑Fi from the mirror

When `allowWifiUpdates` is true, simply tap or click the enlarged Wi‑Fi strength icon (the whole padded square is clickable and also supports keyboard Enter/Space). The button is pointer-enabled from the moment the module loads, and the form will stay put while you type (inputs are preserved even as the signal status updates in the background). Submitting the form triggers the provided shell script (or your custom command) to append the new network to `/etc/wpa_supplicant/wpa_supplicant.conf`, reconfigure Wi‑Fi, and restart MagicMirror with `pm2 restart mm`. Any errors returned by the command will be shown under the form.

### Custom Wi‑Fi script (default)

This module ships with `scripts/update-wifi.sh`, which:

- Backs up `/etc/wpa_supplicant/wpa_supplicant.conf`
- Uses `wpa_passphrase` to append a secure network block for your SSID/password
- Reconfigures Wi‑Fi and restarts MagicMirror via `pm2 restart mm`

If you prefer to recreate the script yourself, copy/paste the following on your Pi (adjust the path if you keep your module elsewhere):

```bash
cd ~/MagicMirror/modules/MMM-WIFI
cat <<'EOF' > scripts/update-wifi.sh
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

if ! command -v wpa_passphrase >/dev/null 2>&1; then
  echo "wpa_passphrase command not found. Please install wpa_supplicant." >&2
  exit 2
fi

wpa_passphrase "$SSID" "$PASSWORD" > "$TMP_NETWORK"
sudo cp "$WPA_CONF" "$BACKUP_PATH"
echo "# Added by MMM-WIFI on $(date)" | sudo tee -a "$WPA_CONF" >/dev/null
sudo tee -a "$WPA_CONF" < "$TMP_NETWORK" >/dev/null
rm -f "$TMP_NETWORK"
sudo wpa_cli -i wlan0 reconfigure || sudo systemctl restart wpa_supplicant.service
sudo pm2 restart mm
echo "Wi-Fi credentials for '$SSID' applied. Backup saved to $BACKUP_PATH"
EOF
chmod +x scripts/update-wifi.sh
```

Ensure `wifiCommand` in your module config points to this script (the default path assumes `/home/pi/MagicMirror/modules/MMM-WIFI/scripts/update-wifi.sh`).
