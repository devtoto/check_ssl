# Dockerfile for SSL Checker Service
# Based on Alpine Linux for minimal footprint

FROM alpine:3.18

RUN apk add --no-cache \
    openssl \
    nginx \
    tzdata \
    dcron \
    fcgiwrap \
    spawn-fcgi \
    bash

WORKDIR /app
COPY check_ssl.sh .
COPY hosts.txt .
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh .

# Nginx Konfiguration und Berechtigungen
RUN mkdir -p /run/nginx && \
    mkdir -p /var/www/html && \
    chmod +x check_ssl.sh start.sh && \
    echo "0 8 * * * /app/check_ssl.sh" > /etc/crontabs/root && \
    chown -R nginx:nginx /var/www/html && \
    # Debug: Zeige Inhalt der hosts.txt
    echo "Hosts file content:" && \
    cat /app/hosts.txt && \
    # Setze Berechtigungen
    chmod 644 /app/hosts.txt

# Verwende das Start-Skript als Entrypoint
CMD ["/app/start.sh"]
