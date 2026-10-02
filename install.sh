#!/bin/bash
# One-time setup of NII App on the server — separate from the journal site:
# its own folder, its own database and its own address (port 8080 and app.<domain>).
#
#   git clone https://github.com/aiganymaset002-arch/nii-app.git /var/www/nii-app
#   bash /var/www/nii-app/install.sh
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="app.nii-arai-publishhouse.kz"
PORT=8080
cd "$APP_DIR"

if [ -f config.local.php ]; then
    echo "NII App is already installed. To update: cd $APP_DIR && git pull"
    exit 0
fi

# ---------- Database ----------
DB_PASS=$(openssl rand -hex 16)
ADMIN_CODE="ADMIN-$(openssl rand -hex 4)"
TEAM_CODE="TEAM-$(openssl rand -hex 4)"

mysql -e "CREATE DATABASE IF NOT EXISTS nii_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'nii_app'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "ALTER USER 'nii_app'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON nii_app.* TO 'nii_app'@'localhost'; FLUSH PRIVILEGES;"

if [ "$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'nii_app'")" = "0" ]; then
    mysql nii_app < schema.sql
fi

cat > config.local.php <<CONF
<?php
return [
    "db_user"    => "nii_app",
    "db_pass"    => "$DB_PASS",
    "debug"      => false,
    "admin_code" => "$ADMIN_CODE",
    "team_code"  => "$TEAM_CODE",
];
CONF

chown root:www-data config.local.php
chmod 640 config.local.php
mkdir -p uploads
chown -R www-data:www-data uploads

# ---------- Web server (separate nginx site) ----------
if command -v nginx >/dev/null 2>&1; then
    PHP_SOCK=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n 1)

    cat > /etc/nginx/sites-available/nii-app <<NGINX
server {
    listen $PORT;
    listen [::]:$PORT;
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $APP_DIR;
    index index.php;
    client_max_body_size 25M;

    location ~ /\\. { deny all; }
    location ~ ^/(config\\.local\\.php|schema\\.sql|install\\.sh|README\\.md|tailwind\\.config\\.js|roadmap-data\\.php|lib\\.php|layout\\.php)\$ { deny all; }
    location ^~ /uploads/ { location ~ \\.php\$ { deny all; } }

    location / { try_files \$uri \$uri/ =404; }

    location ~ \\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }
}
NGINX

    ln -sf /etc/nginx/sites-available/nii-app /etc/nginx/sites-enabled/nii-app
    nginx -t && systemctl reload nginx

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow $PORT/tcp >/dev/null
    fi
fi

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "======================================"
echo " NII App installed"
echo " Open:  http://$IP:$PORT"
echo "        (later http://$DOMAIN after DNS)"
echo " Organizer (admin) code: $ADMIN_CODE"
echo " Team code:              $TEAM_CODE"
echo " Save both codes!"
echo "======================================"
