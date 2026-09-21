#!/usr/bin/env bash
# ==============================================================================
# TPANEL MASTER OWNER CLUSTER INSTALLER (অফিসিয়াল মাস্টার অ্যাডমিন ইনস্টলার)
# Exclusively for Master Owner Node Setup (Tamim Hasan / tamimhasan1281@gmail.com)
# Zero License Required • Instant Automated Login • Full Authority Mode
# ==============================================================================

set -e

# 1. Root Check
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root. Run with 'sudo bash master-install.sh'"
    exit 1
fi

# TTY-safe input helpers
read_input() {
    local prompt_text="$1"
    local var_name="$2"
    local val=""
    printf "%s" "$prompt_text" >&2
    if [ ! -t 0 ] && [ -c /dev/tty ]; then
        read -r val < /dev/tty 2>/dev/null || read -r val
    else
        read -r val
    fi
    eval "$var_name=\"\$val\""
}

prompt_password() {
    local prompt="$1"
    local pass=""
    printf "%s" "$prompt" >&2
    if [ ! -t 0 ] && [ -c /dev/tty ]; then
        read -r -s pass < /dev/tty 2>/dev/null || read -r pass < /dev/tty 2>/dev/null || read -r -s pass 2>/dev/null || read -r pass
    else
        read -r -s pass 2>/dev/null || read -r pass
    fi
    echo "" >&2
    echo "$pass"
}

