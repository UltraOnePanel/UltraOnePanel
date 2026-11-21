# UltraOnePanel

> **Next-Generation Cloud Web Hosting & Server Management Suite**  
> Complete cPanel® & WHM® alternative designed for Ubuntu 22.04 LTS and 24.04 LTS.

---

## 🚀 Quick Install (Fresh Server)

Run this one-line command as `root` on any clean **Ubuntu 22.04** or **Ubuntu 24.04 LTS** server:

```bash
curl -fsSL https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/install.sh | sudo bash
```

Upon completion, the installer automatically generates a cryptographically secure random administrator password and displays all URLs and credentials on your terminal.

---

## 🔄 How to Upgrade an Existing Server

To upgrade an existing installation to the latest version **without losing any website files, databases, or settings**, run this command as `root` via SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/upgrade.sh | sudo bash
```

### Or Upgrade via the Web Panel
You can also upgrade with one click directly inside the panel:
1. Log in to **uPanel** (`:2083`) or **UHM** (`:2087`) as `admin`.
2. Navigate to **Preferences** → **System Updates** (`/preferences/updates`).
3. Click **Check for Updates** and then **Apply Update**.

### What the Upgrade preserves:
- ✅ **100% Zero Data Loss:** All domains, websites (`/www/wwwroot/*`), databases, user accounts, DNS zones, and email inboxes remain completely untouched.
- ✅ **Automated Backup:** Automatically generates a safety rollback archive in `/var/backups/facezila/` before applying changes.
- ✅ **Zero Config Overwrite:** Retains your `.env` configuration, license tokens, and SSL certificates.

---

## 🛠️ CLI Management (`upanel` Command Utility)

UltraOnePanel includes a dedicated command-line utility for instant server and credential management:

```bash
# View all login URLs, ports, username, and password
upanel info
# (alias: upanel default or facezila info)

# Change or auto-generate a strong admin password
upanel password <new_password>
# (leaving password blank automatically generates a fresh 16-character secure password)

# Check all listening control panel and service ports
upanel ports

# Check system health and running services (nginx, mariadb, dovecot, etc.)
upanel status

# Restart the UltraOnePanel service
upanel restart

# Update panel to the latest version via CLI
upanel update

# Check current version
upanel version
```

---

## 🌐 Panel Access & Standard Ports

| Interface | Port (SSL) | Port (HTTP Redirect) | Purpose |
| :--- | :--- | :--- | :--- |
| **UHM (WebHost Manager)** | `:2087` | `:2086` | Server, Reseller & Account Administration |
| **uPanel (Client Panel)** | `:2083` | `:2082` | Website, Files, Databases & Email Management |
| **Webmail (Roundcube)** | `:2096` | `:2095` | Secure Webmail Client |
| **phpMyAdmin** | `https://<IP>:2083/phpmyadmin/` | — | MySQL / MariaDB Database Manager |
| **phpPgAdmin** | `https://<IP>:2083/phppgadmin/` | — | PostgreSQL Database Manager |
| **Web Traffic** | `:443` | `:80` | Public Website HTTP / HTTPS Traffic |
| **FTP** | `:21` | — | Secure File Transfer Protocol |
| **DNS** | `:53` | — | BIND9 Authoritative Nameserver |

- **Default Admin User:** `admin`
- **Default Password:** Cryptographically generated on first setup (view anytime with `upanel info` or check `/root/upanel_login.txt`)

---

## 📦 Key Features

- **Multi-PHP Selector:** Full support for PHP 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, and 8.5 with live extension toggles and per-domain inheritance.
- **Relational Databases:** MySQL, MariaDB, and PostgreSQL with one-click phpMyAdmin / phpPgAdmin integration.
- **Email Infrastructure:** Postfix & Dovecot IMAP/POP3, DKIM, SPF, and automatic mail routing.
- **DNS Server:** BIND9 DNS management with automated zone provisioning.
- **Free Automated SSL:** One-click Let's Encrypt / Certbot SSL certificate issuance and auto-renewal.
- **Isolated Developer Terminal:** Real PTY WebSocket terminal with domain chroot isolation.
- **Security:** UFW firewall and Fail2ban brute-force protection.

---

## 📋 Service Management

```bash
# Check panel status
systemctl status facezila

# Restart panel
systemctl restart facezila

# View real-time logs
journalctl -u facezila -f
```

---

## 📄 License

Proprietary Software — All rights reserved © UltraOnePanel.
