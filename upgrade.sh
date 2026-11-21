#!/usr/bin/env bash
# ==============================================================================
# UltraOnePanel Official One-Line Upgrade Utility
# Usage on existing installations (Ubuntu 22.04 / 24.04):
#   curl -fsSL https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/upgrade.sh | sudo bash
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

INSTALL_DIR="/opt/facezila"
RELEASE_URL="${RELEASE_URL:-https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/ultraonepanel-latest.tar.gz}"

[ "$(id -u)" -eq 0 ] || { echo -e "${RED}[ERROR] This upgrade script must be run as root.${NC}"; exit 1; }
[ -d "$INSTALL_DIR" ] || { echo -e "${RED}[ERROR] UltraOnePanel is not installed in $INSTALL_DIR.${NC}"; exit 1; }

echo -e "${CYAN}${BOLD}========================================================================${NC}"
echo -e "${GREEN}${BOLD}             Upgrading UltraOnePanel to the Latest Version              ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"

# 1. Create a safety backup of existing panel code
BACKUP_DIR="/var/backups/facezila"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/panel-code-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" -C "$INSTALL_DIR" src dist package.json 2>/dev/null || true
echo -e "${GREEN}✓ Existing code backed up to: ${BACKUP_FILE}${NC}"

# 2. Download latest release archive
STAGE="$(mktemp -d)"
echo "Downloading latest UltraOnePanel release package..."
curl -k -fsSL "$RELEASE_URL" -o "$STAGE/ultraonepanel.tar.gz" 2>/dev/null || wget --no-check-certificate -qO "$STAGE/ultraonepanel.tar.gz" "$RELEASE_URL"
tar -xzf "$STAGE/ultraonepanel.tar.gz" -C "$STAGE"

# 3. Replace application files safely (keeping .env, SSL, and data intact)
echo "Deploying latest backend runtime and frontend interfaces..."
rm -rf "$INSTALL_DIR/src" "$INSTALL_DIR/dist" "$INSTALL_DIR/whm-dist" "$INSTALL_DIR/frontend" "$INSTALL_DIR/whm-frontend"
cp -r "$STAGE/src" "$INSTALL_DIR/"
cp -r "$STAGE/package.json" "$INSTALL_DIR/"
[ -f "$STAGE/package-lock.json" ] && cp "$STAGE/package-lock.json" "$INSTALL_DIR/"
[ -d "$STAGE/dist" ] && cp -r "$STAGE/dist" "$INSTALL_DIR/dist" && cp -r "$STAGE/dist" "$INSTALL_DIR/frontend/dist" 2>/dev/null || true
[ -d "$STAGE/whm-dist" ] && cp -r "$STAGE/whm-dist" "$INSTALL_DIR/whm-dist" && cp -r "$STAGE/whm-dist" "$INSTALL_DIR/whm-frontend/dist" 2>/dev/null || true

# 4. Install or update upanel CLI command utility
if [ -f "$STAGE/installer/upanel" ]; then
  cp -f "$STAGE/installer/upanel" /usr/local/bin/upanel
  chmod +x /usr/local/bin/upanel
  ln -sf /usr/local/bin/upanel /usr/local/bin/facezila
  /usr/local/bin/upanel init >/dev/null 2>&1 || true
fi

# 5. Clean up temporary directory
rm -rf "$STAGE"

# 6. Install any new production npm dependencies
cd "$INSTALL_DIR"
npm install --omit=dev --no-audit --no-fund

# 7. Restart panel service
echo "Restarting UltraOnePanel service..."
systemctl daemon-reload 2>/dev/null || true
systemctl restart facezila.service 2>/dev/null || true
sleep 2

if systemctl is-active --quiet facezila.service; then
  echo -e "${GREEN}${BOLD}✓ UltraOnePanel successfully upgraded to the latest version!${NC}"
  echo ""
  /usr/local/bin/upanel info 2>/dev/null || true
else
  echo -e "${YELLOW}[WARN] Panel service did not start immediately. Checking logs...${NC}"
  journalctl -u facezila.service -n 25 --no-pager
fi
