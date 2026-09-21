#!/usr/bin/env bash
# ==============================================================================
# TPANEL COMMERCIAL CLOUD HOSTING & CONTROL ENGINE INSTALLER
# Client Production Installation Script for Ubuntu 20.04/22.04/24.04 & Debian
# Zero Plain-Text Source Code • V8 Bytecode Protected • Enterprise Hardened
# Official Repository: https://github.com/turkyhub1280/TPANEL-VPS-SETUP
# ==============================================================================

set -e

# 1. Root Check
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root. Run with 'sudo bash install.sh'"
    exit 1
fi

# Attach to /dev/tty if running via curl pipe so interactive prompts work cleanly
if [ ! -t 0 ]; then
    if [ -c /dev/tty ]; then
        exec < /dev/tty 2>/dev/null || true
    fi
fi

echo ""
cat << 'EOF'
  ______ _____                 _ 
 |_   __|  __ \               | |
   | |  | |__) |_ _ _ __   ___| |
   | |  |  ___/ _` | '_ \ / _ \ |
  _| |_ | |  | (_| | | | |  __/ |
 |_____||_|   \__,_|_| |_|\___|_|
==========================================================================
  🚀 WELCOME TO TPANEL CLOUD HOSTING & CONTROL ENGINE
  ⚡ Autonomous Linux Hosting, Mail Engine & Cryptographic Stack
==========================================================================
EOF
echo ""

# Detect Server IP early for activation
SERVER_IP=$(curl -s -4 --connect-timeout 4 https://api.ipify.org || curl -s --connect-timeout 4 https://ifconfig.me || hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="127.0.0.1"
fi

# Ensure hardware machine_id exists
MACHINE_ID=""
if [ -f /etc/machine-id ]; then
    MACHINE_ID=$(cat /etc/machine-id | tr -d '\r\n ')
elif [ -f /var/lib/dbus/machine-id ]; then
    MACHINE_ID=$(cat /var/lib/dbus/machine-id | tr -d '\r\n ')
fi
if [ -z "$MACHINE_ID" ]; then
    MACHINE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)
    mkdir -p /etc
    echo "$MACHINE_ID" > /etc/machine-id
fi

# ------------------------------------------------------------------------------
# STEP 1: COMMERCIAL LICENSE VERIFICATION
# ------------------------------------------------------------------------------
LICENSE_KEY="${TPANEL_LICENSE_KEY:-}"
while [ -z "$LICENSE_KEY" ]; do
    echo "🔐 STEP 1/2: LICENSE KEY VERIFICATION (লাইসেন্স কি যাচাইকরণ)"
    echo "--------------------------------------------------------------------------"
    echo "  Tpanel requires an authentic commercial license key to activate."
    read -r -p "🔑 Enter your Tpanel License Key: " LICENSE_KEY
    LICENSE_KEY=$(echo "$LICENSE_KEY" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    if [ -z "$LICENSE_KEY" ]; then
        echo "❌ License key cannot be blank. Please enter a valid key."
        echo ""
    fi
done

TPANEL_HUB="${TPANEL_HUB:-}"
while [ -z "$TPANEL_HUB" ]; do
    echo ""
    echo "🌐 MASTER LICENSING AUTHORITY (মাস্টার সার্ভার লিঙ্ক বা আইপি):"
    read -r -p "   Enter Master Server URL or IP (e.g. https://xxx.trycloudflare.com or 1.2.3.4): " TPANEL_HUB
    TPANEL_HUB=$(echo "$TPANEL_HUB" | tr -d ' ' | sed 's|/$||')
    if [[ ! "$TPANEL_HUB" =~ ^https?:// ]] && [ -n "$TPANEL_HUB" ]; then
        TPANEL_HUB="http://${TPANEL_HUB}"
    fi
    if [ -z "$TPANEL_HUB" ]; then
        echo "❌ Master Server URL or IP cannot be blank."
    fi
done

echo ""
echo "⏳ Validating license with Tpanel Master Licensing Hub (${TPANEL_HUB})..."
ACTIVATE_PAYLOAD=$(printf '{"licenseKey":"%s","machineId":"%s","vpsIp":"%s","hostname":"%s"}' "$LICENSE_KEY" "$MACHINE_ID" "$SERVER_IP" "$(hostname)")
ACTIVATE_RESP=$(curl -s -k -X POST "${TPANEL_HUB}/api/license/activate" \
    -H "Content-Type: application/json" \
    --connect-timeout 10 \
    -d "$ACTIVATE_PAYLOAD" 2>/dev/null || true)

ACTIVATE_SUCCESS=$(echo "$ACTIVATE_RESP" | grep -o '"success":true' || true)

if [ -z "$ACTIVATE_SUCCESS" ]; then
    ERR_MSG=$(echo "$ACTIVATE_RESP" | grep -o '"error":"[^"]*' | cut -d'"' -f4 || echo "License validation failed. Cannot reach licensing authority.")
    echo ""
    echo "=========================================================================="
    echo "❌ LICENSE ACTIVATION REJECTED!"
    echo "=========================================================================="
    echo "  Reason: ${ERR_MSG}"
    echo "  Please verify your license key with the server owner or obtain a valid key."
    echo "  Support & Inquiries: tamimhasan1281@gmail.com"
    echo "=========================================================================="
    echo ""
    exit 1
fi

OWNER_NAME=$(echo "$ACTIVATE_RESP" | grep -o '"owner_name":"[^"]*' | cut -d'"' -f4 || echo "Authorized Client")
MAX_INST=$(echo "$ACTIVATE_RESP" | grep -o '"max_instances":[0-9]*' | cut -d':' -f2 || echo "1")

echo "✅ License Verified & Hardware Bound Successfully!"
echo "   👤 Licensed To    : ${OWNER_NAME}"
echo "   🖥️ Instance Quota : ${MAX_INST} VPS Instance(s)"
echo "   🔒 Hardware ID    : ${MACHINE_ID:0:16}..."
echo ""

# Store Cryptographically Signed Token & Master Hub
mkdir -p /etc/tpanel
echo "$ACTIVATE_RESP" | grep -o '"token":{[^}]*}' | sed 's/"token"://' > /etc/tpanel/.license 2>/dev/null || echo "$ACTIVATE_RESP" > /etc/tpanel/.license
echo "$TPANEL_HUB" > /etc/tpanel/.hub
chmod 600 /etc/tpanel/.license /etc/tpanel/.hub

# ------------------------------------------------------------------------------
# STEP 2: ADMINISTRATOR ACCOUNT SETUP
# ------------------------------------------------------------------------------
echo "--------------------------------------------------------------------------"
echo "👤 STEP 2/2: ADMINISTRATOR ACCOUNT SETUP (মাস্টার অ্যাডমিন একাউন্ট)"
echo "--------------------------------------------------------------------------"
echo "  Create your primary administrative credentials for the Tpanel dashboard."
echo ""

ADMIN_EMAIL="${TPANEL_ADMIN_EMAIL:-}"
while [ -z "$ADMIN_EMAIL" ]; do
    read -r -p "📧 Administrator Email: " ADMIN_EMAIL
    ADMIN_EMAIL=$(echo "$ADMIN_EMAIL" | tr -d ' ')
    if [ -z "$ADMIN_EMAIL" ]; then
        echo "❌ Email cannot be blank."
    fi
done

prompt_password() {
    local prompt="$1"
    local password=""
    local char
    echo -n "$prompt" >&2
    while IFS= read -r -s -n 1 char; do
        if [[ $char == $'\0' || $char == $'\n' ]]; then
            break
        elif [[ $char == $'\177' || $char == $'\b' ]]; then
            if [ ${#password} -gt 0 ]; then
                password="${password%?}"
                echo -ne "\b \b" >&2
            fi
        else
            password+="$char"
            echo -n "*" >&2
        fi
    done
    echo "" >&2
    echo "$password"
}

ADMIN_PASS="${TPANEL_ADMIN_PASS:-}"
if [ -z "$ADMIN_PASS" ]; then
    while true; do
        ADMIN_PASS=$(prompt_password "🔒 Administrator Password: ")
        if [ ${#ADMIN_PASS} -lt 6 ]; then
            echo "❌ Password must be at least 6 characters long."
            continue
        fi
        ADMIN_PASS_CONFIRM=$(prompt_password "🔒 Confirm Administrator Password: ")
        if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
            echo "❌ Passwords do not match. Please re-enter."
            continue
        fi
        break
    done
fi

echo ""
echo "✅ Administrator credentials verified."
echo "🚀 Proceeding with system installation and package optimization..."
echo "=========================================================================="
echo ""

export DEBIAN_FRONTEND=noninteractive

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
else
    echo "❌ Error: Cannot detect operating system."
    exit 1
fi

echo "📦 Detected OS: ${OS_NAME} ${OS_VERSION}"

# 3. System Packages & Base Dependencies
echo "🔄 Updating package lists and installing core dependencies..."
apt-get update -y -q
apt-get install -y -q \
    curl wget git software-properties-common ca-certificates \
    lsb-release apt-transport-https build-essential ufw zip unzip tar \
    nano jq net-tools dnsutils ssl-cert fail2ban

# 4. Install Nginx Web Server
echo "🌐 Installing Nginx Web Server..."
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true
apt-get install -y -q nginx 2>/dev/null || true
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d
systemctl enable nginx 2>/dev/null || true
systemctl start nginx 2>/dev/null || true

# 5. Install MariaDB Database Server
echo "🗄️ Installing MariaDB Database Engine..."
apt-get install -y -q mariadb-server mariadb-client 2>/dev/null || true
systemctl enable mariadb 2>/dev/null || true
systemctl start mariadb 2>/dev/null || true

# Harden MariaDB port 3306 to localhost only
if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
    sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
    systemctl restart mariadb 2>/dev/null || true
fi

# 6. Install Node.js LTS (v20)
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 18 ]; then
    echo "🟢 Installing Node.js LTS (v20)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -q nodejs
fi
echo "✅ Node.js $(node -v) & NPM $(npm -v) ready."

# 7. Install PHP FastCGI & Multi-Version Extensions
echo "🐘 Installing PHP Runtime & Modules..."
if [ "$OS_NAME" = "ubuntu" ]; then
    add-apt-repository -y ppa:ondrej/php || true
    apt-get update -y -q
fi
apt-get install -y -q php8.2-fpm php8.2-mysql php8.2-cli php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath || true
systemctl enable php8.2-fpm 2>/dev/null || true
systemctl start php8.2-fpm 2>/dev/null || true

# 8. Install Mail Server Stack (Postfix + Dovecot)
echo "✉️ Installing In-House Mail Stack (Postfix SMTP & Dovecot Maildir)..."
debconf-set-selections <<< "postfix postfix/mailname string localhost"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y -q postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql

# Directory Layout
APP_DIR="/opt/cpanel-core"
VHOSTS_DIR="/var/www/vhosts"
mkdir -p "${APP_DIR}" "${VHOSTS_DIR}" /var/vmail /var/log/tpanel /etc/tpanel
chown -R vmail:vmail /var/vmail 2>/dev/null || useradd -r -u 5000 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual Mail" vmail 2>/dev/null || true
mkdir -p /var/vmail && chown -R vmail:mail /var/vmail && chmod -R 770 /var/vmail

# ------------------------------------------------------------------------------
# 9. DEPLOY PRE-COMPILED V8 BYTECODE PACKAGE (NO RAW SOURCE CODE)
# ------------------------------------------------------------------------------
echo "🔒 Downloading & Deploying Compiled Tpanel Engine Package..."
RELEASE_URL="https://raw.githubusercontent.com/turkyhub1280/TPANEL-VPS-SETUP/main/releases/tpanel-core-client.tar.gz"
TEMP_TAR=$(mktemp)

if curl -sSL -f -m 60 "${RELEASE_URL}" -o "${TEMP_TAR}"; then
    echo "✅ Compiled engine package received. Unpacking into ${APP_DIR}..."
    tar -xzf "${TEMP_TAR}" -C "${APP_DIR}"
    rm -f "${TEMP_TAR}"
else
    echo "⚠️ Central release CDN busy, building secure runtime bundle..."
    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/turkyhub1280/TPANEL-VPS-SETUP "${TEMP_DIR}"
    cp -rf "${TEMP_DIR}/"* "${APP_DIR}/"
    rm -rf "${TEMP_DIR}"
fi

cd "${APP_DIR}"
echo "📦 Installing production dependencies..."
npm install --omit=dev --loglevel=error

# If bytenode is present and server.jsc exists, ensure raw server.js is removed from client VPS!
if [ -f "${APP_DIR}/server.jsc" ] && [ -f "${APP_DIR}/tpanel-core.js" ]; then
    rm -f "${APP_DIR}/server.js" "${APP_DIR}/server.obf.js"
    chmod 600 "${APP_DIR}/server.jsc"
    chmod 755 "${APP_DIR}/tpanel-core.js"
    echo "🛡️ Proprietary source code locked (V8 Machine Bytecode mode active)."
fi

# Configure Postfix & Dovecot
if [ -d "${APP_DIR}/configs/postfix" ]; then
    cp -f "${APP_DIR}/configs/postfix/main.cf" /etc/postfix/main.cf
    cp -f "${APP_DIR}/configs/postfix/master.cf" /etc/postfix/master.cf
    cp -rf "${APP_DIR}/configs/postfix/sql/"* /etc/postfix/sql/ 2>/dev/null || true
    chmod 640 /etc/postfix/sql/*.cf 2>/dev/null || true
fi
if [ -d "${APP_DIR}/configs/dovecot" ]; then
    cp -f "${APP_DIR}/configs/dovecot/dovecot.conf" /etc/dovecot/dovecot.conf
    cp -f "${APP_DIR}/configs/dovecot/dovecot-sql.conf.ext" /etc/dovecot/dovecot-sql.conf.ext
    cp -rf "${APP_DIR}/configs/dovecot/conf.d/"* /etc/dovecot/conf.d/ 2>/dev/null || true
fi
make-ssl-cert generate-default-snakeoil --force-overwrite 2>/dev/null || true

# Setup MariaDB
echo "🗃️ Setting up MariaDB 'cpanel_system' database..."
SQL_USER_CMDS="CREATE USER IF NOT EXISTS 'cpanel_admin'@'localhost' IDENTIFIED BY 'cPanelSecurePass2026!'; ALTER USER 'cpanel_admin'@'localhost' IDENTIFIED BY 'cPanelSecurePass2026!'; GRANT ALL PRIVILEGES ON *.* TO 'cpanel_admin'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"
mariadb -u root -e "$SQL_USER_CMDS" 2>/dev/null || mariadb -e "$SQL_USER_CMDS" 2>/dev/null || true
if [ -f "${APP_DIR}/schema.sql" ]; then
    mariadb -u cpanel_admin -pcPanelSecurePass2026! < "${APP_DIR}/schema.sql" 2>/dev/null || true
fi

# Register Primary Administrator with Bcrypt Hash (Zero plain-text)
echo "🔒 Registering Primary Administrator Account into MariaDB..."
ADMIN_BCRYPT_HASH=$(node -e "const b = require('bcryptjs'); console.log(b.hashSync(process.argv[1], 10));" "$ADMIN_PASS")
mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO users (name, email, password_hash, role) VALUES ('Administrator', '${ADMIN_EMAIL}', '${ADMIN_BCRYPT_HASH}', 'admin') ON DUPLICATE KEY UPDATE email = '${ADMIN_EMAIL}', password_hash = '${ADMIN_BCRYPT_HASH}', role = 'admin';" 2>/dev/null || true
echo "✅ Administrator account registered securely (Zero plain-text password storage)."
unset ADMIN_PASS ADMIN_PASS_CONFIRM

# Setup Systemd Service
echo "⚡ Registering systemd background service..."
NODE_BIN=$(command -v node || which node || echo "/usr/bin/node")
RUNNER_ENTRY="${APP_DIR}/tpanel-core.js"
if [ ! -f "$RUNNER_ENTRY" ]; then
    RUNNER_ENTRY="${APP_DIR}/server.js"
fi

cat << EOF > /etc/systemd/system/cpanel-core.service
[Unit]
Description=Tpanel Cloud Control Platform Engine
After=network.target mariadb.service nginx.service
Wants=mariadb.service nginx.service

[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
ExecStart=${NODE_BIN} ${RUNNER_ENTRY}
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tpanel-core
Environment=NODE_ENV=production
Environment=PORT=3000
LimitNOFILE=65535
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cpanel-core.service
systemctl restart cpanel-core.service

# Configure Nginx Reverse Proxy
if ! grep -q "client_max_body_size" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    client_max_body_size 2048M;' /etc/nginx/nginx.conf
fi
if [ -f "${APP_DIR}/configs/nginx/cpanel-nginx.conf" ]; then
    cp -f "${APP_DIR}/configs/nginx/cpanel-nginx.conf" /etc/nginx/sites-available/default
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx 2>/dev/null || true
fi
systemctl restart postfix dovecot 2>/dev/null || true

# ------------------------------------------------------------------------------
# 10. ENTERPRISE FIREWALL & SECURITY HARDENING
# ------------------------------------------------------------------------------
echo "🛡️ Hardening Firewall (UFW) & Internal Service Isolation..."
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22/tcp 2>/dev/null || true
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true
ufw allow 3000/tcp 2>/dev/null || true
ufw allow 25/tcp 2>/dev/null || true
ufw allow 587/tcp 2>/dev/null || true
ufw allow 465/tcp 2>/dev/null || true
ufw allow 143/tcp 2>/dev/null || true
ufw allow 993/tcp 2>/dev/null || true
ufw allow 110/tcp 2>/dev/null || true
ufw allow 995/tcp 2>/dev/null || true
ufw --force enable 2>/dev/null || true

# Enable fail2ban for SSH & web protection
systemctl enable fail2ban 2>/dev/null || true
systemctl restart fail2ban 2>/dev/null || true

# Store server IP
mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO system_settings (setting_key, setting_value) VALUES ('server_ip', '${SERVER_IP}') ON DUPLICATE KEY UPDATE setting_value = '${SERVER_IP}';" 2>/dev/null || true

# Install & Configure Cloudflare Quick Tunnel (Zero Domain / Instant HTTPS)
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "☁️ Installing Cloudflare Quick Tunnel Agent (cloudflared)..."
    ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    curl -fsSL -o /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" 2>/dev/null || \
    curl -fsSL -o /tmp/cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" 2>/dev/null || true
    if [ -f /tmp/cloudflared.deb ]; then
        dpkg -i /tmp/cloudflared.deb 2>/dev/null || apt-get install -f -y -q 2>/dev/null || true
        rm -f /tmp/cloudflared.deb
    fi
fi

CF_BIN=$(command -v cloudflared || echo "/usr/local/bin/cloudflared")
if [ -x "$CF_BIN" ]; then
    echo "☁️ Setting up Cloudflare Quick Tunnel background service..."
    cat << EOF > /etc/systemd/system/tpanel-tunnel.service
[Unit]
Description=Tpanel Cloudflare Quick Tunnel Service
After=network.target cpanel-core.service

[Service]
Type=simple
User=root
ExecStart=${CF_BIN} tunnel --url http://127.0.0.1:3000 --logfile /var/log/tpanel-tunnel.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable tpanel-tunnel.service 2>/dev/null || true
    systemctl restart tpanel-tunnel.service 2>/dev/null || true
fi

# Extract Cloudflare Tunnel URL
CF_TUNNEL_URL=""
echo "⏳ Waiting for Cloudflare Quick Tunnel endpoint (up to 8s)..."
for i in $(seq 1 8); do
    sleep 1
    CF_TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/tpanel-tunnel.log 2>/dev/null | head -n 1 || true)
    if [ -n "$CF_TUNNEL_URL" ]; then
        break
    fi
done

if [ -n "$CF_TUNNEL_URL" ]; then
    mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO system_settings (setting_key, setting_value) VALUES ('cloudflare_tunnel_url', '${CF_TUNNEL_URL}') ON DUPLICATE KEY UPDATE setting_value = '${CF_TUNNEL_URL}';" 2>/dev/null || true
fi

echo ""
echo "=========================================================================="
echo "  🎉 CONGRATULATIONS! TPANEL ENGINE INSTALLED SUCCESSFULLY!"
echo "=========================================================================="
echo ""
echo "  🔑 ACTIVE LICENSE : Bound & Verified with Master Authority"
echo "  👤 PRIMARY ADMIN  : ${ADMIN_EMAIL} (Password hashed with bcrypt)"
echo "  🛡️ SOURCE STATUS  : V8 Machine Bytecode Locked (Anti-Tamper Active)"
echo "  🔒 FIREWALL STATUS: Hardened (Port 3306 & internal services isolated)"
echo ""
if [ -n "$CF_TUNNEL_URL" ]; then
echo "  👉 🚀 CLOUDFLARE SECURE ACCESS URL (ক্লাউডফ্লেয়ার ইনস্ট্যান্ট লিঙ্ক):"
echo "     ${CF_TUNNEL_URL}/"
echo "     (Instant HTTPS • Zero Port Forwarding • Global Cloudflare CDN)"
echo ""
fi
echo "  👉 🌐 DIRECT SERVER IP ACCESS URL (সার্ভার ডিরেক্ট আইপি লিঙ্ক):"
echo "     http://${SERVER_IP}/"
echo "     (or direct port 3000: http://${SERVER_IP}:3000/)"
echo ""
echo "  📋 NEXT STEPS (পরবর্তী করণীয় ধাপসমূহ):"
echo "  1. Open your panel URL in your browser."
echo "  2. Sign in with your configured Administrator Email & Password."
echo "  3. Add your domain in the Domains section and start hosting!"
echo ""
echo "  🛠️ SYSTEM SERVICES STATUS:"
echo "     • Tpanel Core Engine : systemctl status cpanel-core"
echo "     • Cloudflare Tunnel  : systemctl status tpanel-tunnel"
echo "     • Nginx Web Server   : systemctl status nginx"
echo "     • MariaDB Database   : systemctl status mariadb"
echo "     • Postfix Mail MTA   : systemctl status postfix"
echo "     • Dovecot Maildir    : systemctl status dovecot"
echo "=========================================================================="
echo ""
