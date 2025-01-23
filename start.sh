#!/bin/sh
# SSL Checker Service Startup Script
# Handles service initialization and startup

# Starte spawn-fcgi für CGI-Unterstützung
spawn-fcgi -s /var/run/fcgiwrap.sock -u nginx -g nginx -- /usr/bin/fcgiwrap

# Setze Berechtigungen für Socket
chmod 660 /var/run/fcgiwrap.sock

# Führe den initialen SSL-Check durch
/app/check_ssl.sh

# Starte Cron-Daemon
crond -l 2 -b

# Starte Nginx im Vordergrund
nginx -g 'daemon off;'
