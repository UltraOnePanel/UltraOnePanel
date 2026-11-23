# uPanel AI Cyber Security & Threat Protection — Project Audit Report
**Document ID:** `UPANEL_SECURITY_AUDIT.md`  
**Date:** November 2026  
**Auditor:** Antigravity AI Systems Engine  
**System:** UltraOnePanel / uPanel Hosting Platform (Production & Local Development)

---

## 1. Executive Summary

This security audit assesses the existing architecture of **UltraOnePanel (uPanel / UHM)** prior to implementing the **AI Cyber Security & Advanced Hosting Protection Module**.

The audit verified all 12 architectural points outlined in `nextplan.md`. The uPanel platform is an enterprise-grade multi-tenant hosting system running on Linux (Ubuntu 22.04/24.04 LTS), utilizing an **Nginx-first** web server architecture, Multi-PHP FPM pools (PHP 7.2 to 8.5), MySQL/MariaDB database backends, and a dual-dashboard interface (**uPanel** on port 2083 for end-users, **UHM** on port 2087 for administrators/resellers).

Existing security components (UFW firewall, Fail2ban jail inspection, WP-Lock CMS hardening, basic regex Nginx WAF, Payment Shield, and RFC 6238 2FA) provide a foundation that can be expanded into an enterprise-grade **Security Center**.

---

## 2. Comprehensive Audit of the 12 Architectural Points

### Point 1: Complete Project Structure
```
G:\xampp\htdocs\facezila\ (Repository Root)
├── backend/
│   ├── src/
│   │   ├── server.js              # Central entry point (ports 2083, 2087, 2082, 2086, 2095, 2096)
│   │   ├── cli.js                 # Internal CLI runner
│   │   ├── lib/                   # Core shared libraries (db, store, sslContext, platform, validate)
│   │   ├── middleware/            # Auth & License validation middleware
│   │   ├── routes/                # 15+ Express API route modules (/api/*)
│   │   ├── services/              # Business logic & system drivers (website, security, database, etc.)
│   │   └── templates/skel/        # Account skeleton (index, 404, 403, 500 error pages)
├── frontend/                      # uPanel Client End-User React SPA (:2083)
│   ├── src/views/                 # Dashboard, Websites, Files, Databases, Security, Dns, Email, etc.
│   └── src/lib/api.ts             # Central Axios API client & type definitions
├── whm-frontend/                  # UHM Reseller & Server Admin React SPA (:2087)
├── license-server/                # Central Licensing & Update Authority Daemon (:9000)
├── installer/
│   └── upanel                     # Primary server CLI management utility (/usr/local/bin/upanel)
└── install.sh                     # Non-interactive Ubuntu deployment & provisioning script
```
* **Production Deployment Path**: `/opt/facezila/` on Ubuntu Linux.
* **Service Management**: Controlled via systemd (`facezila.service`, `yourpanel-license.service`).

---

### Point 2: Frontend & Backend Frameworks
* **Frontend Architecture**:
  * React 18 with TypeScript.
  * Bundler: **Vite 8** with Rolldown/ESBuild production compiler.
  * Styling: Tailwind CSS 3.4 with custom Apple/cPanel visual themes and responsive design.
  * Icons: `lucide-react`.
  * Networking: `axios` with global auth bearer interceptors and 401 token refresh handling.
* **Backend Architecture**:
  * Node.js runtime (v18 - v24 LTS).
  * Web Framework: **Express 4.19+**.
  * Real-Time: `ws` (WebSockets) for terminal emulation and interactive shell sessions.
  * Networking: `ssh2`, `basic-ftp`, `https` (SNI dynamic context switching).
  * Cryptography: Native Node.js `crypto` (AES-256-GCM, HMAC-SHA256), `bcryptjs` (salt rounds = 12).

---

