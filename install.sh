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
RELEASE_URL="${RELEASE_URL:-https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/ultraonepanel-latest.tar.gz}"
export DEBIAN_FRONTEND=noninteractive

# 1. Privileges & OS verification
[ "$(id -u)" -eq 0 ] || die "This installer must be run as root (or with sudo)."
[ -f /etc/os-release ] || die "Unsupported Linux distribution."
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || warn "UltraOnePanel targets Ubuntu (22.04/24.04); detected ${NAME:-unknown}. Proceeding."

SERVER_IP="$(curl -s -m 5 https://api.ipify.org || hostname -I | awk '{print $1}')"

# 2. System dependencies & Core Hosting Stack
step "[1/6] Installing system packages and hosting stack"

# Stop background update services so they don't contest package locks during installation
systemctl stop unattended-upgrades apt-daily.service apt-daily.timer apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true

# Helper to check if any APT or DPKG process is running or holding lock files
is_apt_locked() {
  if command -v fuser >/dev/null 2>&1; then
    fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/cache/apt/archives/lock >/dev/null 2>&1 && return 0
  fi
  pgrep -f "(apt-get|dpkg|unattended-upgrade)" >/dev/null 2>&1 && return 0
  return 1
}

# Wait if cloud-init, unattended-upgrades, or background apt processes are running on first boot
if is_apt_locked; then
  wait_cycles=0
  max_wait=100  # Up to 300s (5 minutes)
  while is_apt_locked && [ $wait_cycles -lt $max_wait ]; do
    echo "Waiting for background system updates (apt/unattended-upgrades) to release lock ($((wait_cycles * 3))s / 300s)..."
    sleep 3
    wait_cycles=$((wait_cycles + 1))
  done
  if is_apt_locked; then
    warn "Background package lock held for over 300s. Safely terminating background apt process..."
    killall -9 apt-get apt unattended-upgrade-shutdown unattended-upgrades 2>/dev/null || true
    if command -v fuser >/dev/null 2>&1; then
      fuser -k -9 /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
    fi
    rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
    dpkg --configure -a 2>/dev/null || true
  fi
fi

# Pre-seed postfix debconf selections for completely non-interactive installation
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections 2>/dev/null || true
echo "postfix postfix/mailname string localhost" | debconf-set-selections 2>/dev/null || true

# Fix incompatible dovecot.conf from prior hosting stacks or Dovecot 2.4 remnants
if [ -f /etc/dovecot/dovecot.conf ] && grep -q "dovecot_config_version" /etc/dovecot/dovecot.conf 2>/dev/null; then
  warn "Incompatible dovecot.conf detected. Resetting to standard Ubuntu configuration..."
  mv /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak 2>/dev/null || true
  mkdir -p /etc/dovecot
  cat > /etc/dovecot/dovecot.conf <<'EOF'
