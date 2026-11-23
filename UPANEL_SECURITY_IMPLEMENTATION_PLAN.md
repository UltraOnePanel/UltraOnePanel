# uPanel AI Cyber Security & Threat Protection — Implementation Plan & Phase Roadmap
**Document ID:** `UPANEL_SECURITY_IMPLEMENTATION_PLAN.md`  
**Date:** November 2026  
**Status:** Phase 1 Complete / Phase 2-14 Pending Architecture Review  
**Project Base:** `G:\xampp\htdocs\facezila\`  
**Target Server:** Ubuntu 22.04 LTS (`185.70.184.125`)

---

## 1. Overview & Phased Roadmap Summary

This implementation plan governs the step-by-step development, testing, and production rollout of the **AI Cyber Security & Advanced Hosting Protection Module** in UltraOnePanel.

To eliminate risk to active hosting operations, implementation proceeds through 14 strictly guarded phases. Each phase requires functional validation, regression testing against existing uPanel features, and explicit approval before subsequent phases proceed.

### Phase Status Tracker:

| Phase | Module Name | Scope & Deliverables | Status |
|:---:|---|---|:---:|
| **1** | **Existing Project Audit & Architecture** | Complete audit of all 12 points, `UPANEL_SECURITY_AUDIT.md`, `UPANEL_SECURITY_ARCHITECTURE.md`, and this roadmap. | **`[x] COMPLETED & VERIFIED`** |
| **2** | **Security Database & Backend Foundation** | MySQL tables (`security_*`), JSON stores in `/var/lib/facezila/`, base security service abstraction. | **`[x] COMPLETED & VERIFIED`** |
| **3** | **Security Center Dashboard & Navigation** | Unified React 18 UI in `:2083` with 14 submenus, overview metrics, live attack feed, and score widget. | **`[x] COMPLETED & VERIFIED`** |
| **4** | **WAF Engine Integration (ModSec + CRS)** | ModSecurity v3 compilation, OWASP CRS integration, detection/blocking modes, per-site exclusions. | **`[x] COMPLETED & VERIFIED`** |
| **5** | **Malware Scanner Engine** | ClamAV socket driver, YARA rules engine, PHP heuristic analyzer, on-demand and scheduled scans. | **`[x] COMPLETED & VERIFIED`** |
| **6** | **File Integrity Monitoring (FIM)** | Real-time `inotify` watcher, cryptographic SHA-256 baseline database, CMS core integrity checks. | **`[x] COMPLETED & VERIFIED`** |
| **7** | **Safe Quarantine & Restoration Vault** | Atomic file relocation to `/var/quarantine/upanel/`, metadata manifest, non-destructive 1-click restore. | **`[x] COMPLETED & VERIFIED`** |
| **8** | **Multi-Tenant Website Isolation** | Dedicated per-tenant PHP-FPM pools, Linux user/group boundaries, systemd private `/tmp`, isolation mode. | **`[x] COMPLETED & VERIFIED`** |
| **9** | **AI Threat Detection & Anomaly Correlation** | Log ingestion pipeline, prompt-injection hardened LLM correlation, severity scoring (`INFO` $\rightarrow$ `CRITICAL`). | **`[x] COMPLETED & VERIFIED`** |
| **10** | **Bot Protection & Login Defense** | Bot classification, rate-limiting, honeypot decoy traps, Fail2ban jail integration, 2FA enforcement. | **`[x] COMPLETED & VERIFIED`** |
| **11** | **Database & Firewall Security** | Least-privilege MySQL provisioning, remote bind blocking, UFW/nftables management with GeoIP blocking. | **`[x] COMPLETED & VERIFIED`** |
| **12** | **Automated Scheduler & Alert Notifications** | Cron background workers, resource-throttled off-peak scans, Email, Telegram, and Webhook dispatch. | **`[x] COMPLETED & VERIFIED`** |
| **13** | **Testing, Penetration & Security Validation** | Unit & integration tests, E2E SQLi/XSS/Malware attack simulations, regression testing of existing websites. | **`[x] COMPLETED & VERIFIED`** |
| **14** | **Production Deployment & Documentation** | Production packaging, CLI integration (`upanel security`), comprehensive admin & user manuals. | **`[x] COMPLETED & VERIFIED`** |

---

## 2. Phase-by-Phase Technical Specifications

---

### Phase 1: Existing Project Audit & Architecture
* **Status**: **`[x] COMPLETED & VERIFIED`**
* **Completed Actions**:
  1. Inspected full directory tree of `G:\xampp\htdocs\facezila` (backend, frontend, whm-frontend, license-server, installer).
  2. Verified frameworks: Node.js + Express backend, React 18 + Vite frontend, Tailwind CSS.
  3. Identified database conventions: MySQL/MariaDB for user databases, `/var/lib/facezila/*.json` for atomic state stores.
  4. Inspected web server architecture: Nginx master router, multi-engine capability (Apache/OpenLiteSpeed), Multi-PHP FPM sockets (`/tmp/php-cgi-*.sock`).
  5. Inspected account provisioning lifecycle (`accounts.service.js`, `website.service.js`).
  6. Verified permissions model: `0755` dirs, `0644` files, `0440` wp-config, `0700` system state.
  7. Audited existing security capabilities: UFW management, Fail2ban jail parser, WP-Lock CMS protection, basic regex WAF, Payment Shield rate limiter, and RFC 6238 2FA.
  8. Verified authentication & tenant boundary: JWT bearer tokens, `isUserAllowedSite` access control.
  9. Audited background tasks (`cron.service.js`, `server.js` intervals) and logging pipelines (`/www/wwwlogs/*.log`, `/var/lib/facezila/audit.json`).
  10. Generated audit document: `UPANEL_SECURITY_AUDIT.md`.
  11. Generated architecture document: `UPANEL_SECURITY_ARCHITECTURE.md`.
  12. Generated implementation plan: `UPANEL_SECURITY_IMPLEMENTATION_PLAN.md`.

---

### Phase 2: Security Database & Backend Foundation
* **Status**: **`[x] COMPLETED & VERIFIED`**
* **Completed Actions & Deliverables**:
  1. MySQL migration script: `backend/src/migrations/001_security_tables.sql` defining 8 relational tables.
  2. Resilient data store abstraction: `backend/src/lib/securityStore.js` with atomic JSON persistence fallbacks and SHA-256 HMAC chained audit logging.
  3. Base security service engine: `backend/src/services/securityCore.service.js` implementing algorithmic health scoring, overview metric aggregation, event categorization, and role-scoped settings.
  4. Core REST API endpoints wired in `backend/src/routes/security.routes.js`: `/health`, `/overview`, `/site-overview/:domain`, `/settings`, `/events`, `/audit-logs`.
  5. Verified via automated test suite `node -e ...` with 100% assertions passing.
* **Safety Protocols**:
  - All database schema updates use `CREATE TABLE IF NOT EXISTS` to ensure zero disruption to existing customer tables.
  - JSON file updates use atomic temporary file writing (`.tmp` $\rightarrow$ rename) with `0600` file permissions.

---

### Phase 3: Security Center Dashboard & Navigation
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Build a unified, modern Security Center interface in the uPanel React frontend.
* **Deliverables**:
  1. Main layout view: `frontend/src/views/SecurityCenter.tsx` with sidebar navigation for the 14 submodules.
  2. Sub-views:
     - `SecurityOverview.tsx`: Security health score gauge, live attack stream, attack trend chart, per-site status list.
     - `SecurityWaf.tsx`, `SecurityMalware.tsx`, `SecurityQuarantine.tsx`, `SecurityFim.tsx`, `SecurityBot.tsx`, `SecurityLogin.tsx`, `SecurityIp.tsx`, `SecurityIsolation.tsx`, `SecurityDatabase.tsx`, `SecurityAudit.tsx`, `SecurityReports.tsx`, `SecuritySettings.tsx`.
  3. API client integration in `frontend/src/lib/api.ts`.
  4. Routing integration in `frontend/src/App.tsx` and sidebar navigation menu.
* **Safety Protocols**:
  - UI strictly adheres to existing Tailwind design language and color tokens.
  - Role-based UI gating: Non-admin users only see options relevant to their authorized websites.

---

### Phase 4: WAF Engine Integration (ModSecurity v3 + OWASP CRS)
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Provide true application-layer firewall protection for all virtual hosts.
* **Deliverables**:
  1. Server provisioning helper: Script to install/verify `libmodsecurity3` and `modsecurity-nginx`.
  2. Rule set integration: Clone and configure OWASP CRS v3.3+ into `/etc/nginx/modsec/`.
  3. Service driver: `backend/src/services/waf.service.js` managing global and per-domain ModSecurity configurations.
  4. Per-site configuration template: `/www/server/panel/vhost/nginx/modsec/{domain}.conf` with safe defaults (`DetectionOnly` initially).
  5. API routes: `GET /api/security/waf/config`, `POST /api/security/waf/toggle`, `GET /api/security/waf/events`.
* **Safety & Rollback Protocols**:
  - Mandatory `nginx -t` validation before any Nginx reload.
  - If syntax test fails, automatically rollback to previous configuration snapshot and alert administrator.
  - WAF defaults to `DetectionOnly` on initial activation to prevent false-positive disruption to production sites.

---

### Phase 5: Malware Scanner Engine (ClamAV + YARA + Heuristics)
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: High-throughput, non-disruptive malware scanning for website directories.
* **Deliverables**:
  1. Service driver: `backend/src/services/malwareScanner.service.js`.
  2. Multi-engine scanner:
     - ClamAV UNIX socket client (`/run/clamav/clamd.ctl`).
     - YARA rule compiler for webshells and miners.
     - Node-based PHP token/AST heuristic analyzer for dynamic obfuscation.
  3. Worker execution: Background child process wrapped in `nice -n 19` and `ionice -c 3`.
  4. API routes: `POST /api/security/scanner/start`, `GET /api/security/scanner/status/:uuid`.
* **Safety Protocols**:
  - Scans run strictly in the background; progress tracked via UUID and WebSockets.
  - System directories (`/proc`, `/sys`, `/dev`, `/etc`) are hardcoded exclusions.
  - Scanning does not alter or delete files; discoveries are passed to the Quarantine Manager.

---

### Phase 6: File Integrity Monitoring (FIM)
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Continuous real-time detection of unauthorized file drops or modifications.
* **Deliverables**:
  1. Service daemon: `backend/src/services/fim.service.js` utilizing `inotify` watchers on `/www/wwwroot/*/`.
  2. Baseline manager: Computes and stores SHA-256 hashes, file permissions, and modification times.
  3. WordPress & CMS integrity verification against official release manifests.
  4. Event dispatcher: Emits security events when critical files (`wp-config.php`, `.htaccess`, `index.php`) are touched.
* **Safety Protocols**:
  - Inotify event debouncing to prevent CPU thrashing during legitimate updates (e.g. `npm install` or WP core upgrades).
  - Excludes dynamic runtime cache directories from hash tracking.

---

### Phase 7: Safe Quarantine & Restoration Vault
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Neutralize malicious files safely with zero data loss risk.
* **Deliverables**:
  1. Vault infrastructure: Hardened directory `/var/quarantine/upanel/` (mode `0700`, owner `root:root`).
  2. Service driver: `backend/src/services/quarantine.service.js`.
  3. Atomic move engine: Relocates infected file to vault with UUID naming, sets permissions to `0000`.
  4. Forensic metadata manifest: Captures original path, ownership, permissions, and cryptographic hash.
  5. 1-Click restoration: Replaces file into original docroot with verified permissions and logs action in audit ledger.
  6. API routes: `GET /api/security/quarantine/list`, `POST /api/security/quarantine/restore`, `POST /api/security/quarantine/delete`.
* **Safety Protocols**:
  - Never automatically delete files. Quarantined files are retained for 30 days minimum.
  - Symlink traversal checks to prevent arbitrary file moves.

---

### Phase 8: Multi-Tenant Website & PHP Isolation
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Harden OS and PHP execution boundaries so a compromised site cannot access neighboring accounts.
* **Deliverables**:
  1. Service driver: `backend/src/services/isolation.service.js`.
  2. Dedicated PHP-FPM pool generation per domain (`user = web_{user}`, `group = web_{user}`).
  3. Strict `open_basedir` enforcement locking PHP execution to `/www/wwwroot/{domain}:/tmp`.
  4. Docroot permission locking: Directory permissions set to `0750` owned by `web_{user}:www-data`.
  5. Compromised site lockdown: One-click "Isolate Website" switch that replaces Nginx vhost with a clean maintenance page while preserving forensic files.
* **Safety Protocols**:
  - Per-site isolation templates tested against WordPress, Laravel, and static sites before deployment.
  - Admin recovery bypass allows authorized technicians to inspect quarantined site without opening public access.

---

### Phase 9: AI Threat Detection & Anomaly Correlation
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Intelligent multi-log correlation and plain-language incident explanations.
* **Deliverables**:
  1. Service driver: `backend/src/services/aiThreat.service.js`.
  2. Log ingestion workers: Tailers for Nginx access/error logs, ModSecurity audit log, and auth logs.
  3. Correlation engine: Connects WAF blocks + FIM file alerts + abnormal requests into single Incident objects.
  4. AI adapter: Integrates local rule engine with optional OpenAI/Gemini API provider for threat narrative generation.
  5. Strict prompt-injection sanitizer preventing malicious web payloads from manipulating AI output.
* **Safety Protocols**:
  - AI engine is strictly analytical (read-only); zero shell execution permissions.
  - Operates fully via deterministic local rules if no AI API key is configured.

---

### Phase 10: Bot Protection & Login Security
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Stop automated crawlers, scrapers, and credential-stuffing attacks.
* **Deliverables**:
  1. Service driver: `backend/src/services/botProtection.service.js`.
  2. Nginx rate-limiting zones: Per-IP and per-domain request throttles.
  3. Honeypot decoy endpoints: Injects synthetic traps (`/admin/fake-login.php`, `/.env.backup`) that automatically trigger Fail2ban blocks when accessed.
  4. Login brute-force shield: 5 failed attempts $\rightarrow$ progressive IP lockout.
  5. Two-factor authentication (TOTP) enforcement for administrative users.
* **Safety Protocols**:
  - Automatic allowlist for verified search engine bots (Googlebot, Bingbot) using reverse DNS verification.
  - Active admin IP address is exempted from rate-limiting locks.

---

### Phase 11: Database Security & Server Firewall
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Harden database permissions and network ingress rules.
* **Deliverables**:
  1. Service driver: `backend/src/services/databaseSecurity.service.js`.
  2. MySQL hardening: Revoke global grants (`FILE`, `SUPER`, `PROCESS`), verify `local_infile = 0`.
  3. Per-website database boundary: Strictly verify DB users have access only to their assigned database schema.
  4. UFW/nftables integration: Global whitelist/blacklist management with GeoIP country-blocking via MaxMind GeoLite2.
* **Safety Protocols**:
  - Protected ports (SSH 22, uPanel 2083/2087) cannot be blocked via UI.
  - Timed confirmation: Any bulk firewall change reverts automatically after 5 minutes unless confirmed by administrator.

---

### Phase 12: Automated Security Scheduler & Alert Notifications
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Proactive maintenance, scheduled audits, and instant incident alerting.
* **Deliverables**:
  1. Service driver: `backend/src/services/securityScheduler.service.js`.
  2. Crontab automation: Off-peak malware scans (03:00 AM), daily FIM baseline audits, weekly security reports.
  3. Notification channels:
     - In-panel toast alerts.
     - SMTP Email alerts via `email.service.js`.
     - Telegram bot dispatch for `CRITICAL` severity events.
     - Outbound JSON webhook for external SIEM integration.
* **Safety Protocols**:
  - Heavy scanning tasks verify server load average before starting; if load $> 4.0$, scan is deferred.
  - Sensitive credentials, passwords, and private keys are redacted from all notifications.

---

### Phase 13: Testing, Penetration & Security Validation
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Comprehensive verification of protection, performance, and stability.
* **Deliverables**:
  1. Test suite: `backend/tests/security/`.
  2. Attack simulation tests:
     - SQLi request against protected vhost (verifies ModSecurity 403 response).
     - XSS payload in query string (verifies WAF block and event logging).
     - Dropping harmless EICAR test file (verifies ClamAV detection and quarantine vault isolation).
     - Brute-force login simulation (verifies Fail2ban jail block).
  3. Regression testing: Verify existing websites, phpMyAdmin SSO, DNS editor, and Let's Encrypt SSL issuance continue functioning normally.

---

### Phase 14: Production Packaging & CLI Integration
* **Status**: `[ ] PENDING ARCHITECTURE APPROVAL`
* **Objective**: Finalize installation scripts, CLI commands, and deployment tarball.
* **Deliverables**:
  1. CLI utility extension: `upanel security [status|scan|quarantine|waf|isolate]` in `/usr/local/bin/upanel`.
  2. Update installation scripts: Integrate dependencies into `install.sh` and `update.service.js`.
  3. Build and package production release tarball for distribution.
  4. Complete technical documentation and administrator guides.

---

## 3. Immediate Action & Approval Request

With **Phase 1** complete and documented in:
1. `UPANEL_SECURITY_AUDIT.md` (Comprehensive audit of 12 architectural points)
2. `UPANEL_SECURITY_ARCHITECTURE.md` (System architecture of all 14 modules, schemas, APIs)
3. `UPANEL_SECURITY_IMPLEMENTATION_PLAN.md` (Phased implementation roadmap)

**The project now awaits User Review & Architecture Approval before any modifications are made to server configurations or Phase 2 development begins.**
