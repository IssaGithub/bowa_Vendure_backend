# Deployment Troubleshooting Guide

## GitHub Actions Issues

### 1. "tar: .: file changed as we read it" Error

**Ursache**: Dateien werden während der Archivierung modifiziert.

**Lösungen**:
```bash
# 1. Überprüfen Sie aktive Prozesse
ps aux | grep node
ps aux | grep npm

# 2. Stoppen Sie alle Node.js Prozesse
sudo pkill -f "node" || true
sudo pkill -f "npm" || true

# 3. Bereinigen Sie temporäre Dateien
find . -name "*.tmp" -delete
find . -name "*.lock" -delete
find . -name ".git/index.lock" -delete

# 4. Warten Sie kurz und erstellen Sie das Archiv
sleep 5
tar -czf deployment.tar.gz --exclude=node_modules --exclude=.git .
```

### 2. Build-Fehler

**Symptom**: `npm run build` schlägt fehl

**Diagnose**:
```bash
# Lokale Überprüfung
cd bowa-shop
npm install
npm run build

# Überprüfen Sie die build-Ausgabe
ls -la dist/
```

**Lösungen**:
- Stellen Sie sicher, dass TypeScript-Konfiguration korrekt ist
- Überprüfen Sie fehlende Dependencies
- Löschen Sie `node_modules` und installieren Sie neu

### 3. SSH-Verbindungsfehler

**Symptom**: SSH connection failed

**Diagnose**:
```bash
# Testen Sie SSH-Verbindung lokal
ssh -i ~/.ssh/bowa-deploy user@your-vps-ip
ssh -v user@your-vps-ip  # Verbose output
```

**Lösungen**:
- Überprüfen Sie VPS_HOST, VPS_USER, VPS_SSH_KEY Secrets
- Stellen Sie sicher, dass SSH-Key korrekt formatiert ist
- Überprüfen Sie VPS Firewall-Einstellungen

## VPS Deployment Issues

### 1. PM2 Prozesse analysieren

```bash
# Status aller PM2 Prozesse
pm2 status

# Detaillierte Logs
pm2 logs --lines 50

# Spezifische Prozess-Logs
pm2 logs bowa-backend-server --lines 100
pm2 logs bowa-backend-worker --lines 100

# Prozess-Informationen
pm2 show bowa-backend-server
pm2 monit
```

### 2. Port-Konflikte

**Symptom**: Port bereits in Verwendung

**Diagnose**:
```bash
# Überprüfen Sie verwendete Ports
netstat -tulpn | grep :3000
netstat -tulpn | grep :3002

# Finden Sie Prozesse auf spezifischen Ports
sudo lsof -i :3000
sudo lsof -i :3002
```

**Lösungen**:
```bash
# Stoppen Sie alte Prozesse
pm2 kill
sudo killall node

# Oder spezifische Ports freigeben
sudo kill -9 $(sudo lsof -t -i:3000)
sudo kill -9 $(sudo lsof -t -i:3002)
```

### 3. NGINX Probleme

**Diagnose**:
```bash
# NGINX Status
sudo systemctl status nginx
sudo nginx -t  # Konfiguration testen

# Logs überprüfen
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

**Häufige Probleme**:
```bash
# SSL-Zertifikat Probleme
sudo certbot certificates
sudo certbot renew --dry-run

# NGINX Konfiguration neu laden
sudo nginx -s reload
sudo systemctl reload nginx
```

### 4. Dateiberechtigungen

**Symptom**: Permission denied Fehler

**Diagnose**:
```bash
# Überprüfen Sie Berechtigungen
ls -la /var/www/bowa-backend/
ls -la /var/www/bowa-backend/.env

# Überprüfen Sie Eigentümer
stat /var/www/bowa-backend/
```

**Lösungen**:
```bash
# Korrekte Berechtigungen setzen
sudo chown -R www-data:www-data /var/www/bowa-backend/
sudo chmod 755 /var/www/bowa-backend/
sudo chmod 600 /var/www/bowa-backend/.env
```

### 5. Datenbank-Verbindungsprobleme

**Diagnose**:
```bash
# SQLite (Standard)
ls -la /var/www/bowa-backend/vendure.sqlite
sqlite3 /var/www/bowa-backend/vendure.sqlite ".tables"

