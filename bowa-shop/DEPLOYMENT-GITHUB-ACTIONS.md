# GitHub Actions Deployment Guide

Diese Anleitung erklärt, wie Sie das Bowa Vendure Backend mit GitHub Actions automatisch auf einen VPS deployen.

## Übersicht

Das Deployment erfolgt in zwei Phasen:
1. **Build**: Code wird kompiliert und als Artefakt verpackt
2. **Deploy**: Artefakt wird auf den VPS übertragen und installiert

## Voraussetzungen

### VPS Requirements
- Ubuntu 20.04+ oder Debian 11+
- SSH-Zugang mit sudo-Rechten
- Mindestens 2GB RAM
- Node.js 20+ (wird automatisch installiert)
- NGINX (wird automatisch installiert)

### Domain Setup
- Eine registrierte Domain
- DNS-Einträge für:
  - `api.yourdomain.com` → VPS IP
  - `admin.yourdomain.com` → VPS IP

## Setup

### 1. SSH-Schlüssel generieren

Generieren Sie ein SSH-Schlüsselpaar für das Deployment:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/bowa-deploy -N ""
```

### 2. SSH-Schlüssel auf VPS installieren

```bash
# Public Key auf VPS kopieren
ssh-copy-id -i ~/.ssh/bowa-deploy.pub user@your-vps-ip

# Testen Sie die Verbindung
ssh -i ~/.ssh/bowa-deploy user@your-vps-ip
```

### 3. GitHub Secrets konfigurieren

Gehen Sie zu GitHub Repository → Settings → Secrets and variables → Actions

Fügen Sie folgende Secrets hinzu:

#### VPS Connection
```
VPS_HOST=your-vps-ip-or-hostname
VPS_USER=your-ssh-username
VPS_SSH_KEY=<inhalt-der-privaten-schlüssel-datei>
```

#### Application Configuration
```
DOMAIN=yourdomain.com
FRONTEND_DOMAIN=yourdomain.com
SUPERADMIN_USERNAME=admin
SUPERADMIN_PASSWORD=<sicheres-passwort>
COOKIE_SECRET=<zufälliger-string-mindestens-32-zeichen>
```

#### Database Configuration (Optional)
```
DB_TYPE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bowa_vendure
DB_USERNAME=vendure_user
DB_PASSWORD=<db-passwort>
```

### 4. VPS für Deployment vorbereiten

#### Passwordless Sudo einrichten
```bash
# Auf dem VPS als root oder mit sudo
echo "your-username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/deploy
```

#### Firewall vorbereiten (falls nicht vorhanden)
```bash
sudo ufw allow OpenSSH
sudo ufw enable
```

## SSL-Zertifikate einrichten

### Option 1: Manuell über Workflow

1. Gehen Sie zu GitHub Actions → "Setup SSL Certificates"
2. Klicken Sie "Run workflow"
3. Geben Sie Ihre Domain und E-Mail-Adresse ein
4. Starten Sie den Workflow

### Option 2: Manuell auf dem VPS

```bash
# Certbot installieren
sudo apt install certbot python3-certbot-nginx

# Zertifikate erstellen
sudo certbot --nginx -d yourdomain.com -d api.yourdomain.com -d admin.yourdomain.com

# Automatische Erneuerung einrichten
sudo crontab -e
# Fügen Sie hinzu: 0 12 * * * /usr/bin/certbot renew --quiet
```

## Deployment ausführen

### Automatisches Deployment

Das Deployment wird automatisch ausgelöst bei:
- Push auf den `main` Branch
- Manueller Trigger über GitHub Actions

### Manuelles Deployment

1. Gehen Sie zu GitHub Actions → "Deploy to VPS"
2. Klicken Sie "Run workflow"
3. Wählen Sie das Environment (production/staging)
4. Starten Sie den Workflow

## Monitoring und Troubleshooting

### PM2 Status prüfen

```bash
# Auf dem VPS
pm2 status
pm2 logs
pm2 logs bowa-backend-server
pm2 logs bowa-backend-worker
```

### NGINX Status prüfen

```bash
sudo systemctl status nginx
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### Application Logs

```bash
cd /var/www/bowa-backend
tail -f logs/combined.log
tail -f logs/err.log
```

### Health Check

```bash
curl https://api.yourdomain.com/health
```

## Umgebungen

### Production
- Branch: `main`
- Domain: Ihre Produktions-Domain
- SSL: Let's Encrypt Zertifikate

### Staging (Optional)
- Branch: `staging`
- Domain: staging.yourdomain.com
- SSL: Selbstsignierte Zertifikate möglich

## Rollback

Bei Problemen können Sie einen Rollback durchführen:

```bash
# Auf dem VPS
cd /var/www/bowa-backend
git log --oneline -10  # Letzte 10 Commits anzeigen
git checkout <commit-hash>
npm install --production
npm run build
pm2 restart all
```

## Wartung

### Updates
- Updates erfolgen automatisch bei neuen Commits
- Dependencies werden bei jedem Deployment aktualisiert

### Backup
- Sichern Sie regelmäßig die Datenbank
- Sichern Sie die `/var/www/bowa-backend` Verzeichnis

### Monitoring
- Überwachen Sie PM2 Prozesse
- Überwachen Sie NGINX Logs
- Überwachen Sie SSL-Zertifikat Ablauf

## Troubleshooting

### Häufige Probleme

1. **SSH Connection Failed**
   - Prüfen Sie VPS_HOST, VPS_USER, VPS_SSH_KEY
   - Testen Sie SSH-Verbindung manuell

2. **Permission Denied**
   - Prüfen Sie sudo-Rechte auf dem VPS
   - Stellen Sie sicher, dass passwordless sudo konfiguriert ist

3. **Port bereits in Verwendung**
   - Stoppen Sie alte Prozesse: `pm2 kill`
   - Prüfen Sie: `netstat -tulpn | grep :3000`

4. **SSL Certificate Error**
   - Führen Sie den SSL-Setup Workflow aus
   - Prüfen Sie DNS-Einstellungen

5. **Database Connection Error**
   - Prüfen Sie DB_* Secrets
   - Stellen Sie sicher, dass die Datenbank läuft

### Support

Bei Problemen prüfen Sie:
1. GitHub Actions Logs
2. VPS System Logs: `journalctl -f`
3. Application Logs: `/var/www/bowa-backend/logs/`
4. NGINX Logs: `/var/log/nginx/`

## Security Best Practices

1. **SSH Keys**: Verwenden Sie separate SSH-Keys nur für Deployment
2. **Secrets**: Rotieren Sie regelmäßig Passwörter und Secrets
3. **Firewall**: Nur notwendige Ports öffnen
4. **SSL**: Verwenden Sie immer HTTPS in Production
5. **Updates**: Halten Sie System und Dependencies aktuell 