echo ""
cat << 'EOF'
  ______ _____                 _ 
 |_   __|  __ \               | |
   | |  | |__) |_ _ _ __   ___| |
   | |  |  ___/ _` | '_ \ / _ \ |
  _| |_ | |  | (_| | | | |  __/ |
 |_____||_|   \__,_|_| |_|\___|_|
  👑 TPANEL ENTERPRISE — MASTER OWNER CLUSTER DEPLOYMENT
  ⚡ Master Authority Node Setup & Automatic Control Panel Provisioning
  🔒 Authority: tamimhasan1281@gmail.com | Master Licensing Hub
==========================================================================
EOF
echo ""

# ------------------------------------------------------------------------------
# STEP 0: MASTER SECURITY PIN GATE (৬ ডিজিটের গোপন পিন যাচাইকরণ)
# ------------------------------------------------------------------------------
MASTER_EXPECTED_PIN="${TPANEL_MASTER_PIN:-128099}"
PIN_ATTEMPTS=0
PIN_AUTHENTICATED=false

echo "🔒 MASTER SECURITY ACCESS VERIFICATION (মাস্টার সিকিউরিটি গেট)"
echo "--------------------------------------------------------------------------"
echo "  This private deployment is strictly restricted to authorized owners."
echo "  A 6-digit Master Security PIN is required to unlock this installer."
echo ""

while [ "$PIN_ATTEMPTS" -lt 3 ]; do
    ENTERED_PIN=$(prompt_password "🔑 Enter 6-digit Master Security PIN: ")
    ENTERED_PIN=$(echo "$ENTERED_PIN" | tr -d ' \r\n')
    
    if [ "$ENTERED_PIN" = "$MASTER_EXPECTED_PIN" ]; then
        PIN_AUTHENTICATED=true
        echo "✅ Master Authority PIN Verified! Access Granted."
        echo ""
        break
    else
        PIN_ATTEMPTS=$((PIN_ATTEMPTS + 1))
        REMAINING=$((3 - PIN_ATTEMPTS))
        if [ "$REMAINING" -gt 0 ]; then
            echo "❌ Invalid Master PIN! Access Denied (${REMAINING} attempt(s) remaining)."
            echo ""
        fi
    fi
done

if [ "$PIN_AUTHENTICATED" != "true" ]; then
    echo "=========================================================================="
    echo "🚨 ACCESS DENIED: UNAUTHORIZED MASTER NODE DEPLOYMENT TERMINATED!"
    echo "=========================================================================="
    echo "  You have exceeded the maximum allowed PIN attempts."
    echo "  This repository and cluster installer are private property."
    echo "  Contact: tamimhasan1281@gmail.com"
    echo "=========================================================================="
    echo ""
    exit 1
fi

echo "👑 MASTER ADMINISTRATOR CREDENTIALS (অ্যাডমিন একাউন্ট সেটআপ)"
echo "--------------------------------------------------------------------------"
echo "  Configure your Master Control Panel login credentials."
echo "  Login is performed directly using your Email and Password."
echo ""

# Prompt Master Admin Credentials
MASTER_EMAIL="${TPANEL_MASTER_EMAIL:-}"
while [ -z "$MASTER_EMAIL" ]; do
    read_input "👤 Master Administrator Email [tamimhasan1281@gmail.com]: " MASTER_EMAIL
    MASTER_EMAIL=$(echo "$MASTER_EMAIL" | tr -d ' ')
    if [ -z "$MASTER_EMAIL" ]; then
        MASTER_EMAIL="tamimhasan1281@gmail.com"
    fi
done

MASTER_PASS="${TPANEL_MASTER_PASS:-}"
if [ -z "$MASTER_PASS" ]; then
    while true; do
        MASTER_PASS=$(prompt_password "🔒 Master Administrator Password: ")
        if [ ${#MASTER_PASS} -lt 6 ]; then
            echo "❌ Password must be at least 6 characters long."
            continue
        fi
        MASTER_PASS_CONFIRM=$(prompt_password "🔒 Confirm Master Password: ")
        if [ "$MASTER_PASS" != "$MASTER_PASS_CONFIRM" ]; then
            echo "❌ Passwords do not match. Please re-enter."
            continue
        fi
        break
    done
fi

echo ""
echo "✅ Master credentials recorded. Initializing Enterprise Linux Stack..."
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

echo "📦 Detected Operating System: ${OS_NAME} ${OS_VERSION}"

# 1. System Update & Dependencies
echo "🔄 Updating system packages and installing core hosting dependencies..."
apt-get update -y -q
apt-get install -y -q \
    curl wget git software-properties-common ca-certificates \
    lsb-release apt-transport-https build-essential ufw zip unzip tar \
    nano jq net-tools dnsutils ssl-cert fail2ban

# 2. Install Nginx Web Server
echo "🌐 Installing & Tuning Nginx Web Engine..."
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true
apt-get install -y -q nginx 2>/dev/null || true
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d
systemctl enable nginx 2>/dev/null || true
systemctl start nginx 2>/dev/null || true

# 3. Install MariaDB Database Server
echo "🗄️ Installing MariaDB SQL Engine..."
apt-get install -y -q mariadb-server mariadb-client 2>/dev/null || true
systemctl enable mariadb 2>/dev/null || true
systemctl start mariadb 2>/dev/null || true

# Harden MariaDB to localhost only
if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
    sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
    systemctl restart mariadb 2>/dev/null || true
fi

# 4. Install Node.js LTS (v20)
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 18 ]; then
    echo "🟢 Installing Node.js LTS (v20)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -q nodejs
fi
echo "✅ Node.js $(node -v) & NPM $(npm -v) ready."

# 5. Install PHP FastCGI
echo "🐘 Installing PHP Runtime & Modules..."
if [ "$OS_NAME" = "ubuntu" ]; then
    add-apt-repository -y ppa:ondrej/php || true
    apt-get update -y -q
fi
apt-get install -y -q php8.2-fpm php8.2-mysql php8.2-cli php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath || true
systemctl enable php8.2-fpm 2>/dev/null || true
systemctl start php8.2-fpm 2>/dev/null || true

# 6. Install Mail Server Stack (Postfix + Dovecot)
echo "✉️ Installing Mail MTA & Maildir System..."
debconf-set-selections <<< "postfix postfix/mailname string localhost"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y -q postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql

# Directory Layout
APP_DIR="/opt/cpanel-core"
VHOSTS_DIR="/var/www/vhosts"
mkdir -p "${APP_DIR}" "${VHOSTS_DIR}" /var/vmail /var/log/tpanel /etc/tpanel
chown -R vmail:vmail /var/vmail 2>/dev/null || useradd -r -u 5000 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual Mail" vmail 2>/dev/null || true
mkdir -p /var/vmail && chown -R vmail:mail /var/vmail && chmod -R 770 /var/vmail

# Clone Master Repository
echo "📥 Deploying Full Master Repository..."
TEMP_DIR=$(mktemp -d)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -n "$GITHUB_TOKEN" ]; then
    CLONE_URL="https://${GITHUB_TOKEN}@github.com/turkyhub1280/TPANEL-VPS.git"
else
    CLONE_URL="https://github.com/turkyhub1280/TPANEL-VPS.git"
fi

if ! git clone --depth 1 "$CLONE_URL" "${TEMP_DIR}" 2>/dev/null; then
    echo "🔒 Private repository authentication required."
    read_input "🔑 Enter your GitHub Personal Access Token: " GITHUB_TOKEN
    GITHUB_TOKEN=$(echo "$GITHUB_TOKEN" | tr -d ' ')
    git clone --depth 1 "https://${GITHUB_TOKEN}@github.com/turkyhub1280/TPANEL-VPS.git" "${TEMP_DIR}"
fi
cp -rf "${TEMP_DIR}/"* "${APP_DIR}/"
rm -rf "${TEMP_DIR}"
cd "${APP_DIR}"

# Install Node dependencies
echo "📦 Installing backend dependencies..."
npm install --omit=dev --loglevel=error

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
echo "🗃️ Setting up MariaDB 'cpanel_system' schema..."
SQL_USER_CMDS="CREATE USER IF NOT EXISTS 'cpanel_admin'@'localhost' IDENTIFIED BY 'cPanelSecurePass2026!'; ALTER USER 'cpanel_admin'@'localhost' IDENTIFIED BY 'cPanelSecurePass2026!'; GRANT ALL PRIVILEGES ON *.* TO 'cpanel_admin'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"
mariadb -u root -e "$SQL_USER_CMDS" 2>/dev/null || mariadb -e "$SQL_USER_CMDS" 2>/dev/null || true
if [ -f "${APP_DIR}/schema.sql" ]; then
    mariadb -u cpanel_admin -pcPanelSecurePass2026! < "${APP_DIR}/schema.sql" 2>/dev/null || true
fi

# Generate Bcrypt Hash & Insert Master User
echo "🔒 Registering Master Administrator Account..."
BCRYPT_HASH=$(node -e "const b = require('bcryptjs'); console.log(b.hashSync(process.argv[1], 10));" "$MASTER_PASS")
mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO users (name, email, password_hash, role) VALUES ('Master Owner', '${MASTER_EMAIL}', '${BCRYPT_HASH}', 'admin') ON DUPLICATE KEY UPDATE email = '${MASTER_EMAIL}', password_hash = '${BCRYPT_HASH}', role = 'admin';" 2>/dev/null || true
MASTER_USER_ID=$(mariadb -u cpanel_admin -pcPanelSecurePass2026! -N -s -e "USE cpanel_system; SELECT id FROM users WHERE email = '${MASTER_EMAIL}' LIMIT 1;" 2>/dev/null || echo "1")
if [ -z "$MASTER_USER_ID" ]; then MASTER_USER_ID=1; fi

# Seed Master Lifetime License
mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO licenses (license_key, owner_name, owner_email, max_instances, status, notes) VALUES ('TPNL-MASTER-TAMIM-2026-ROOT', 'Tamim Hasan (Master Owner)', '${MASTER_EMAIL}', 9999, 'active', 'Master Owner Authority License') ON DUPLICATE KEY UPDATE status = 'active';" 2>/dev/null || true

# Install tpanel-license CLI tool
if [ -f "${APP_DIR}/tpanel-license.js" ]; then
    cp -f "${APP_DIR}/tpanel-license.js" /usr/local/bin/tpanel-license
    chmod +x /usr/local/bin/tpanel-license
    echo "✅ Master CLI utility installed at /usr/local/bin/tpanel-license"
fi

# Setup Systemd Service
NODE_BIN=$(command -v node || which node || echo "/usr/bin/node")
if [ -f "${APP_DIR}/configs/systemd/cpanel-core.service" ]; then
    cp -f "${APP_DIR}/configs/systemd/cpanel-core.service" /etc/systemd/system/cpanel-core.service
    sed -i "s|ExecStart=.*|ExecStart=${NODE_BIN} ${APP_DIR}/server.js|g" /etc/systemd/system/cpanel-core.service
    systemctl daemon-reload
    systemctl enable cpanel-core.service
    systemctl restart cpanel-core.service
fi

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

# Enterprise Firewall (UFW)
echo "🛡️ Locking down firewall ports..."
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
ufw --force enable 2>/dev/null || true

# Detect Server IP
SERVER_IP=$(curl -s -4 --connect-timeout 4 https://api.ipify.org || curl -s --connect-timeout 4 https://ifconfig.me || hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then SERVER_IP="127.0.0.1"; fi
mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO system_settings (setting_key, setting_value) VALUES ('server_ip', '${SERVER_IP}') ON DUPLICATE KEY UPDATE setting_value = '${SERVER_IP}';" 2>/dev/null || true

# Install & Configure Cloudflare Quick Tunnel (Zero Domain / Instant HTTPS)
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "☁️ Installing Cloudflare Quick Tunnel Agent (cloudflared)..."
    ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    curl -fsSL -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" 2>/dev/null || \
    curl -fsSL -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" 2>/dev/null || true
    chmod +x /usr/local/bin/cloudflared 2>/dev/null || true
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
echo "⏳ Waiting for Cloudflare Quick Tunnel endpoint (up to 15s)..."
for i in $(seq 1 15); do
    sleep 1
    CF_TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/tpanel-tunnel.log 2>/dev/null | head -n 1 || true)
    if [ -n "$CF_TUNNEL_URL" ]; then
        break
    fi
done

if [ -n "$CF_TUNNEL_URL" ]; then
    mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO system_settings (setting_key, setting_value) VALUES ('cloudflare_tunnel_url', '${CF_TUNNEL_URL}') ON DUPLICATE KEY UPDATE setting_value = '${CF_TUNNEL_URL}';" 2>/dev/null || true
fi

# Generate Instant Pre-Authenticated 1-Click Login Token
AUTO_TOKEN=$(node -e "const jwt = require('jsonwebtoken'); const secret = process.env.JWT_SECRET || 'cpanel-secret-super-key-2026-tamim'; console.log(jwt.sign({ id: ${MASTER_USER_ID}, email: '${MASTER_EMAIL}', name: 'Master Owner', role: 'admin', isMaster: true }, secret, { expiresIn: '30d' }));")

# Shorten Master Login URL for Professional Clean Look
SHORT_URL=""
if [ -n "$CF_TUNNEL_URL" ]; then
    LONG_LOGIN_URL="${CF_TUNNEL_URL}/?token=${AUTO_TOKEN}"
    SHORT_URL=$(curl -s -m 5 "https://tinyurl.com/api-create.php?url=$(printf %s "$LONG_LOGIN_URL" | jq -s -R -r @uri 2>/dev/null || echo "$LONG_LOGIN_URL")" 2>/dev/null || true)
    if [[ ! "$SHORT_URL" =~ ^https?:// ]]; then
        SHORT_URL=$(curl -s -m 5 "https://is.gd/create.php?format=simple&url=$(printf %s "$LONG_LOGIN_URL" | jq -s -R -r @uri 2>/dev/null || echo "$LONG_LOGIN_URL")" 2>/dev/null || true)
    fi
fi

# Purge plain-text password from memory
unset MASTER_PASS MASTER_PASS_CONFIRM

echo ""
echo "=========================================================================="
echo "  🎉 CONGRATULATIONS! TPANEL MASTER OWNER NODE DEPLOYED SUCCESSFULLY!"
echo "=========================================================================="
echo ""
echo "  👑 MASTER OWNER    : ${MASTER_EMAIL}"
echo "  🔑 MASTER LICENSE  : TPNL-MASTER-TAMIM-2026-ROOT (Unlimited Authority)"
echo "  🛡️ FIREWALL STATUS : Locked (Web & Mail ports protected)"
echo "  🗄️ DATABASE STATUS : Port 3306 locked to 127.0.0.1 (Internal only)"
echo ""
if [ -n "$SHORT_URL" ] && [[ "$SHORT_URL" =~ ^https?:// ]]; then
echo "  👉 🚀 1-CLICK MASTER SETUP & LOGIN (প্রফেশনাল ইউনিক লিঙ্ক):"
echo "     ${SHORT_URL}"
echo "     (Instant Auto-Login • Cloudflare Edge • Domain Onboarding Ready)"
echo ""
fi
if [ -n "$CF_TUNNEL_URL" ]; then
echo "  👉 🌐 DIRECT SECURE HTTPS URL (ক্লাউডফ্লেয়ার ডিরেক্ট লিঙ্ক):"
echo "     ${CF_TUNNEL_URL}/?token=${AUTO_TOKEN}"
echo ""
fi
echo "  👉 🖥️ DIRECT SERVER IP LOGIN (সার্ভার আইপি সাধারণ লিঙ্ক):"
echo "     http://${SERVER_IP}/"
echo "     Email: ${MASTER_EMAIL}"
echo ""
echo "  🛠️ MASTER CLI TOOL READY:"
echo "     • Create new client license : tpanel-license create --instances 1 --name \"Client\""
echo "     • List all client licenses  : tpanel-license list"
echo "     • Revoke any client license : tpanel-license revoke <KEY>"
echo "=========================================================================="
echo ""
