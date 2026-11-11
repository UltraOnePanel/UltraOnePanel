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
apt-get update -y
apt-get install -y curl wget ca-certificates gnupg lsb-release tar zip unzip openssl sqlite3 cron build-essential python3 \
  nginx mariadb-server certbot \
  postgresql postgresql-contrib phppgadmin php-pgsql \
  php-fpm php-mysql php-cli php-curl php-mbstring php-xml php-zip php-gd php-intl php-bcmath php-opcache php-sqlite3 \
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
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = '127.0.0.1';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['TempDir'] = '/tmp';
EOF
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
LICENSE_SERVER_URL=https://185.70.184.125:2087
EOF
  if [ "${SERVER_IP}" = "185.70.184.125" ]; then
    echo "IS_LICENSE_SERVER=true" >> "$INSTALL_DIR/.env"
  fi
  chmod 600 "$INSTALL_DIR/.env"
else
  if grep -q "LICENSE_SERVER_URL" "$INSTALL_DIR/.env"; then
    sed -i "s|LICENSE_SERVER_URL=.*|LICENSE_SERVER_URL=https://185.70.184.125:2087|" "$INSTALL_DIR/.env"
  else
    echo "LICENSE_SERVER_URL=https://185.70.184.125:2087" >> "$INSTALL_DIR/.env"
  fi
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
echo -e "  UHM Admin URL : ${BOLD}${YELLOW}https://${SERVER_IP}:2087${NC}"
echo -e "  uPanel URL    : ${BOLD}${YELLOW}https://${SERVER_IP}:2083${NC}"
echo -e "  Webmail URL   : ${BOLD}${YELLOW}https://${SERVER_IP}:2096${NC}"
echo -e "  phpMyAdmin    : ${BOLD}${YELLOW}https://${SERVER_IP}:2083/phpmyadmin/${NC}"
echo -e "  phpPgAdmin    : ${BOLD}${YELLOW}https://${SERVER_IP}:2083/phppgadmin/${NC}"
echo ""
echo -e "  Admin User    : ${BOLD}root${NC}"
echo -e "  Password      : (Your Ubuntu VPS root password)"
echo ""
echo -e "  Service       : systemctl status facezila"
echo -e "  Logs          : journalctl -u facezila -f"
echo "=========================================================="

