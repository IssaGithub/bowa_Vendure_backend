# Bowa Backend Deployment Guide

## Übersicht

Dieses Dokument beschreibt, wie Sie das Bowa Vendure Backend auf einem VPS mit NGINX deployen.

## Backend-URLs

Nach dem Deployment ist das Backend unter folgenden URLs erreichbar:

- **API Endpoint**: `https://api.yourdomain.com`
- **Admin Interface**: `https://admin.yourdomain.com`
- **Assets**: `https://api.yourdomain.com/assets/`

## Voraussetzungen

- Ubuntu/Debian VPS mit Root-Zugriff
- Domain mit DNS-Einträgen für `api.yourdomain.com` und `admin.yourdomain.com`
- NGINX bereits installiert

## Deployment-Schritte

### 1. Dateien auf den Server übertragen

```bash
# Übertragen Sie den gesamten bowa-shop Ordner auf Ihren Server
scp -r bowa-shop/ root@your-server-ip:/tmp/
```

### 2. Deployment-Skript ausführen

```bash
ssh root@your-server-ip
cd /tmp/bowa-shop
chmod +x deploy.sh
./deploy.sh
```

### 3. Konfiguration anpassen

```bash
# Bearbeiten Sie die Umgebungsvariablen
nano /var/www/bowa-backend/.env

# Wichtige Variablen:
# - DOMAIN: Ihre Domain
# - SUPERADMIN_USERNAME: Admin-Benutzername
# - SUPERADMIN_PASSWORD: Sicheres Passwort
# - COOKIE_SECRET: Zufälliger String
```

### 4. SSL-Zertifikate installieren

```bash
# Bearbeiten Sie zuerst die Domain im SSL-Skript
nano /var/www/bowa-backend/ssl-setup.sh

# Dann ausführen
chmod +x /var/www/bowa-backend/ssl-setup.sh
/var/www/bowa-backend/ssl-setup.sh
```

### 5. DNS-Einträge konfigurieren

Stellen Sie sicher, dass folgende DNS-Einträge existieren:

```
api.yourdomain.com    A    YOUR_SERVER_IP
admin.yourdomain.com  A    YOUR_SERVER_IP
```

## Vendure-Konfiguration

Das Backend nutzt folgende Pfade:

- **Shop API**: `https://api.yourdomain.com/shop-api`
- **Admin API**: `https://api.yourdomain.com/admin-api`
- **Admin UI**: `https://admin.yourdomain.com/admin`
- **GraphQL Playground**: `https://api.yourdomain.com/graphql`

## Verwaltung

### PM2 Kommandos

```bash
# Status anzeigen
pm2 status

# Logs anzeigen
pm2 logs

# Anwendung neu starten
pm2 restart bowa-backend-server
pm2 restart bowa-backend-worker

# Anwendung stoppen
pm2 stop bowa-backend-server
pm2 stop bowa-backend-worker
```

### Logs

Logs finden Sie unter:
- `/var/www/bowa-backend/logs/`

### Datenbank

Die SQLite-Datenbank befindet sich unter:
- `/var/www/bowa-backend/vendure.sqlite`

**Wichtig**: Für Produktionsumgebungen wird PostgreSQL empfohlen.

## Sicherheit

### Firewall

Das Deployment-Skript konfiguriert UFW:
- Port 22 (SSH)
- Port 80 (HTTP)
- Port 443 (HTTPS)

### SSL-Zertifikate

SSL-Zertifikate werden automatisch erneuert. Überprüfung mit:
```bash
certbot renew --dry-run
```

### Backup

Erstellen Sie regelmäßig Backups:
```bash
# Datenbank-Backup
cp /var/www/bowa-backend/vendure.sqlite /backup/vendure-$(date +%Y%m%d).sqlite

# Assets-Backup
tar -czf /backup/assets-$(date +%Y%m%d).tar.gz /var/www/bowa-backend/static/assets/
```

## Fehlerbehebung

### Backend reagiert nicht

```bash
# Überprüfen Sie PM2-Status
pm2 status

# Überprüfen Sie Logs
pm2 logs

# Neustart
pm2 restart all
```

### NGINX-Fehler

```bash
# Konfiguration testen
nginx -t

# Status überprüfen
systemctl status nginx

# Logs überprüfen
tail -f /var/log/nginx/error.log
```

### SSL-Probleme

```bash
# Zertifikat-Status überprüfen
certbot certificates

# Manuell erneuern
certbot renew

# NGINX neu laden
systemctl reload nginx
```

## Updates

Für Updates:

```bash
cd /var/www/bowa-backend
git pull  # Falls Git verwendet wird
npm install
npm run build
pm2 restart all
```

## Kontakt

Bei Problemen wenden Sie sich an den Administrator. 