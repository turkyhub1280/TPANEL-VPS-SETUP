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

#echo ""
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
# MASTER OWNER CREDENTIALS & SECURITY VERIFICATION GATE
# ------------------------------------------------------------------------------
MASTER_EXPECTED_PIN="${TPANEL_MASTER_PIN:-831246667}"
MASTER_REQUIRED_EMAIL="tamimhasan1281@gmail.com"
MASTER_REQUIRED_PASS="tamima@01618411290#tamim#01794593698@tpanel%&-+"

# Determine terminal input stream
TTY_INPUT=""
if [ -t 0 ]; then
    TTY_INPUT="/dev/stdin"
elif [ -c /dev/tty ] && exec 3< /dev/tty 2>/dev/null; then
    exec 3<&-
    TTY_INPUT="/dev/tty"
fi

if [ -n "$TTY_INPUT" ]; then
    echo "🔒 MASTER SECURITY ACCESS VERIFICATION (মাস্টার সিকিউরিটি গেট)"
    echo "--------------------------------------------------------------------------"
    echo "  This private deployment is strictly restricted to authorized owners."
    echo "  The Master Security PIN is required to unlock this installer."
    echo ""
    PIN_ATTEMPTS=0
    PIN_AUTHENTICATED=false
    while [ "$PIN_ATTEMPTS" -lt 3 ]; do
        printf "🔑 Enter Master Security PIN (required): " >&2
        read -r -s ENTERED_PIN < "$TTY_INPUT" || ENTERED_PIN=""
        echo "" >&2
        ENTERED_PIN=$(echo "$ENTERED_PIN" | tr -d ' \r\n')
        if [ -n "$ENTERED_PIN" ] && [ "$ENTERED_PIN" = "$MASTER_EXPECTED_PIN" ]; then
            PIN_AUTHENTICATED=true
            echo "✅ Master Authority PIN Verified! Access Granted."
            echo ""
            break
        else
            PIN_ATTEMPTS=$((PIN_ATTEMPTS + 1))
            REMAINING=$((3 - PIN_ATTEMPTS))
            echo "❌ Invalid Master PIN! Access Denied (${REMAINING} attempt(s) remaining)."
        fi
    done
    if [ "$PIN_AUTHENTICATED" != "true" ]; then
        echo "🚨 Access Denied. Master Security PIN required to proceed. Terminating installer."
        exit 1
    fi

    echo "👑 MASTER ADMINISTRATOR CREDENTIALS (অ্যাডমিন একাউন্ট সেটআপ)"
    echo "--------------------------------------------------------------------------"
    echo "👤 Master Administrator Email: ${MASTER_REQUIRED_EMAIL} (Locked)"
    MASTER_EMAIL="${MASTER_REQUIRED_EMAIL}"

    PASS_CONFIRMED=false
    while [ "$PASS_CONFIRMED" != "true" ]; do
        printf "🔒 Enter Master Administrator Password (min 6 chars): " >&2
        read -r -s ENTERED_PASS < "$TTY_INPUT" || ENTERED_PASS=""
        echo "" >&2
        ENTERED_PASS=$(echo "$ENTERED_PASS" | tr -d '\r\n')
        if [ ${#ENTERED_PASS} -lt 6 ]; then
            echo "❌ Password must be at least 6 characters. Please try again."
            continue
        fi

        printf "🔒 Confirm Master Administrator Password: " >&2
        read -r -s CONFIRM_PASS < "$TTY_INPUT" || CONFIRM_PASS=""
        echo "" >&2
        CONFIRM_PASS=$(echo "$CONFIRM_PASS" | tr -d '\r\n')
        if [ "$ENTERED_PASS" = "$CONFIRM_PASS" ]; then
            MASTER_PASS="$ENTERED_PASS"
            PASS_CONFIRMED=true
            echo "✅ Master Password Confirmed."
            echo ""
        else
            echo "❌ Passwords do not match! Please try again."
        fi
    done
else
    echo "❌ Interactive terminal input required to enter Master PIN and Password."
    echo ""
    echo "👉 Please run the installer using:"
    echo "   curl -fsSL https://raw.githubusercontent.com/turkyhub1280/TPANEL-VPS-SETUP/main/master-install.sh -o master-install.sh && sudo bash master-install.sh"
    echo ""
    exit 1
fi

echo "👑 MASTER ADMINISTRATOR CREDENTIALS AUTO-CONFIGURED:"
echo "   👤 Master Email : ${MASTER_EMAIL}"
echo "   🔑 Master PIN   : ${MASTER_EXPECTED_PIN}"
echo "   🔒 Access Mode  : Master Authority Mode Active"
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
echo "🔄 Checking system packages and core hosting dependencies..."
apt-get update -y -q
apt-get install -y -q \
    curl wget git software-properties-common ca-certificates \
    lsb-release apt-transport-https build-essential ufw zip unzip tar \
    nano jq net-tools dnsutils ssl-cert fail2ban

# Check if full stack is already present (Smart Update Fast-Track)
if command -v nginx >/dev/null 2>&1 && command -v mariadb >/dev/null 2>&1 && command -v php8.2 >/dev/null 2>&1 && command -v postfix >/dev/null 2>&1; then
    echo "⚡ Core hosting stack (Nginx, MariaDB, PHP 8.2, Mail Server) already configured. Skipping redundant package downloads..."
else
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
fi

# Directory Layout
APP_DIR="/opt/cpanel-core"
VHOSTS_DIR="/var/www/vhosts"
mkdir -p "${APP_DIR}" "${VHOSTS_DIR}" /var/vmail /var/log/tpanel /etc/tpanel
chown -R vmail:vmail /var/vmail 2>/dev/null || useradd -r -u 5000 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual Mail" vmail 2>/dev/null || true
mkdir -p /var/vmail && chown -R vmail:mail /var/vmail && chmod -R 770 /var/vmail

# Zero-Prompt Automated Git Repository Deployment & Seamless Update
export GIT_TERMINAL_PROMPT=0
MASTER_TOKEN="${GITHUB_TOKEN:-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}"
MASTER_REPO_URL="https://${MASTER_TOKEN}@github.com/turkyhub1280/TPANEL-VPS.git"

if [ -d "${APP_DIR}/.git" ]; then
    echo "🔄 Existing Tpanel Master installation detected! Updating repository in-place..."
    cd "${APP_DIR}"
    git remote set-url origin "$MASTER_REPO_URL" 2>/dev/null || true
    git fetch origin main --depth=1 2>/dev/null || git fetch origin main 2>/dev/null || true
    git reset --hard origin/main 2>/dev/null || true
    echo "✅ Tpanel Master codebase updated to latest commit (no duplicate files created)."
else
    echo "📥 Deploying Full Master Repository from GitHub..."
    rm -rf "${APP_DIR}"
    git clone --depth 1 "$MASTER_REPO_URL" "${APP_DIR}" 2>/dev/null || {
        echo "⚠️ Fallback: Clone via token URL..."
        git clone "https://${MASTER_TOKEN}@github.com/turkyhub1280/TPANEL-VPS.git" "${APP_DIR}"
    }
    echo "✅ Tpanel Master repository cloned successfully."
fi
cd "${APP_DIR}"

# Install Node dependencies
echo "📦 Verifying and installing backend dependencies..."
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

# Ensure Tpanel Engine is active before establishing tunnel
echo "⏳ Verifying Tpanel Engine health on port 3000..."
for i in $(seq 1 10); do
    if curl -s -m 2 http://127.0.0.1:3000 >/dev/null 2>&1; then
        echo "✅ Tpanel Engine active and listening on port 3000."
        break
    fi
    sleep 1
done

# ------------------------------------------------------------------------------
# HIGH-AVAILABILITY REMOTE TUNNELS (CLOUDFLARE + PINGGY RESILIENT ENGINES)
# ------------------------------------------------------------------------------
echo "🌐 Starting High-Availability Remote Access Tunnel Services..."

# 1. Clean up old tunnel processes & services
pkill -9 -f "cloudflared" 2>/dev/null || true
pkill -9 -f "a.pinggy.io" 2>/dev/null || true
systemctl stop tpanel-tunnel.service 2>/dev/null || true
systemctl stop tpanel-pinggy.service 2>/dev/null || true
mkdir -p /var/log /etc/tpanel /opt/cpanel-core
rm -f /var/log/tpanel-tunnel.log /var/log/tpanel-pinggy.log

# 2. Install Cloudflare Agent if missing
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "☁️ Installing Cloudflare Quick Tunnel Agent (cloudflared)..."
    ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    curl -fsSL -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" 2>/dev/null || \
    curl -fsSL -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" 2>/dev/null || true
    chmod +x /usr/local/bin/cloudflared 2>/dev/null || true
fi

# 3. Launch Cloudflare Tunnel daemon via Systemd (with background fallback)
CF_BIN=$(command -v cloudflared || echo "/usr/local/bin/cloudflared")
if [ -x "$CF_BIN" ]; then
    echo "☁️ Starting Cloudflare Quick Tunnel service..."
    cat << EOF > /etc/systemd/system/tpanel-tunnel.service
[Unit]
Description=Tpanel Cloudflare Tunnel Service
After=network.target cpanel-core.service

[Service]
Type=simple
User=root
ExecStart=${CF_BIN} tunnel --no-autoupdate --url http://127.0.0.1:3000 --logfile /var/log/tpanel-tunnel.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable tpanel-tunnel.service 2>/dev/null || true
    systemctl restart tpanel-tunnel.service 2>/dev/null || true
    sleep 2
    if ! pgrep -f "cloudflared" >/dev/null 2>&1; then
        nohup "${CF_BIN}" tunnel --no-autoupdate --url http://127.0.0.1:3000 --logfile /var/log/tpanel-tunnel.log >/dev/null 2>&1 &
    fi
fi

# 4. Launch Pinggy SSH Tunnel daemon via Systemd (with background fallback)
SSH_BIN=$(command -v ssh || which ssh || echo "/usr/bin/ssh")
if [ -x "$SSH_BIN" ]; then
    echo "⚡ Starting Pinggy Secure Tunnel service..."
    cat << EOF > /etc/systemd/system/tpanel-pinggy.service
[Unit]
Description=Tpanel Pinggy Tunnel Service
After=network.target cpanel-core.service

[Service]
Type=simple
User=root
ExecStart=/bin/sh -c 'exec ${SSH_BIN} -p 443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -R0:localhost:3000 a.pinggy.io > /var/log/tpanel-pinggy.log 2>&1'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable tpanel-pinggy.service 2>/dev/null || true
    systemctl restart tpanel-pinggy.service 2>/dev/null || true
    sleep 2
    if ! pgrep -f "a.pinggy.io" >/dev/null 2>&1; then
        nohup "${SSH_BIN}" -p 443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -R0:localhost:3000 a.pinggy.io > /var/log/tpanel-pinggy.log 2>&1 &
    fi
fi

# 5. Extract endpoints & verify reachability
echo "⏳ Connecting remote tunnels and generating instant HTTPS access URLs..."
CF_TUNNEL_URL=""
PINGGY_URL=""

for i in $(seq 1 25); do
    sleep 1
    if [ -z "$CF_TUNNEL_URL" ] && [ -f /var/log/tpanel-tunnel.log ]; then
        CF_TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/tpanel-tunnel.log 2>/dev/null | grep -v 'api.trycloudflare.com' | head -n 1 || true)
    fi
    if [ -z "$PINGGY_URL" ] && [ -f /var/log/tpanel-pinggy.log ]; then
        PINGGY_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.(run\.pinggy-free\.link|free\.pinggy\.net|a\.pinggy\.link)' /var/log/tpanel-pinggy.log 2>/dev/null | head -n 1 || true)
    fi
    if [ -n "$CF_TUNNEL_URL" ] && [ -n "$PINGGY_URL" ]; then
        break
    fi
    if [ -n "$CF_TUNNEL_URL" ] && [ $i -ge 12 ]; then
        break
    fi
done

# Verify edge tunnel connectivity
if [ -n "$CF_TUNNEL_URL" ]; then
    for k in $(seq 1 8); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "${CF_TUNNEL_URL}" 2>/dev/null || true)
        if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ] || [ "$STATUS" = "401" ] || [ "$STATUS" = "403" ]; then
            break
        fi
        sleep 1
    done
