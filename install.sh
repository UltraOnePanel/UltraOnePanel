#!/usr/bin/env bash
# ==============================================================================
# UltraOnePanel Official One-Line Ubuntu Installer
# Supported OS: Ubuntu 22.04 LTS / Ubuntu 24.04 LTS
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/install.sh | sudo bash
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
step() { echo -e "${CYAN}${BOLD}==> $*${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $*${NC}"; }
die()  { echo -e "${RED}[ERROR] $*${NC}"; exit 1; }

INSTALL_DIR="/opt/facezila"
DATA_DIR="/var/lib/facezila"
RELEASE_URL="${RELEASE_URL:-https://github.com/UltraOnePanel/UltraOnePanel/releases/latest/download/ultraonepanel-latest.tar.gz}"
export DEBIAN_FRONTEND=noninteractive

# 1. Privileges & OS verification
[ "$(id -u)" -eq 0 ] || die "This installer must be run as root (or with sudo)."
[ -f /etc/os-release ] || die "Unsupported Linux distribution."
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || warn "UltraOnePanel targets Ubuntu (22.04/24.04); detected ${NAME:-unknown}. Proceeding."

SERVER_IP="$(curl -s -m 5 https://api.ipify.org || hostname -I | awk '{print $1}')"

# 2. System dependencies & Core Hosting Stack
step "[1/6] Installing system packages and hosting stack"
apt-get update -y
apt-get install -y curl wget ca-certificates gnupg lsb-release tar zip unzip openssl sqlite3 cron build-essential python3 \
  nginx mariadb-server certbot \
  postgresql postgresql-contrib phppgadmin php-pgsql \
  php-fpm php-mysql php-cli php-curl php-mbstring php-xml php-zip php-gd php-intl php-bcmath php-opcache \
  postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd ssl-cert \
  bind9 bind9utils vsftpd ufw fail2ban

# Install Node.js 20 LTS if not present
if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]; then
  step "Installing Node.js 20 LTS"
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update -y
  apt-get install -y nodejs
fi

# 3. Configure Database & Web Services
step "[2/6] Configuring MariaDB, PostgreSQL and Nginx"
systemctl enable --now mariadb 2>/dev/null || systemctl enable --now mysql 2>/dev/null || true
systemctl enable --now postgresql 2>/dev/null || true
systemctl disable --now apache2 2>/dev/null || true
systemctl mask apache2 2>/dev/null || true

# phpPgAdmin configuration
if [ -f /etc/phppgadmin/config.inc.php ]; then
  sed -i "s/\\$conf\\['extra_login_security'\\] = true;/\\$conf\\['extra_login_security'\\] = false;/g" /etc/phppgadmin/config.inc.php
  sed -i "s/\\$conf\\['owned_only'\\] = true;/\\$conf\\['owned_only'\\] = false;/g" /etc/phppgadmin/config.inc.php
fi

for fpm in /etc/init.d/php*-fpm; do [ -e "$fpm" ] && systemctl enable --now "$(basename "$fpm")" 2>/dev/null || true; done
systemctl enable --now nginx 2>/dev/null || true

# 4. Download and Install Pre-compiled Package
step "[3/6] Downloading UltraOnePanel pre-compiled package"
mkdir -p "$INSTALL_DIR" "$DATA_DIR" /var/log/facezila /etc/facezila/ssl
curl -fsSL "$RELEASE_URL" -o /tmp/ultraonepanel.tar.gz
tar -xzf /tmp/ultraonepanel.tar.gz -C "$INSTALL_DIR"
rm -f /tmp/ultraonepanel.tar.gz

step "[4/6] Installing production dependencies"
cd "$INSTALL_DIR"
npm install --omit=dev --no-audit --no-fund

# 5. SSL & Environment Setup
step "[5/6] Generating SSL certificate and configuring panel"
if [ ! -f /etc/facezila/ssl/panel.crt ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /etc/facezila/ssl/panel.key -out /etc/facezila/ssl/panel.crt \
    -subj "/CN=${SERVER_IP}" >/dev/null 2>&1
  chmod 600 /etc/facezila/ssl/panel.key
fi

if [ ! -f "$INSTALL_DIR/.env" ]; then
  cat > "$INSTALL_DIR/.env" <<EOF
NODE_ENV=production
CPANEL_PORT=2083
WHM_PORT=2087
SERVER_IP=${SERVER_IP}
SSL_CERT=/etc/facezila/ssl/panel.crt
SSL_KEY=/etc/facezila/ssl/panel.key
EOF
  chmod 600 "$INSTALL_DIR/.env"
fi

# 6. Firewall & Service Management
step "[6/6] Configuring firewall and systemd service"
for port in 80/tcp 443/tcp 2083/tcp 2087/tcp 2096/tcp 21/tcp 25/tcp 465/tcp 587/tcp 993/tcp 995/tcp 53; do
  ufw allow "$port" >/dev/null 2>&1 || true
done
ufw --force enable >/dev/null 2>&1 || true

cat > /etc/systemd/system/facezila.service <<EOF
[Unit]
Description=UltraOnePanel Hosting Control Panel
After=network.target nginx.service mariadb.service postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=$(command -v node) ${INSTALL_DIR}/src/server.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now facezila.service
systemctl restart facezila.service

echo -e "${GREEN}${BOLD}"
echo "=========================================================="
echo "      UltraOnePanel Installed Successfully!"
echo "=========================================================="
echo -e "${NC}"
echo -e "  WHM Admin URL : ${BOLD}${YELLOW}https://${SERVER_IP}:2087${NC}"
echo -e "  cPanel URL    : ${BOLD}${YELLOW}https://${SERVER_IP}:2083${NC}"
echo -e "  Webmail URL   : ${BOLD}${YELLOW}https://${SERVER_IP}:2096${NC}"
echo ""
echo -e "  Admin User    : ${BOLD}root${NC}"
echo -e "  Password      : (Your Ubuntu VPS root password)"
echo ""
echo -e "  Service       : systemctl status facezila"
echo -e "  Logs          : journalctl -u facezila -f"
echo "=========================================================="
