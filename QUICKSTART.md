# Bowa Backend - Schnellstart Deployment

## 🚀 Schnellstart (5 Minuten)

### 1. Vorbereitung
```bash
# Ersetzen Sie in folgenden Dateien "yourdomain.com" mit Ihrer Domain:
# - deploy.sh (Zeile 13)
# - ssl-setup.sh (Zeile 8)
# - production.env (Zeile 16)
```

### 2. Deployment
```bash
# Dateien auf Server übertragen
scp -r bowa-shop/ root@YOUR_SERVER_IP:/tmp/

# Auf Server einloggen und deployen
ssh root@YOUR_SERVER_IP
cd /tmp/bowa-shop
chmod +x deploy.sh
./deploy.sh
```

### 3. SSL-Zertifikate
```bash
# SSL-Skript anpassen und ausführen
nano /var/www/bowa-backend/ssl-setup.sh  # Domain und E-Mail anpassen
chmod +x /var/www/bowa-backend/ssl-setup.sh
/var/www/bowa-backend/ssl-setup.sh
```

### 4. Konfiguration
```bash
# Produktions-Einstellungen
nano /var/www/bowa-backend/.env
# Ändern Sie:
# - SUPERADMIN_PASSWORD
# - COOKIE_SECRET
# - DOMAIN
```

## 📍 Backend-URLs

Nach erfolgreichem Deployment ist Ihr Backend erreichbar unter:

- **🔗 API**: `https://api.yourdomain.com`
- **🛠️ Admin**: `https://admin.yourdomain.com`
- **📦 Assets**: `https://api.yourdomain.com/assets/`

## 🔧 Wichtige Endpoints

- **Shop API**: `https://api.yourdomain.com/shop-api`
- **Admin API**: `https://api.yourdomain.com/admin-api`
- **GraphQL Playground**: `https://api.yourdomain.com/graphql`
- **Admin Interface**: `https://admin.yourdomain.com/admin`

## 🔒 DNS-Einträge

Stellen Sie sicher, dass folgende DNS-Einträge existieren:
```
api.yourdomain.com    A    YOUR_SERVER_IP
admin.yourdomain.com  A    YOUR_SERVER_IP
```

## 🔍 Überprüfung

```bash
# Status überprüfen
pm2 status

# Logs anzeigen
pm2 logs

# NGINX-Status
systemctl status nginx

# SSL-Zertifikate überprüfen
certbot certificates
```

## 🛡️ Sicherheit

- [ ] Starke Passwörter in `.env` setzen
- [ ] Firewall ist aktiv (UFW)
- [ ] SSL-Zertifikate installiert
- [ ] Regelmäßige Backups einrichten

## 📱 Frontend-Integration

Für die Frontend-Integration verwenden Sie:

```javascript
// API-Endpunkt für Ihr Frontend
const API_URL = 'https://api.yourdomain.com/shop-api';

// Beispiel für GraphQL-Abfrage
const query = `
  query {
    collections {
      items {
        id
        name
        slug
      }
    }
  }
`;
```

## ⚠️ Troubleshooting

### Backend läuft nicht
```bash
pm2 restart all
pm2 logs
```

### NGINX-Fehler
```bash
nginx -t
systemctl reload nginx
```

### SSL-Probleme
```bash
certbot renew
systemctl reload nginx
```

## 📞 Support

Bei Problemen:
1. Überprüfen Sie die Logs: `pm2 logs`
2. Prüfen Sie die NGINX-Konfiguration: `nginx -t`
3. Lesen Sie die vollständige Dokumentation: `README-DEPLOYMENT.md` 