### Point 3: Database Engine & Data Storage Schemas
1. **Panel Configuration & State Store**:
   * Storage: Atomic JSON file store located at `/var/lib/facezila/` (managed by `backend/src/lib/store.js`).
   * Read-modify-write pattern with atomic temporary file swapping (`.tmp -> .json`) and restricted file modes (`0700` dir, `0600` files).
   * Key state stores:
     * `accounts.json`: Hosting accounts, packages, quotas, credentials.
     * `sites.json`: Domain metadata, PHP versions, document roots, SSL mappings.
     * `security.json`: UFW metadata, blocked IPs, custom rule descriptions.
     * `waf_config.json`: WAF policies, per-site enable/disable toggles, rule configurations.
     * `wplock_settings.json`: Per-site WordPress lock states.
     * `payment_shield_config.json`: Checkout rate limiting rules and blocked carding IPs.
2. **Customer Relational Database Engine**:
   * **MySQL 8.0 / MariaDB 10.x**: Primary relational database server running on `127.0.0.1:3306`.
   * Management: Programmatic user, database, and privilege provisioning via `database.service.js`.
   * Web Console: **phpMyAdmin 5.2.2** with single sign-on (SSO) authentication.
3. **Optional / Secondary Databases**:
   * **PostgreSQL 14+**: Available with `phpPgAdmin` integration.
   * **SQLite3**: `/www/server/panel/data/default.db` (used for legacy host stack interoperability).

---

### Point 4: Server Operating System & Environment
* **Target OS**: Ubuntu 22.04 LTS (Jammy) and Ubuntu 24.04 LTS (Noble).
* **Init System**: `systemd` (handles service auto-restart, dependencies, and process lifecycle).
* **Package Management**: `apt-get` with dpkg lock mitigation and auto-retry scripts.

---

### Point 5: Web Server Configuration & Architecture
* **Web Server**: **Nginx** (acting as primary HTTP/HTTPS reverse proxy and fast static/PHP router).
* **Vhost Layout** (`platform.js`):
  * Active Production Layout: `/www/server/panel/vhost/nginx/{domain}.conf`.
  * Logs: Access log at `/www/wwwlogs/{domain}.log`, error log at `/www/wwwlogs/{domain}.error.log`.
  * Document Root: `/www/wwwroot/{domain}` (or `/www/wwwroot/{domain}/public_html` for custom skeletons).
* **Multi-Engine Support**: `whm.service.js` supports switching or pairing with Apache 2.4 (`mpm_event`) and OpenLiteSpeed (QUIC / HTTP/3).

---

### Point 6: PHP-FPM & Website Provisioning
* **PHP Selector Engine**: Multi-PHP pools from PHP 7.2 to PHP 8.5.
* **Socket Paths**: FastCGI UNIX sockets located at `/tmp/php-cgi-{version}.sock` (e.g., `/tmp/php-cgi-82.sock`).
* **Vhost Inclusion**: Nginx integrates PHP via `include enable-php-{version}.conf;` directives.
* **Per-Domain Settings**: `website.service.js` allows configuring custom FastCGI cache, memory limits, and timeouts per virtual host.

---

### Point 7: Hosting Account & Website Creation Lifecycle
When an account/website is provisioned via `accounts.service.js` or `website.service.js`:
1. Validates domain uniqueness and checks against existing virtual hosts.
2. Generates an isolated Linux username (e.g. `web_domain`).
3. Allocates document root directory `/www/wwwroot/{domain}`.
4. Deploys default website skeleton and branded error pages (`404.html`, `403.html`, `500.html`).
5. Generates Nginx configuration with built-in security rules (sensitive file blocks, regex SQLi/XSS filters, WP-Lock).
6. Issues or binds SSL certificates via Let's Encrypt / local certbot.
7. Registers DNS zone in `dns.service.js`.
8. Enforces quotas on disk space, database count, email accounts, and FTP accounts.

---

### Point 8: File Permissions & Ownership
* Default Web Worker: `www:www` (UID/GID 1000/1000) or `www-data:www-data`.
* Website Directory Permissions: `0755` for directories, `0644` for files.
* Immutable / Read-Only Hardening:
  * `wp-config.php`: Hardened to `0440` via WP-Lock when enabled.
  * System stores: `/var/lib/facezila/` locked to `0700` (root/daemon only).
  * Panel SSL keys: `/etc/facezila/ssl/` locked to `0600`.

---

