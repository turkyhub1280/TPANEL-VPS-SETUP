# Tpanel ⚡ Autonomous Cloud Web Hosting Platform

> **Lightweight, High-Performance Control Panel for Ubuntu & Debian Cloud VPS.**
> Features Built-in Nginx, In-House Mail Engine (Postfix/Dovecot), Multi-PHP, DNS, SSL & Instant Cloudflare Quick Tunnel.

---

## 🚀 1-Click Automated Installation

Run the following command on a clean **Ubuntu (20.04/22.04/24.04)** or **Debian** VPS as root:

```bash
curl -sSL https://raw.githubusercontent.com/turkyhub1280/TPANEL-VPS-SETUP/main/install.sh | bash
```

---

## 📋 Installation Workflow

1. **License Verification:**
   Enter the commercial license key provided by your server provider:
   ```text
   🔑 Enter your Tpanel License Key: TPNL-XXXX-XXXX-XXXX-XXXX
   ```
2. **Master Licensing Endpoint:**
   Enter the Master Hub URL or IP when prompted:
   ```text
   🌐 Enter Master Server URL or IP: https://<master-hub>.trycloudflare.com
   ```
3. **Admin Setup:**
   Configure your administrator email and strong password.
4. **Instant HTTPS Access:**
   Once installed, your terminal will display your dedicated **Cloudflare Quick Tunnel HTTPS URL** and direct IP access URL.

---

## 🛡️ Enterprise Security

- **V8 Native Machine Bytecode:** All server logic runs as compiled binary machine bytecode (`server.jsc`).
- **Cryptographic License Lock:** Verified with Ed25519 signatures and hardware machine ID binding.
- **Isolated Database:** Internal MariaDB (Port 3306) restricted strictly to `127.0.0.1`.
- **Automated UFW Firewall:** Only web, SSH, and mail ports are open; all other attack vectors are blocked.
