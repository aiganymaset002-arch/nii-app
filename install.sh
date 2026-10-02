#!/bin/bash
# One-time setup of NII App on the server (Ubuntu, nginx, PHP, MySQL already installed).
# Run as root from the app folder:   bash install.sh
set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

if [ -f config.local.php ]; then
    echo "config.local.php already exists — NII App is already installed."
    echo "To update the app later just run: cd $APP_DIR && git pull"
    exit 0
fi

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

echo ""
echo "======================================"
echo " NII App installed"
echo " Organizer (admin) code: $ADMIN_CODE"
echo " Team code:              $TEAM_CODE"
echo " Save both codes!"
echo "======================================"