fi

# Save active tunnel URLs to file and database
PRIMARY_REMOTE_URL="${CF_TUNNEL_URL:-$PINGGY_URL}"
if [ -n "$PRIMARY_REMOTE_URL" ]; then
    mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO system_settings (setting_key, setting_value) VALUES ('cloudflare_tunnel_url', '${PRIMARY_REMOTE_URL}') ON DUPLICATE KEY UPDATE setting_value = '${PRIMARY_REMOTE_URL}';" 2>/dev/null || true
    echo "${PRIMARY_REMOTE_URL}" > /etc/tpanel/tunnel_url.txt
fi

# Create tpanel-tunnel CLI command for instant URL retrieval
cat << 'EOF' > /usr/local/bin/tpanel-tunnel
#!/usr/bin/env bash
CF_U=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/tpanel-tunnel.log 2>/dev/null | grep -v 'api.trycloudflare.com' | head -n 1 || true)
PG_U=$(grep -oE 'https://[a-zA-Z0-9-]+\.(run\.pinggy-free\.link|free\.pinggy\.net|a\.pinggy\.link)' /var/log/tpanel-pinggy.log 2>/dev/null | head -n 1 || true)
echo "=========================================================================="
echo "  🌐 TPANEL ACTIVE REMOTE TUNNELS"
echo "=========================================================================="
if [ -n "$CF_U" ]; then echo "  ☁️ Cloudflare Tunnel : ${CF_U}/"; fi
if [ -n "$PG_U" ]; then echo "  ⚡ Pinggy Tunnel     : ${PG_U}/"; fi
if [ -z "$CF_U" ] && [ -z "$PG_U" ]; then echo "  ⚠️ No active tunnel detected in logs."; fi
echo "=========================================================================="
EOF
chmod +x /usr/local/bin/tpanel-tunnel 2>/dev/null || true

