# SSL Certificate Checker Service

This service monitors SSL certificates for multiple domains and provides a web interface to view certificate status.

## Features
- Checks SSL certificate expiration dates
- Provides web interface with status report
- Daily automatic checks via cron job
- Downloadable certificate files
- Email alerts for expiring certificates (TODO)

## Requirements
- Docker
- Docker Compose

## Setup

1. Clone this repository
2. Edit `hosts.txt` with your domains and ports:
   ```
   example.com 443
   anotherdomain.com 8443
   ```
3. Build and start the service:
   ```bash
   docker compose up -d
   ```

## Configuration

### Timezone
The application uses the timezone specified in the TZ environment variable (default: UTC). This can be configured in docker-compose.yml:

```yaml
environment:
  TZ: Europe/Zurich
```

Supported timezones:
- Any valid timezone from the IANA Time Zone Database
- Examples: UTC, Europe/Zurich, America/New_York, Asia/Tokyo

The timezone affects:
- Log timestamps
- Certificate expiration dates
- Report generation timestamps

### Files
- `hosts.txt`: List of domains and ports to check
- `nginx.conf`: Nginx web server configuration
- `check_ssl.sh`: Main SSL checking script
- `start.sh`: Service startup script

### Environment Variables
- `TZ`: Timezone (default: UTC)
- `EMAIL_RECIPIENT`: Email address for alerts (TODO)

## Usage

Access the web interface at: http://localhost:8080

The interface shows:
- Domain name
- Port
- Days until expiration
- Expiration date
- Certificate download link

## Maintenance

### View logs
```bash
docker compose logs -f
```

### Update configuration
1. Edit configuration files
2. Rebuild and restart:
   ```bash
   docker compose up -d --build
   ```

### Add new domains
1. Edit `hosts.txt`
2. Restart service:
   ```bash
   docker compose restart
   ```

## File Descriptions

### check_ssl.sh
Main script that:
- Reads hosts.txt
- Checks SSL certificates
- Generates HTML report
- Saves certificates to /var/www/html/certs

### start.sh
Service startup script that:
- Starts FastCGI service
- Runs initial SSL check
- Starts cron daemon
- Starts Nginx

### nginx.conf
Nginx configuration that:
- Serves HTML report
- Provides certificate downloads
- Handles FastCGI requests

### Dockerfile
Builds the container with:
- Required packages (openssl, nginx, etc.)
- Proper permissions
- Cron job for daily checks

## License
MIT License
