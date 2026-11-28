#!/usr/bin/env bash
# ==============================================================================
# UltraOnePanel Official Uninstaller
# Usage:
#   curl -sSO https://install.ultraonepanel.com/uninstall.sh && bash uninstall.sh
#   Optional: bash uninstall.sh --purge-data  (also removes /www/wwwroot)
# ==============================================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "[ERROR] Run as root."; exit 1; }

PURGE_DATA=false
if [ "${1:-}" = "--purge-data" ]; then
  PURGE_DATA=true
fi

echo "Stopping UltraOnePanel services..."
systemctl stop facezila.service 2>/dev/null || true
systemctl disable facezila.service 2>/dev/null || true
rm -f /etc/systemd/system/facezila.service
systemctl daemon-reload 2>/dev/null || true

echo "Removing UltraOnePanel runtime and CLI..."
rm -rf /opt/facezila
rm -f /usr/local/bin/upanel /usr/local/bin/facezila /usr/local/bin/ultra-license

if [ "$PURGE_DATA" = true ]; then
  echo "Purging /www/wwwroot and /var/backups/facezila..."
  rm -rf /www/wwwroot /var/backups/facezila
else
  echo "Preserved /www/wwwroot website files (pass --purge-data to remove)."
fi

echo "UltraOnePanel has been uninstalled."
