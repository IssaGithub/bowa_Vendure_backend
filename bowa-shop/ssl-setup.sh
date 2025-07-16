#!/bin/bash

# SSL-Setup mit Let's Encrypt für Bowa Backend
# Dieses Skript konfiguriert SSL-Zertifikate für das Backend

set -e

# Konfiguration
DOMAIN="yourdomain.com"  # Ersetzen Sie dies mit Ihrer Domain
EMAIL="your-email@domain.com"  # Ersetzen Sie dies mit Ihrer E-Mail
APP_NAME="bowa-backend"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}SSL-Setup für Bowa Backend...${NC}"

# Überprüfen ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Bitte als root ausführen (sudo $0)${NC}"
    exit 1
fi

# Überprüfen ob Domain konfiguriert ist
if [ "$DOMAIN" = "yourdomain.com" ]; then
    echo -e "${RED}Bitte konfigurieren Sie zuerst die DOMAIN-Variable in diesem Skript${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Installiere Certbot...${NC}"
apt update
apt install -y certbot python3-certbot-nginx

echo -e "${YELLOW}2. Erstelle SSL-Zertifikate...${NC}"
certbot --nginx -d api.$DOMAIN -d admin.$DOMAIN --email $EMAIL --agree-tos --non-interactive

echo -e "${YELLOW}3. Aktualisiere NGINX-Konfiguration...${NC}"
# Die Zertifikate werden automatisch von certbot in die NGINX-Konfiguration eingetragen

echo -e "${YELLOW}4. Teste NGINX-Konfiguration...${NC}"
nginx -t

echo -e "${YELLOW}5. Lade NGINX neu...${NC}"
systemctl reload nginx

echo -e "${YELLOW}6. Richte automatische Zertifikat-Erneuerung ein...${NC}"
# Certbot richtet automatisch einen cron-job ein, aber wir testen ihn
certbot renew --dry-run

echo -e "${GREEN}SSL-Setup erfolgreich abgeschlossen!${NC}"
echo ""
echo -e "${GREEN}Ihre sicheren URLs:${NC}"
echo -e "API: https://api.$DOMAIN"
echo -e "Admin: https://admin.$DOMAIN"
echo ""
echo -e "${YELLOW}Zertifikate werden automatisch vor Ablauf erneuert.${NC}"
echo "Überprüfung mit: certbot renew --dry-run" 