# PostgreSQL
sudo -u postgres psql -c "\l"
sudo -u postgres psql -d bowa_vendure -c "\dt"
```

**Lösungen**:
```bash
# SQLite Berechtigungen
sudo chown www-data:www-data /var/www/bowa-backend/vendure.sqlite
sudo chmod 664 /var/www/bowa-backend/vendure.sqlite

# PostgreSQL Service
sudo systemctl status postgresql
sudo systemctl start postgresql
```

### 6. Speicher-Probleme

**Diagnose**:
```bash
# Speicher-Nutzung prüfen
free -h
df -h
pm2 monit

# Swap-Speicher prüfen
sudo swapon --show
```

**Lösungen**:
```bash
# Swap-Datei erstellen (falls nicht vorhanden)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Permanent machen
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 7. Firewall-Probleme

**Diagnose**:
```bash
# UFW Status
sudo ufw status verbose
sudo ufw app list

# Offene Ports prüfen
sudo netstat -tulpn | grep LISTEN
```

**Lösungen**:
```bash
# Notwendige Ports öffnen
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

## Allgemeine Debugging-Strategien

### 1. System-Logs überprüfen

```bash
# Allgemeine System-Logs
sudo journalctl -f
sudo journalctl -u nginx
sudo journalctl -u pm2-www-data

# Anwendungs-Logs
tail -f /var/www/bowa-backend/logs/combined.log
tail -f /var/www/bowa-backend/logs/err.log
```

### 2. Ressourcen-Monitoring

```bash
# CPU und Speicher
top
htop
iostat 1

# Disk-Nutzung
df -h
du -sh /var/www/bowa-backend/
```

### 3. Netzwerk-Diagnose

```bash
# Connectivity testen
ping yourdomain.com
curl -I https://api.yourdomain.com
telnet yourdomain.com 443
```

### 4. Backup und Recovery

```bash
# Backup erstellen
sudo tar -czf /backup/bowa-backend-$(date +%Y%m%d).tar.gz /var/www/bowa-backend/
sudo cp /var/www/bowa-backend/vendure.sqlite /backup/

# Recovery
sudo tar -xzf /backup/bowa-backend-20231201.tar.gz -C /
sudo systemctl restart nginx
pm2 restart all
```

## Präventive Maßnahmen

### 1. Monitoring einrichten

```bash
# PM2 Monitoring
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7

# System-Monitoring
sudo apt install htop iotop
```

### 2. Automatische Backups

```bash
# Cron-Job für tägliche Backups
echo "0 2 * * * tar -czf /backup/bowa-backend-\$(date +\%Y\%m\%d).tar.gz /var/www/bowa-backend/" | sudo crontab -
```

### 3. Log-Rotation

```bash
# Logrotate konfigurieren
sudo nano /etc/logrotate.d/bowa-backend

# Inhalt:
/var/www/bowa-backend/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 www-data www-data
}
```

## Notfall-Prozeduren

### 1. Kompletter Rollback

```bash
# Stoppen Sie alle Services
pm2 kill
sudo systemctl stop nginx

# Wiederherstellen Sie Backup
sudo tar -xzf /backup/bowa-backend-DATUM.tar.gz -C /

# Services neu starten
sudo systemctl start nginx
cd /var/www/bowa-backend
pm2 start ecosystem.config.js
```

### 2. Schnelle Reparatur

```bash
# Basis-Reparatur-Skript
#!/bin/bash
sudo chown -R www-data:www-data /var/www/bowa-backend/
sudo chmod 755 /var/www/bowa-backend/
sudo chmod 600 /var/www/bowa-backend/.env
pm2 restart all
sudo systemctl reload nginx
```

## Support-Kontakt

Bei anhaltenden Problemen sammeln Sie folgende Informationen:

1. **GitHub Actions Logs** (vollständige Ausgabe)
2. **VPS System-Info**: `uname -a`, `df -h`, `free -h`
3. **Service-Status**: `pm2 status`, `sudo systemctl status nginx`
4. **Error-Logs**: Letzte 50 Zeilen aus allen relevanten Log-Dateien
5. **Konfiguration**: `.env` Datei (ohne Passwörter) 