!include_try /usr/share/dovecot/protocols.d/*.protocol
listen = *, ::
base_dir = /var/run/dovecot/
!include conf.d/*.conf
!include_try local.conf
EOF
fi

# Recover from any interrupted dpkg runs
dpkg --configure -a 2>/dev/null || true

# Unhold any held packages from prior hosting tools/cloud images
if command -v apt-mark >/dev/null 2>&1; then
  HELD_PKGS=$(apt-mark showhold 2>/dev/null || true)
  if [ -n "$HELD_PKGS" ]; then
    warn "Unholding held packages: $HELD_PKGS"
    apt-mark unhold $HELD_PKGS >/dev/null 2>&1 || true
  fi
fi

# Helper to install packages with automatic retry and package-list refresh on mirror 404s
apt_install_with_retry() {
  local pkgs=("$@")
  local attempt=1
  local max_attempts=4
  while [ "$attempt" -le "$max_attempts" ]; do
    if apt-get -o DPkg::Lock::Timeout=300 install -y --allow-change-held-packages --fix-missing \
      -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "${pkgs[@]}"; then
      return 0
    fi
    warn "Package download or installation encountered a mirror sync error / 404 (attempt $attempt/$max_attempts)."
    warn "Refreshing package index from mirrors and retrying..."
    sleep 3
    apt-get -o DPkg::Lock::Timeout=300 update -y || true
    attempt=$((attempt + 1))
  done
  die "Failed to install required system packages after $max_attempts attempts."
}

apt-get -o DPkg::Lock::Timeout=300 update -y

CORE_PACKAGES=(
  curl wget ca-certificates gnupg lsb-release tar zip unzip openssl sqlite3 cron build-essential python3
  nginx mariadb-server certbot
  postgresql postgresql-contrib phppgadmin php-pgsql
  php-fpm php-mysql php-cli php-curl php-mbstring php-xml php-zip php-gd php-intl php-bcmath php-opcache php-sqlite3
  postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd ssl-cert
  bind9 bind9utils vsftpd ufw fail2ban
)
apt_install_with_retry "${CORE_PACKAGES[@]}"

# Install Node.js 20 LTS if not present
if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]; then
  step "Installing Node.js 20 LTS"
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get -o DPkg::Lock::Timeout=300 update -y
  apt_install_with_retry nodejs
fi

# Ensure SSL certificate is generated for Panel & Webmail
mkdir -p /etc/facezila/ssl
if [ ! -f /etc/facezila/ssl/panel.crt ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /etc/facezila/ssl/panel.key -out /etc/facezila/ssl/panel.crt \
    -subj "/CN=${SERVER_IP}" >/dev/null 2>&1
  chmod 600 /etc/facezila/ssl/panel.key
fi

# 3. Configure Database, phpMyAdmin, phpPgAdmin, Roundcube Webmail & Nginx
step "[2/6] Configuring MariaDB, PostgreSQL, Webmail and Database Admin"
systemctl enable --now mariadb 2>/dev/null || systemctl enable --now mysql 2>/dev/null || true
systemctl enable --now postgresql 2>/dev/null || true
systemctl disable --now apache2 2>/dev/null || true
systemctl mask apache2 2>/dev/null || true

# phpPgAdmin configuration
if [ -f /etc/phppgadmin/config.inc.php ]; then
  sed -i "s/\$conf\['extra_login_security'\] = true;/\$conf\['extra_login_security'\] = false;/g" /etc/phppgadmin/config.inc.php
  sed -i "s/\$conf\['owned_only'\] = true;/\$conf\['owned_only'\] = false;/g" /etc/phppgadmin/config.inc.php
fi

# Setup Database Admin directory for phpMyAdmin & phpPgAdmin
mkdir -p /var/www/database-admin
if [ ! -d /var/www/database-admin/phpmyadmin ]; then
  step "Installing phpMyAdmin"
  mkdir -p /var/www/database-admin/phpmyadmin
  curl -fsSL https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-all-languages.tar.gz -o /tmp/pma.tar.gz
  tar -xzf /tmp/pma.tar.gz --strip-components=1 -C /var/www/database-admin/phpmyadmin
  rm -f /tmp/pma.tar.gz

  PMA_SECRET=$(openssl rand -hex 16)
  cat > /var/www/database-admin/phpmyadmin/config.inc.php <<EOF
<?php
ini_set('session.cookie_path', '/phpmyadmin/');
\$cfg['blowfish_secret'] = '${PMA_SECRET}';
\$cfg['PmaAbsoluteUri'] = '/phpmyadmin/';
\$i = 0;
\$i++;
if (!empty(\$_COOKIE['SignonSession'])) {
    \$cfg['Servers'][\$i]['auth_type'] = 'signon';
    \$cfg['Servers'][\$i]['SignonSession'] = 'SignonSession';
    \$cfg['Servers'][\$i]['SignonURL'] = '/phpmyadmin/index.php';
} else {
    \$cfg['Servers'][\$i]['auth_type'] = 'cookie';
}
\$cfg['Servers'][\$i]['host'] = '127.0.0.1';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['TempDir'] = '/tmp';
EOF

  cat > /var/www/database-admin/phpmyadmin/sso.php << 'EOF_PMA_SSO'
<?php
@ini_set('display_errors', '0');
error_reporting(0);
define('PMA_SSO_SECRET', 'UltraOnePanel_PMA_Secret_Key_2026_Secure');
\$token = isset(\$_GET['token']) ? trim(\$_GET['token']) : '';
\$db = isset(\$_GET['db']) ? trim(\$_GET['db']) : '';
if (empty(\$token)) { http_response_code(403); die('Access Denied: Missing SSO token'); }
\$parts = explode('.', \$token);
if (count(\$parts) !== 3) { http_response_code(403); die('Invalid Token'); }
list(\$expStr, \$b64Payload, \$sig) = \$parts;
if (time() > intval(\$expStr)) { http_response_code(403); die('Token Expired'); }
if (!hash_equals(hash_hmac('sha256', \$expStr . '.' . \$b64Payload, PMA_SSO_SECRET), \$sig)) { http_response_code(403); die('Invalid Signature'); }
\$decoded = base64_decode(\$b64Payload);
if (\$decoded !== false && !empty(\$decoded)) {
    if (strpos(\$decoded, ':') !== false) { list(\$pDb) = explode(':', \$decoded, 2); if (!empty(\$pDb)) \$db = \$pDb; }
    else { \$db = \$decoded; }
}
\$mysqlRoot = '';
if (file_exists('/www/server/panel/data/default.db')) {
    \$out = @shell_exec('sqlite3 /www/server/panel/data/default.db "SELECT mysql_root FROM config LIMIT 1;" 2>/dev/null');
    if (\$out) \$mysqlRoot = trim(\$out);
}
if (empty(\$mysqlRoot) && file_exists('/root/.mysql_secret')) {
    \$out = @file_get_contents('/root/.mysql_secret');
    if (\$out) \$mysqlRoot = trim(\$out);
}
if (empty(\$mysqlRoot) && file_exists('/etc/mysql/debian.cnf')) {
    preg_match('/password\\s*=\\s*(\\S+)/', file_get_contents('/etc/mysql/debian.cnf'), \$m);
    if (!empty(\$m[1])) \$mysqlRoot = \$m[1];
}
ini_set('session.use_cookies', 'true');
session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'domain' => '', 'secure' => false, 'httponly' => true, 'samesite' => 'Lax']);
session_name('SignonSession');
session_start();
\$_SESSION['PMA_single_signon_user'] = 'root';
\$_SESSION['PMA_single_signon_password'] = \$mysqlRoot;
\$_SESSION['PMA_single_signon_host'] = 'localhost';
\$_SESSION['PMA_single_signon_port'] = '';
\$_SESSION['PMA_single_signon_cfgupdate'] = [];
\$_SESSION['PMA_single_signon_HMAC_secret'] = hash('sha1', uniqid((string)mt_rand(), true));
session_write_close();
\$redirect = !empty(\$db) ? '/phpmyadmin/index.php?route=/database/structure&db=' . urlencode(\$db) : '/phpmyadmin/index.php';
header('Location: ' . \$redirect);
exit;
EOF_PMA_SSO
  chmod 644 /var/www/database-admin/phpmyadmin/sso.php
fi

if [ -d /usr/share/phppgadmin ]; then
  ln -sfn /usr/share/phppgadmin /var/www/database-admin/phppgadmin
fi
chown -R www-data:www-data /var/www/database-admin

# Install Roundcube Webmail on /var/www/roundcube
if [ ! -d /var/www/roundcube ]; then
  step "Installing Roundcube Webmail"
  mkdir -p /var/www/roundcube /var/lib/roundcube
  curl -fsSL https://github.com/roundcube/roundcubemail/releases/download/1.7.6/roundcubemail-1.7.6-complete.tar.gz -o /tmp/roundcube.tar.gz
  tar -xzf /tmp/roundcube.tar.gz --strip-components=1 -C /var/www/roundcube
  rm -f /tmp/roundcube.tar.gz

  if [ -f /var/www/roundcube/SQL/sqlite.initial.sql ]; then
    sqlite3 /var/lib/roundcube/roundcube.db < /var/www/roundcube/SQL/sqlite.initial.sql
  fi
  chown -R www-data:www-data /var/lib/roundcube
  chmod 770 /var/lib/roundcube
  chmod 660 /var/lib/roundcube/roundcube.db 2>/dev/null || true
  rm -rf /var/www/roundcube/installer

  RC_KEY=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
  cat > /var/www/roundcube/config/config.inc.php <<EOF
<?php
\$config['db_dsnw'] = 'sqlite:////var/lib/roundcube/roundcube.db?mode=0646';
\$config['imap_host'] = 'localhost:143';
\$config['smtp_host'] = 'localhost:25';
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['support_url'] = '';
\$config['product_name'] = 'UltraOnePanel Webmail';
\$config['des_key'] = '${RC_KEY}';
\$config['plugins'] = array('archive', 'zipdownload');
\$config['skin'] = 'elastic';
\$config['enable_installer'] = false;
EOF
  chown -R www-data:www-data /var/www/roundcube
fi

# Detect PHP-FPM socket and enable PHP services
for fpm in /etc/init.d/php*-fpm; do [ -e "$fpm" ] && systemctl enable --now "$(basename "$fpm")" 2>/dev/null || true; done

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")
PHP_SOCK="/run/php/php${PHP_VER}-fpm.sock"

mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/00-php-upstream.conf <<EOF
upstream php_fpm_backend {
    server unix:${PHP_SOCK};
}
EOF

# Nginx vhost for Database Admin (127.0.0.1:888)
cat > /etc/nginx/conf.d/database-admin.conf <<'EOF'
server {
    listen 127.0.0.1:888;
    server_name 127.0.0.1 localhost;

    root /var/www/database-admin;
    index index.php index.html;

    client_max_body_size 500M;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass php_fpm_backend;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# Nginx vhost for Roundcube Webmail (Port 2096 HTTPS)
cat > /etc/nginx/conf.d/webmail.conf <<'EOF'
server {
    listen 2096 ssl;
    listen [::]:2096 ssl;
    server_name _;

    ssl_certificate /etc/facezila/ssl/panel.crt;
    ssl_certificate_key /etc/facezila/ssl/panel.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /var/www/roundcube;
    index index.php index.html;

    client_max_body_size 50M;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass php_fpm_backend;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ ^/(README|INSTALL|LICENSE|CHANGELOG|UPGRADING)$ {
        deny all;
    }
    location ~ ^/(bin|SQL|config|temp|logs)/ {
        deny all;
    }
    location ~ /\. {
        deny all;
    }
}
EOF

systemctl enable --now nginx 2>/dev/null || true
nginx -t && systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true

# 4. Download and Install Pre-compiled Package
step "[3/6] Downloading UltraOnePanel pre-compiled package"
mkdir -p "$INSTALL_DIR" "$DATA_DIR" /var/log/facezila /etc/facezila/ssl
curl -k -fsSL "$RELEASE_URL" -o /tmp/ultraonepanel.tar.gz 2>/dev/null || wget --no-check-certificate -qO /tmp/ultraonepanel.tar.gz "$RELEASE_URL"
tar -xzf /tmp/ultraonepanel.tar.gz -C "$INSTALL_DIR"
rm -f /tmp/ultraonepanel.tar.gz

# Deploy default skeleton files
mkdir -p /etc/skel/public_html
if [ -d "$INSTALL_DIR/templates/skel" ]; then
  cp -f "$INSTALL_DIR"/templates/skel/* /etc/skel/public_html/ 2>/dev/null || true
  chmod -R 755 /etc/skel/public_html 2>/dev/null || true
elif [ -d "$INSTALL_DIR/src/templates/skel" ]; then
  cp -f "$INSTALL_DIR"/src/templates/skel/* /etc/skel/public_html/ 2>/dev/null || true
  chmod -R 755 /etc/skel/public_html 2>/dev/null || true
fi

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
LICENSE_SERVER_URL=https://license.ultraonepanel.com
EOF
  if [ -f /opt/license-server/server.js ] || [ -f /opt/license-server/licenses.json ]; then
    echo "IS_LICENSE_SERVER=true" >> "$INSTALL_DIR/.env"
  fi
  chmod 600 "$INSTALL_DIR/.env"
else
  if grep -q "LICENSE_SERVER_URL" "$INSTALL_DIR/.env"; then
    sed -i "s|LICENSE_SERVER_URL=.*|LICENSE_SERVER_URL=https://license.ultraonepanel.com|" "$INSTALL_DIR/.env"
  else
    echo "LICENSE_SERVER_URL=https://license.ultraonepanel.com" >> "$INSTALL_DIR/.env"
  fi
fi

# 6. Firewall & Service Management
step "[6/6] Configuring firewall and systemd service"
for port in 22/tcp 80/tcp 443/tcp 2083/tcp 2087/tcp 2096/tcp 21/tcp 25/tcp 465/tcp 587/tcp 993/tcp 995/tcp 53; do
  ufw allow "$port" >/dev/null 2>&1 || true
done
ufw allow ssh >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

cat > /etc/systemd/system/facezila.service <<EOF
[Unit]
Description=UltraOnePanel Hosting Control Panel
After=network.target nginx.service mariadb.service postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=$(command -v node) ${INSTALL_DIR}/server.bundle.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Setup Administrator Account & Strong Random Password
step "Configuring Administrator Account & Access Credentials"
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

ADMIN_USER="admin"
ADMIN_PASS=""

if [ -f "$DATA_DIR/default.pl" ]; then
  ADMIN_PASS=$(cat "$DATA_DIR/default.pl" 2>/dev/null | tr -d '\r\n')
fi

if [ -z "$ADMIN_PASS" ]; then
  ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' < /dev/urandom | head -c 16 2>/dev/null || true)
  if [ -z "$ADMIN_PASS" ] || [ ${#ADMIN_PASS} -lt 16 ]; then
    ADMIN_PASS=$(openssl rand -base64 24 | LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' | head -c 16)
  fi
  echo "$ADMIN_PASS" > "$DATA_DIR/default.pl"
  chmod 600 "$DATA_DIR/default.pl"
fi

cd "$INSTALL_DIR"
node -e "
const fs = require('fs');
const bcrypt = require('bcryptjs');
const adminFile = '$DATA_DIR/admin.json';
const pass = '$ADMIN_PASS';
const uname = '$ADMIN_USER';
let data = {};
try { data = JSON.parse(fs.readFileSync(adminFile, 'utf8')); } catch(e) {}
data.username = data.username || uname;
data.hash = bcrypt.hashSync(pass, 12);
data.passwordChangedAt = Date.now();
fs.writeFileSync(adminFile, JSON.stringify(data, null, 2), { mode: 0o600 });
"

# Save root credentials card
cat > /root/upanel_login.txt <<EOF
========================================================================
                   UltraOnePanel Access Details
========================================================================
Server IP Address : ${SERVER_IP}

[ Web Interface URLs & Ports ]
  * UHM Reseller/Admin Panel (SSL)  : https://${SERVER_IP}:2087
    UHM Reseller/Admin Panel (HTTP) : http://${SERVER_IP}:2086

  * uPanel End-User Panel (SSL)     : https://${SERVER_IP}:2083
    uPanel End-User Panel (HTTP)    : http://${SERVER_IP}:2082

  * Webmail Client (SSL)            : https://${SERVER_IP}:2096
    Webmail Client (HTTP)           : http://${SERVER_IP}:2095

  * phpMyAdmin (Database Manager)   : https://${SERVER_IP}:2083/phpmyadmin/
  * phpPgAdmin (PostgreSQL Manager) : https://${SERVER_IP}:2083/phppgadmin/

[ Administrator Credentials ]
  * Username : ${ADMIN_USER}
  * Password : ${ADMIN_PASS}

[ Useful CLI Commands ]
  * View this info anytime  : upanel info
  * Reset admin password    : upanel password <new_password>
  * View port status        : upanel ports
  * Check panel status      : upanel status
  * Restart panel service   : upanel restart
  * Update panel software   : upanel update
========================================================================
EOF
chmod 600 /root/upanel_login.txt

# Install upanel CLI command utility
cat > /usr/local/bin/upanel << 'CLIEOF'
#!/bin/bash
# ==============================================================================
# UltraOnePanel (uPanel & UHM) Command Line Utility
# ==============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
DATA_DIR="/var/lib/facezila"
INSTALL_DIR="/opt/facezila"

show_info() {
  SERVER_IP=$(curl -s -m 4 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$SERVER_IP" ] && SERVER_IP="127.0.0.1"

  ADMIN_USER="admin"
  if [ -f "$DATA_DIR/admin.json" ]; then
    ADMIN_USER=$(node -e "try { const d = JSON.parse(require('fs').readFileSync('$DATA_DIR/admin.json')); console.log(d.username || 'admin'); } catch(e) { console.log('admin'); }" 2>/dev/null || echo "admin")
  fi

  ADMIN_PASS=""
  if [ -f "$DATA_DIR/default.pl" ]; then
    ADMIN_PASS=$(cat "$DATA_DIR/default.pl" 2>/dev/null | tr -d '\r\n')
  fi

  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  echo -e "${GREEN}${BOLD}                   UltraOnePanel Access Details${NC}"
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  echo -e "  Server IP Address : ${BOLD}${YELLOW}${SERVER_IP}${NC}"
  echo ""
  echo -e "${BOLD}[ Web Interface URLs & Ports ]${NC}"
  echo -e "  * ${BOLD}UHM Reseller/Admin (SSL)${NC}  : ${GREEN}https://${SERVER_IP}:2087${NC}"
  echo -e "    UHM Reseller/Admin (HTTP) : http://${SERVER_IP}:2086"
  echo ""
  echo -e "  * ${BOLD}uPanel End-User (SSL)${NC}     : ${GREEN}https://${SERVER_IP}:2083${NC}"
  echo -e "    uPanel End-User (HTTP)    : http://${SERVER_IP}:2082"
  echo ""
  echo -e "  * ${BOLD}Webmail Client (SSL)${NC}      : ${GREEN}https://${SERVER_IP}:2096${NC}"
  echo -e "    Webmail Client (HTTP)     : http://${SERVER_IP}:2095"
  echo ""
  echo -e "  * ${BOLD}phpMyAdmin (SSL)${NC}          : ${GREEN}https://${SERVER_IP}:2083/phpmyadmin/${NC}"
  echo -e "  * ${BOLD}phpPgAdmin (SSL)${NC}          : ${GREEN}https://${SERVER_IP}:2083/phppgadmin/${NC}"
  echo ""
  echo -e "${CYAN}------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}[ Administrator Credentials ]${NC}"
  echo -e "${CYAN}------------------------------------------------------------------------${NC}"
  echo -e "  Username : ${BOLD}${YELLOW}${ADMIN_USER}${NC}"
  if [ -n "$ADMIN_PASS" ]; then
    echo -e "  Password : ${BOLD}${GREEN}${ADMIN_PASS}${NC}"
  else
    echo -e "  Password : ${YELLOW}[Stored as secure bcrypt hash. Run 'upanel password' to reset]${NC}"
  fi
  echo ""
  echo -e "  Credentials file: ${CYAN}/root/upanel_login.txt${NC} (chmod 600)"
  echo -e "${CYAN}------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}[ Quick Management Commands ]${NC}"
  echo -e "  * View this info anytime  : ${CYAN}upanel info${NC} (or: ${CYAN}facezila info${NC})"
  echo -e "  * Change admin password   : ${CYAN}upanel password <new_password>${NC}"
  echo -e "  * View port status        : ${CYAN}upanel ports${NC}"
  echo -e "  * Check service status    : ${CYAN}upanel status${NC}"
  echo -e "  * Restart panel service   : ${CYAN}upanel restart${NC}"
  echo -e "  * Update panel software   : ${CYAN}upanel update${NC}"
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
}

set_password() {
  NEW_PASS="$1"
  if [ -z "$NEW_PASS" ]; then
    NEW_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' < /dev/urandom | head -c 16 2>/dev/null || true)
    if [ -z "$NEW_PASS" ] || [ ${#NEW_PASS} -lt 16 ]; then
      NEW_PASS=$(openssl rand -base64 24 | LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' | head -c 16)
    fi
    echo -e "${YELLOW}No password specified. Generated strong random password.${NC}"
  fi

  ADMIN_USER="admin"
  if [ -f "$DATA_DIR/admin.json" ]; then
    ADMIN_USER=$(node -e "try { const d = JSON.parse(require('fs').readFileSync('$DATA_DIR/admin.json')); console.log(d.username || 'admin'); } catch(e) { console.log('admin'); }" 2>/dev/null || echo "admin")
  fi

  mkdir -p "$DATA_DIR"
  echo "$NEW_PASS" > "$DATA_DIR/default.pl"
  chmod 600 "$DATA_DIR/default.pl"

  cd "$INSTALL_DIR" 2>/dev/null || cd /root
  node -e "
const fs = require('fs');
const bcrypt = require('bcryptjs');
const adminFile = '$DATA_DIR/admin.json';
const pass = '$NEW_PASS';
let data = {};
try { data = JSON.parse(fs.readFileSync(adminFile, 'utf8')); } catch(e) {}
data.username = data.username || '$ADMIN_USER';
data.hash = bcrypt.hashSync(pass, 12);
data.passwordChangedAt = Date.now();
fs.writeFileSync(adminFile, JSON.stringify(data, null, 2), { mode: 0o600 });
"

  SERVER_IP=$(curl -s -m 4 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$SERVER_IP" ] && SERVER_IP="127.0.0.1"

  cat > /root/upanel_login.txt <<EOF
========================================================================
                   UltraOnePanel Access Details
========================================================================
Server IP Address : ${SERVER_IP}

[ Web Interface URLs & Ports ]
  * UHM Reseller/Admin Panel (SSL)  : https://${SERVER_IP}:2087
    UHM Reseller/Admin Panel (HTTP) : http://${SERVER_IP}:2086

  * uPanel End-User Panel (SSL)     : https://${SERVER_IP}:2083
    uPanel End-User Panel (HTTP)    : http://${SERVER_IP}:2082

  * Webmail Client (SSL)            : https://${SERVER_IP}:2096
    Webmail Client (HTTP)           : http://${SERVER_IP}:2095

  * phpMyAdmin (Database Manager)   : https://${SERVER_IP}:2083/phpmyadmin/
  * phpPgAdmin (PostgreSQL Manager) : https://${SERVER_IP}:2083/phppgadmin/

[ Administrator Credentials ]
  * Username : ${ADMIN_USER}
  * Password : ${NEW_PASS}

[ Useful CLI Commands ]
  * View this info anytime  : upanel info
  * Reset admin password    : upanel password <new_password>
  * View port status        : upanel ports
  * Check panel status      : upanel status
  * Restart panel service   : upanel restart
  * Update panel software   : upanel update
========================================================================
EOF
  chmod 600 /root/upanel_login.txt

  echo -e "${GREEN}${BOLD}âœ“ Admin password successfully updated!${NC}"
  echo -e "  Username : ${BOLD}${YELLOW}${ADMIN_USER}${NC}"
  echo -e "  Password : ${BOLD}${GREEN}${NEW_PASS}${NC}"
  echo -e "  Saved to : ${CYAN}/root/upanel_login.txt${NC}"
}

show_ports() {
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  echo -e "${GREEN}${BOLD}                 UltraOnePanel Listening Ports & Services${NC}"
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  printf "%-8s %-28s %-12s %-15s\n" "PORT" "SERVICE" "PROTOCOL" "STATUS"
  echo "------------------------------------------------------------------------"

  check_port() {
    local p="$1"; local name="$2"; local proto="$3"
    local listening="CLOSED"
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
      listening="${GREEN}LISTENING${NC}"
    else
      listening="${RED}INACTIVE${NC}"
    fi
    printf "%-8s %-28s %-12s " "$p" "$name" "$proto"
    echo -e "$listening"
  }

  check_port "2087" "UHM Admin (HTTPS)" "TCP/SSL"
  check_port "2086" "UHM Admin (HTTP redirect)" "TCP"
  check_port "2083" "uPanel User (HTTPS)" "TCP/SSL"
  check_port "2082" "uPanel User (HTTP redirect)" "TCP"
  check_port "2096" "Webmail (HTTPS)" "TCP/SSL"
  check_port "2095" "Webmail (HTTP redirect)" "TCP"
  check_port "80"   "Nginx HTTP" "TCP"
  check_port "443"  "Nginx HTTPS" "TCP/SSL"
  check_port "21"   "FTP Service" "TCP"
  check_port "25"   "SMTP Mail Transfer" "TCP"
  check_port "465"  "SMTPS Mail Submission" "TCP/SSL"
  check_port "587"  "Submission Mail" "TCP"
  check_port "993"  "IMAPS Secure Mailbox" "TCP/SSL"
  check_port "995"  "POP3S Secure Mailbox" "TCP/SSL"
  check_port "3306" "MariaDB / MySQL" "TCP"
  check_port "5432" "PostgreSQL" "TCP"
  check_port "53"   "BIND9 DNS" "TCP/UDP"
  echo -e "${CYAN}========================================================================${NC}"
}

show_status() {
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  echo -e "${GREEN}${BOLD}                     UltraOnePanel Services Status${NC}"
  echo -e "${CYAN}${BOLD}========================================================================${NC}"
  for svc in facezila nginx mariadb postgresql dovecot postfix named; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      printf "%-20s : ${GREEN}ACTIVE (Running)${NC}\n" "$svc"
    else
      printf "%-20s : ${RED}INACTIVE / STOPPED${NC}\n" "$svc"
    fi
  done
  echo -e "${CYAN}========================================================================${NC}"
}

restart_panel() {
  echo -e "${YELLOW}Restarting UltraOnePanel service...${NC}"
  systemctl restart facezila.service
  sleep 1
  if systemctl is-active --quiet facezila; then
    echo -e "${GREEN}${BOLD}âœ“ UltraOnePanel service restarted and active.${NC}"
  else
    echo -e "${RED}${BOLD}âœ— Failed to restart facezila service. Check journalctl -u facezila -n 50${NC}"
  fi
}

update_panel() {
  echo -e "${CYAN}${BOLD}========================================================${NC}"
  echo -e "${GREEN}${BOLD} UltraOnePanel (uPanel & UHM) Automatic Updater${NC}"
  echo -e "${CYAN}${BOLD}========================================================${NC}"
  echo "Triggering panel update process..."
  if [ -f "/opt/facezila/server.bundle.js" ]; then
    node /opt/facezila/server.bundle.js --update || true
  elif [ -f "/opt/facezila/src/services/update.service.js" ]; then
    node -e "const updater = require('/opt/facezila/src/services/update.service.js'); updater.applyUpdate().then(r => console.log('Result:', r.message)).catch(e => console.error('Error:', e.message));" || true
  fi
  echo -e "${CYAN}========================================================${NC}"
}

show_version() {
  cat /opt/facezila/version.json 2>/dev/null || echo '{"version":"1.3.0"}'
}

show_help() {
  echo -e "${BOLD}Usage:${NC} upanel [command]  (or: facezila [command])"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo -e "  ${CYAN}info | default | credentials${NC}  Display all access URLs, ports, username and password"
  echo -e "  ${CYAN}password [<new_password>]${NC}    Change admin password or generate a new random password"
  echo -e "  ${CYAN}ports${NC}                        List all control panel and hosting listening ports"
  echo -e "  ${CYAN}status${NC}                       Check status of all panel services"
  echo -e "  ${CYAN}restart${NC}                      Restart UltraOnePanel daemon"
  echo -e "  ${CYAN}update${NC}                       Update UltraOnePanel to the latest version"
  echo -e "  ${CYAN}version | -v${NC}                 Show current installed version"
  echo -e "  ${CYAN}help${NC}                         Show this help menu"
  echo ""
}

case "${1:-}" in
  info|default|credentials|login)
    show_info
    ;;
  password|passwd)
    set_password "${2:-}"
    ;;
  ports|port)
    show_ports
    ;;
  status)
    show_status
    ;;
  restart)
    restart_panel
    ;;
  update)
    update_panel
    ;;
  version|-v)
    show_version
    ;;
  help|-h|--help)
    show_help
    ;;
  "")
    show_help
    show_info
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    show_help
    exit 1
    ;;
esac
CLIEOF

chmod +x /usr/local/bin/upanel
ln -sf /usr/local/bin/upanel /usr/local/bin/facezila

systemctl daemon-reload
systemctl enable --now facezila.service
systemctl restart facezila.service

# Display Final Completion Card
echo -e "${CYAN}${BOLD}========================================================================${NC}"
echo -e "${GREEN}${BOLD}                   UltraOnePanel Installed Successfully!${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"
echo -e "  Server IP Address : ${BOLD}${YELLOW}${SERVER_IP}${NC}"
echo ""
echo -e "${BOLD}[ Web Interface URLs & Ports ]${NC}"
echo -e "  * ${BOLD}UHM Reseller/Admin (SSL)${NC}  : ${GREEN}https://${SERVER_IP}:2087${NC}"
echo -e "    UHM Reseller/Admin (HTTP) : http://${SERVER_IP}:2086"
echo ""
echo -e "  * ${BOLD}uPanel End-User (SSL)${NC}     : ${GREEN}https://${SERVER_IP}:2083${NC}"
echo -e "    uPanel End-User (HTTP)    : http://${SERVER_IP}:2082"
echo ""
echo -e "  * ${BOLD}Webmail Client (SSL)${NC}      : ${GREEN}https://${SERVER_IP}:2096${NC}"
echo -e "    Webmail Client (HTTP)     : http://${SERVER_IP}:2095"
echo ""
echo -e "  * ${BOLD}phpMyAdmin (SSL)${NC}          : ${GREEN}https://${SERVER_IP}:2083/phpmyadmin/${NC}"
echo -e "  * ${BOLD}phpPgAdmin (SSL)${NC}          : ${GREEN}https://${SERVER_IP}:2083/phppgadmin/${NC}"
echo ""
echo -e "${CYAN}------------------------------------------------------------------------${NC}"
echo -e "${BOLD}[ Administrator Credentials ]${NC}"
echo -e "${CYAN}------------------------------------------------------------------------${NC}"
echo -e "  Username : ${BOLD}${YELLOW}${ADMIN_USER}${NC}"
echo -e "  Password : ${BOLD}${GREEN}${ADMIN_PASS}${NC}"
echo ""
echo -e "  Credentials file: ${CYAN}/root/upanel_login.txt${NC} (chmod 600)"
echo -e "${CYAN}------------------------------------------------------------------------${NC}"
echo -e "${BOLD}[ Quick Management Commands ]${NC}"
echo -e "  * View credentials & URLs : ${CYAN}upanel info${NC} (or ${CYAN}facezila info${NC})"
echo -e "  * Reset admin password    : ${CYAN}upanel password <new_password>${NC}"
echo -e "  * View open ports         : ${CYAN}upanel ports${NC}"
echo -e "  * Service status          : ${CYAN}upanel status${NC}"
echo -e "  * Restart panel service   : ${CYAN}upanel restart${NC}"
echo -e "  * Update panel software   : ${CYAN}upanel update${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"

