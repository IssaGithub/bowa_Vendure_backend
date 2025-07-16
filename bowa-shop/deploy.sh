#!/bin/bash

# Bowa Vendure Backend Deployment Script
# Dieses Skript deployed das Backend auf einen VPS mit NGINX

set -e

# Konfiguration
APP_NAME="bowa-backend"
APP_DIR="/var/www/bowa-backend"
NODE_USER="www-data"
SERVICE_NAME="bowa-backend"
DOMAIN="yourdomain.com"  # Ersetzen Sie dies mit Ihrer Domain
BACKEND_PORT=3000
ADMIN_PORT=3002

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment of Bowa Vendure Backend...${NC}"

# Funktion für Fehlerbehandlung
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Überprüfen ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then
    error_exit "Bitte als root ausführen (sudo $0)"
fi

echo -e "${YELLOW}1. Aktualisiere System-Pakete...${NC}"
apt update && apt upgrade -y

echo -e "${YELLOW}2. Installiere Node.js, npm und PM2...${NC}"
# Node.js 20 installieren
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# PM2 global installieren
npm install -g pm2

echo -e "${YELLOW}3. Erstelle Anwendungsverzeichnis...${NC}"
mkdir -p $APP_DIR
cd $APP_DIR

echo -e "${YELLOW}4. Kopiere Anwendungsdateien...${NC}"
# Kopiere alle Dateien außer node_modules
rsync -av --exclude=node_modules --exclude=.git --exclude=dist . $APP_DIR/

# Setze richtige Berechtigungen
chown -R $NODE_USER:$NODE_USER $APP_DIR
chmod +x $APP_DIR/deploy.sh

echo -e "${YELLOW}5. Installiere Abhängigkeiten...${NC}"
cd $APP_DIR
sudo -u $NODE_USER npm install

echo -e "${YELLOW}6. Baue Anwendung...${NC}"
sudo -u $NODE_USER npm run build

echo -e "${YELLOW}7. Erstelle Umgebungskonfiguration...${NC}"
cat > $APP_DIR/.env << EOL
APP_ENV=production
PORT=$BACKEND_PORT
SUPERADMIN_USERNAME=admin
SUPERADMIN_PASSWORD=secure_password_here
COOKIE_SECRET=your_cookie_secret_here
EOL

chown $NODE_USER:$NODE_USER $APP_DIR/.env

echo -e "${YELLOW}8. Konfiguriere PM2...${NC}"
cat > $APP_DIR/ecosystem.config.js << EOL
module.exports = {
  apps: [
    {
      name: '${SERVICE_NAME}-server',
      script: './dist/index.js',
      instances: 1,
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'production',
        PORT: $BACKEND_PORT
      },
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_file: './logs/combined.log',
      time: true
    },
    {
      name: '${SERVICE_NAME}-worker',
      script: './dist/index-worker.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production'
      },
      error_file: './logs/worker-err.log',
      out_file: './logs/worker-out.log',
      log_file: './logs/worker-combined.log',
      time: true
    }
  ]
}
EOL

# Erstelle logs-Verzeichnis
mkdir -p $APP_DIR/logs
chown -R $NODE_USER:$NODE_USER $APP_DIR/logs

echo -e "${YELLOW}9. Starte Anwendung mit PM2...${NC}"
cd $APP_DIR
sudo -u $NODE_USER pm2 start ecosystem.config.js
sudo -u $NODE_USER pm2 save
sudo -u $NODE_USER pm2 startup

echo -e "${YELLOW}10. Konfiguriere NGINX...${NC}"
cat > /etc/nginx/sites-available/$APP_NAME << 'EOL'
# Bowa Backend NGINX Configuration
server {
    listen 80;
    server_name api.DOMAIN_PLACEHOLDER admin.DOMAIN_PLACEHOLDER;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.DOMAIN_PLACEHOLDER;
    
    # SSL-Konfiguration (SSL-Zertifikate müssen separat konfiguriert werden)
    # ssl_certificate /path/to/your/certificate.pem;
    # ssl_certificate_key /path/to/your/private.key;
    
    # Für Entwicklung - entfernen Sie diese Zeilen für Produktion
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    
    # API Backend
    location / {
        proxy_pass http://127.0.0.1:BACKEND_PORT_PLACEHOLDER;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Assets
    location /assets {
        alias /var/www/bowa-backend/static/assets;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

server {
    listen 443 ssl http2;
    server_name admin.DOMAIN_PLACEHOLDER;
    
    # SSL-Konfiguration (gleiche wie oben)
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    
    # Admin UI
    location / {
        proxy_pass http://127.0.0.1:ADMIN_PORT_PLACEHOLDER;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOL

# Ersetze Platzhalter
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /etc/nginx/sites-available/$APP_NAME
sed -i "s/BACKEND_PORT_PLACEHOLDER/$BACKEND_PORT/g" /etc/nginx/sites-available/$APP_NAME
sed -i "s/ADMIN_PORT_PLACEHOLDER/$ADMIN_PORT/g" /etc/nginx/sites-available/$APP_NAME

# Aktiviere Site
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo -e "${YELLOW}11. Konfiguriere Firewall...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "${GREEN}Deployment erfolgreich abgeschlossen!${NC}"
echo ""
echo -e "${GREEN}Ihr Backend ist erreichbar unter:${NC}"
echo -e "API: https://api.$DOMAIN"
echo -e "Admin: https://admin.$DOMAIN"
echo ""
echo -e "${YELLOW}Weitere Schritte:${NC}"
echo "1. Aktualisieren Sie die Domain in diesem Skript: $DOMAIN"
echo "2. Ändern Sie die Passwörter in $APP_DIR/.env"
echo "3. Konfigurieren Sie SSL-Zertifikate (Let's Encrypt empfohlen)"
echo "4. Testen Sie die Anwendung"
echo ""
echo -e "${GREEN}PM2 Kommandos:${NC}"
echo "pm2 status - Status anzeigen"
echo "pm2 logs - Logs anzeigen"
echo "pm2 restart $SERVICE_NAME-server - Server neu starten"
echo "pm2 restart $SERVICE_NAME-worker - Worker neu starten" 