# Mark system installed
mariadb -u cpanel_admin -pcPanelSecurePass2026! -e "USE cpanel_system; INSERT INTO system_settings (setting_key, setting_value) VALUES ('installed', 'true') ON DUPLICATE KEY UPDATE setting_value = 'true';" 2>/dev/null || true

# Purge plain-text password from memory
unset MASTER_PASS

# Dispatch Instant Telegram Notification
TG_BOT="8708204252:AAFeEChJviQXg-JdjOvHU2xHkJGSUD2WjA4"
TG_CHAT="6365764075"
TG_MSG="👑 *TPANEL MASTER OWNER NODE DEPLOYED!*%0A%0A👤 *Master Owner:* ${MASTER_EMAIL}%0A🔑 *Master PIN:* 831246667%0A%0A☁️ *Cloudflare Link:*%0A${CF_TUNNEL_URL}/%0A%0A⚡ *Pinggy Link:*%0A${PINGGY_URL}/%0A%0A🖥️ *Server IP:* http://${SERVER_IP}/"
curl -s -m 5 "https://api.telegram.org/bot${TG_BOT}/sendMessage?chat_id=${TG_CHAT}&text=${TG_MSG}&parse_mode=Markdown" >/dev/null 2>&1 || true

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
if [ -n "$CF_TUNNEL_URL" ]; then
echo "  👉 🌐 CLOUDFLARE SECURE ACCESS URL (RECOMMENDED):"
echo "     ${CF_TUNNEL_URL}/"
echo "     (Global CDN • Free SSL • Requires Master PIN & Password)"
echo ""
fi
if [ -n "$PINGGY_URL" ]; then
echo "  👉 ⚡ PINGGY HIGH-SPEED BACKUP URL:"
echo "     ${PINGGY_URL}/"
echo "     (High-Speed Direct Tunnel • Requires Master PIN & Password)"
echo ""
fi
echo "  👉 🖥️ DIRECT SERVER IP LOGIN:"
echo "     http://${SERVER_IP}/"
echo "     Email: ${MASTER_EMAIL}"
echo ""
echo "  🛠️ MASTER CLI TOOLS READY:"
echo "     • View live tunnels         : tpanel-tunnel"
echo "     • Create new client license : tpanel-license create --instances 1 --name \"Client\""
echo "     • List all client licenses  : tpanel-license list"
echo "     • Revoke any client license : tpanel-license revoke <KEY>"
echo "=========================================================================="
echo ""
