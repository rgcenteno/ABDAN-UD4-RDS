#!/bin/bash
set -euxo pipefail

# ====== CONFIGURACIÓN ======
REPO_URL="https://bitbucket.org/rgcenteno/aws-dynamo-php.git"
APP_DIR="/var/www/app"
WEB_DIR="$APP_DIR/www"
PUBLIC_DIR="$WEB_DIR/public"
# ===========================

export HOME=/root
export COMPOSER_HOME=/root/.composer
export GIT_TERMINAL_PROMPT=0

# 1. Actualizar el sistema
dnf upgrade -y --releasever=latest

# 2. Instalar Apache, Git y PHP 8.4
dnf install -y httpd git unzip \
  php8.4 php8.4-cli php8.4-common php8.4-fpm php8.4-opcache \
  php8.4-mbstring php8.4-xml php8.4-pdo php8.4-mysqlnd \
  php8.4-gd php8.4-zip php8.4-intl

# 3. Clonar el repositorio (rama por defecto)
rm -rf "$APP_DIR"
git clone --depth 1 "$REPO_URL" "$APP_DIR"

# 4. Instalar dependencias de Composer si existe www/composer.json
if [ -f "$WEB_DIR/composer.json" ]; then
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  cd "$WEB_DIR"
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction
fi

chown -R apache:apache "$APP_DIR"

# 5. VirtualHost apuntando a www/public
cat > /etc/httpd/conf.d/app.conf <<EOF
<VirtualHost *:80>
    DocumentRoot ${PUBLIC_DIR}

    <Directory ${PUBLIC_DIR}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    ErrorLog /var/log/httpd/app_error.log
    CustomLog /var/log/httpd/app_access.log combined
</VirtualHost>
EOF

# 6. Quitar la página de bienvenida por defecto
rm -f /etc/httpd/conf.d/welcome.conf

# 7. Arrancar servicios
systemctl enable --now php-fpm
systemctl enable --now httpd
