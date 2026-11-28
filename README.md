# UltraOnePanel

[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ultraonepanel.com/docs.php)
[![Live Demo](https://img.shields.io/badge/Live%20Demo-demo.ultraonepanel.com-f97316)](https://demo.ultraonepanel.com)
[![Docs](https://img.shields.io/badge/Docs-ultraonepanel.com%2Fdocs.php-0ea5e9)](https://ultraonepanel.com/docs.php)
[![GitHub](https://img.shields.io/badge/GitHub-UltraOnePanel-181717?logo=github)](https://github.com/UltraOnePanel/UltraOnePanel)

> **Next-Generation Cloud Web Hosting & Server Management Suite**  
> Complete **uPanel** (end-user hosting console) + **UHM** (WebHost Manager & reseller admin) built for Ubuntu 22.04 LTS & 24.04 LTS.

- 🌐 **Website:** [https://ultraonepanel.com](https://ultraonepanel.com)
- 🖥️ **Live Demo:** [https://demo.ultraonepanel.com](https://demo.ultraonepanel.com) (`admin` / `demo1234`)
- 📖 **Documentation:** [https://ultraonepanel.com/docs.php](https://ultraonepanel.com/docs.php)

---

## 🚀 1-Command Install (Fresh Ubuntu 22.04 / 24.04)

Run as `root` on any clean **Ubuntu 22.04** or **Ubuntu 24.04 LTS** server:

```bash
curl -sSO https://install.ultraonepanel.com/install.sh && bash install.sh
```

*(GitHub mirror)*:
```bash
curl -fsSL https://raw.githubusercontent.com/UltraOnePanel/UltraOnePanel/main/install.sh | sudo bash
```

Upon completion, the installer generates a cryptographically secure admin password and prints your **UHM (`:2087`)**, **uPanel (`:2083`)**, and **Webmail (`:2096/mailbox/`)** URLs.

---

## 🔄 Upgrade & Uninstall

### Upgrade an Existing Server (Zero Data Loss)
```bash
curl -fsSL https://install.ultraonepanel.com/upgrade.sh | sudo bash
```
Preserves all websites (`/www/wwwroot/*`), databases, email mailboxes, DNS zones, `.env`, and SSL certificates.

### Uninstall
```bash
curl -sSO https://install.ultraonepanel.com/uninstall.sh && bash uninstall.sh
```

---

## 📸 Screenshots

| **uPanel End-User Dashboard (`:2083`)** | **UHM Account Management (`:2087`)** |
| :---: | :---: |
| ![uPanel Dashboard](https://ultraonepanel.com/upanel-screenshot.png) | ![UHM Accounts](https://ultraonepanel.com/uhm-panel-account-screenshot.png) |

| **File Manager & Code Editor** | **Database & phpMyAdmin Suite** |
| :---: | :---: |
| ![File Manager](https://ultraonepanel.com/upanel-filemanager-screenshot.png) | ![Databases](https://ultraonepanel.com/upanel-database-screenshot.png) |

| **Security & SSL Center** | **Automated Backup & Restore** |
| :---: | :---: |
| ![Security](https://ultraonepanel.com/upanel-security-screenshot.png) | ![Backups](https://ultraonepanel.com/upanel-backup-screenshot.png) |

---

## ⚖️ Comparison: UltraOnePanel vs cPanel / Plesk / CyberPanel

| Feature | **UltraOnePanel** | **cPanel / WHM** | **Plesk** | **CyberPanel** |
| :--- | :---: | :---: | :---: | :---: |
| **1-Command Ubuntu 22.04 / 24.04 Install** | ✅ Yes | ✅ Alma/Ubuntu | ✅ Yes | ✅ Yes |
| **End-User + Admin/Reseller Split (`:2083` / `:2087`)** | ✅ Built-in | ✅ Built-in | ⚠️ Single UI | ⚠️ Single UI |
| **Native Nginx + FastCGI Cache Manager** | ✅ Built-in | ❌ Add-on | ⚠️ Paid Extension | ⚠️ OpenLiteSpeed |
| **Multi-PHP (7.4 – 8.4) + Node.js / Python Apps** | ✅ Built-in | ⚠️ CloudLinux/Paid | ✅ Yes | ⚠️ Limited |
| **WebSocket Terminal & SSH Access Control** | ✅ Per-Account Toggle | ✅ Built-in | ✅ Extension | ❌ No |
| **Custom Branded Webmail (`/mailbox/` on `:2096`)** | ✅ Roundcube + SSO | ✅ Roundcube | ✅ Roundcube | ⚠️ RainLoop |
| **Built-in cPanel `.tar.gz` Migration** | ✅ Included | ✅ Native | ✅ Paid/Migrator | ❌ Manual |
| **AutoSSL (Let's Encrypt) + DNS Zone Editor** | ✅ Included | ✅ Included | ✅ Included | ✅ Included |
| **Pricing** | 💚 **Fraction of cPanel** | 💸 High per-account | 💸 Per-domain tiers | 🆓 / Paid Enterprise |

---

## 🛠️ CLI Management (`upanel`) & Ports

```bash
upanel info       # Show login URLs, ports, and credentials
upanel status     # Check panel & system services
upanel password   # Reset or auto-generate strong admin password
upanel update     # Update to latest release
```

| Service | HTTPS Port | Purpose |
| :--- | :---: | :--- |
| **UHM (Admin / Reseller)** | `:2087` | Server, Packages, Accounts & DNS |
| **uPanel (Client Panel)** | `:2083` | Sites, Files, Databases, Cache & Email |
| **Webmail (`/mailbox/`)** | `:2096` | Branded Roundcube Webmail & SSO |

Full documentation: **[https://ultraonepanel.com/docs.php](https://ultraonepanel.com/docs.php)** · Live Sandbox: **[https://demo.ultraonepanel.com](https://demo.ultraonepanel.com)**