### Point 9: Existing Firewall & Security Integrations
* **UFW Firewall**: Integrated in `security.service.js`. Dynamically opens/closes TCP/UDP ports, parses numbered rules, and enforces protected ports (SSH 22, Panel 2083/2087/5000 cannot be accidentally closed).
* **Fail2ban**: Actively monitors jails, extracts banned IPs, and provides unban capabilities.
* **Nginx Regex Filter**: Existing vhost includes basic regex protection against SQL injection (`union select`, `benchmark`, `sleep`) and XSS.
* **WP-Lock**: Enforces `.htaccess` and permission locks on WordPress uploads, `xmlrpc.php`, and author scanning.
* **Payment Shield**: Monitors carding bot traffic and applies 429 rate limits on checkout endpoints.
* **2FA**: Native RFC 6238 TOTP engine built into `security.service.js`.

---

### Point 10: Authentication, Roles & Multi-Tenancy
* **Auth Driver**: `backend/src/services/auth.service.js` and `backend/src/middleware/auth.js`.
* **Token Structure**: Signed JWT containing `{ id, username, domain, ip, role, services }`.
* **Tenant Isolation**:
  * `isUserAllowedSite(domain, siteMeta, user)` enforces strict website-level authorization.
  * Non-admin users are strictly blocked from accessing other tenants' virtual hosts, directories, databases, or logs.

---

### Point 11: Cron Jobs & Background Tasks
* **Cron Service**: `cron.service.js` manages `/var/spool/cron/crontabs/{user}`.
* **In-Process Tasks**: `server.js` maintains background intervals for performance telemetry, license synchronization, and temporary file cleanup.
* **Process Execution**: `shell.service.js` wraps `child_process.exec` and `spawn` with execution timeouts and safety escaping.

---

### Point 12: Logging & Monitoring Infrastructure
* **Web Server Logs**: `/www/wwwlogs/{domain}.log` (access) and `/www/wwwlogs/{domain}.error.log` (errors).
* **System Logs**: `/var/log/auth.log`, `/var/log/fail2ban.log`, `/var/log/nginx/`.
* **Panel Activity**: Audit records stored in `/var/lib/facezila/audit.json` and `waf_attack_logs.json`.
* **Alert Channels**: Toast notifications in React UI, email notification hooks via `email.service.js`.

---

## 3. Existing Security Gaps & Opportunities

| Security Area | Current State in uPanel | Required Module State |
|---|---|---|
| **WAF Engine** | Basic Nginx query-string regex filters | Full ModSecurity v3 + OWASP Core Rule Set (CRS) integration with detection/blocking modes |
| **Malware Detection** | Basic keyword scan (`eval`, `base64`) | ClamAV engine + YARA rule compilation + PHP heuristics + AI correlation |
| **File Integrity (FIM)** | Static WP-Lock checksums | Real-time `inotify` file watcher + SHA-256 baseline database |
| **Quarantine System** | Basic file rename (`.quarantine`) | Isolated `/var/quarantine/upanel/` directory, immutable metadata, atomic move, forensic archive, safe restore |
| **AI Threat Engine** | None | Multi-source log correlation, threat classification (INFO -> CRITICAL), prompt-injection hardened |
| **Multi-Tenant Isolation** | Basic file permissions | Dedicated PHP-FPM pool per tenant + Linux group isolation + AppArmor/cgroup resource limits |
| **Bot & Deception** | Payment rate limiter | Global bot classifier + honeytoken / decoy trap endpoints |
| **Security Center UI** | 10 individual tabs in `Security.tsx` | Unified 14-submenu Security Center dashboard consistent with enterprise uPanel UX |

---

## 4. Audit Conclusion & Approval Recommendation

The existing uPanel architecture is stable, well-organized, and ready for the **AI Cyber Security & Threat Protection Module**. All proposed additions can be built as clean service modules without altering or breaking existing website provisioning, DNS, database, or email functions.

Proceed to **Phase 2** (Database Schema & Backend Foundation) following review of `UPANEL_SECURITY_ARCHITECTURE.md` and `UPANEL_SECURITY_IMPLEMENTATION_PLAN.md`.
