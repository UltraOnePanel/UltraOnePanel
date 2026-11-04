# UltraOnePanel

> **Next-Generation Cloud Web Hosting & Server Management Suite**  
> Complete cPanel® & WHM® alternative designed for Ubuntu 22.04 LTS and 24.04 LTS.

---

## 🚀 Quick Install (One-Line Command)

Run this command as `root` on any clean, freshly installed **Ubuntu 22.04** or **Ubuntu 24.04 LTS** server:

```bash
curl -fsSL https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/install.sh | sudo bash
```

---

## 🌐 Panel Access & Standard Ports

Once installation finishes, your panel is immediately live:

| Service | Port | Description |
| :--- | :--- | :--- |
| **WHM (WebHost Manager)** | `:2087` (HTTPS) | Server, Reseller & Account Administration |
| **cPanel (End-User Panel)** | `:2083` (HTTPS) | Website, Files, Databases & Email Management |
| **Webmail** | `:2096` (HTTPS) | Webmail client interface |
| **Standard HTTP / HTTPS** | `:80` / `:443` | Public website traffic |
| **FTP** | `:21` | Secure File Transfer Protocol |

- **Default Admin User:** `root`
- **Default Password:** Your server's Ubuntu root password

---

## 📦 What UltraOnePanel Includes

- **Full Web Stack:** Nginx Reverse Proxy, PHP-FPM (multi-version support), Node.js, Python.
- **Relational Databases:** MySQL / MariaDB and PostgreSQL with phpMyAdmin and phpPgAdmin.
- **Mail Server:** Postfix & Dovecot IMAP/POP3, DKIM, SPF, and automatic mail routing.
- **DNS Server:** BIND9 DNS management with automated zone provisioning.
- **Free Automated SSL:** One-click Let's Encrypt / Certbot SSL certificate issuance and auto-renewal.
- **Isolated Developer Terminal:** Real PTY WebSocket terminal with domain chroot isolation.
- **Security:** UFW firewall and Fail2ban brute-force protection.

---

## 🛠️ Service Management

To check status, restart, or view real-time logs on your server:

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
