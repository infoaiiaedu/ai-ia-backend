#!/bin/bash
# SSL Certificate Auto-Renewal Script
# Usage: Run via cron or manually
# Cron: 0 3 * * * /home/ubuntu/main/ai-ia-backend/scripts/ssl-renew.sh

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log "Starting SSL certificate renewal check..."

# Domains to renew
DOMAINS=("eduaiia.com" "www.eduaiia.com" "staging.eduaiia.com" "devstatus.eduaiia.com")

# Check if certbot is available
if ! command -v certbot &> /dev/null; then
    error "certbot is not installed. Install with: sudo apt-get install certbot python3-certbot-nginx"
fi

# Renew certificates
RENEWED=false
for domain in "${DOMAINS[@]}"; do
    log "Checking certificate for $domain..."
    
    # Check certificate expiration (days until expiry)
    EXPIRY_DAYS=$(certbot certificates 2>/dev/null | grep -A 5 "$domain" | grep "Expiry Date" | awk '{print $3, $4, $5}' | xargs -I {} sh -c 'echo $(($(date -d "{}" +%s) - $(date +%s)) / 86400)' 2>/dev/null || echo "999")
    
    if [ "$EXPIRY_DAYS" -lt 30 ]; then
        log "Certificate for $domain expires in $EXPIRY_DAYS days. Renewing..."
        
        # Renew certificate
        if certbot renew --cert-name "$domain" --quiet --no-self-upgrade 2>&1; then
            log "✓ Certificate renewed for $domain"
            RENEWED=true
        else
            warn "Failed to renew certificate for $domain"
        fi
    else
        log "Certificate for $domain is valid for $EXPIRY_DAYS more days. Skipping."
    fi
done

# If certificates were renewed, copy them to nginx ssl directory and reload nginx
if [ "$RENEWED" = true ]; then
    log "Copying renewed certificates to nginx..."
    
    SSL_DIR="docker/nginx/ssl"
    mkdir -p "$SSL_DIR"
    
    for domain in "${DOMAINS[@]}"; do
        CERT_PATH="/etc/letsencrypt/live/$domain"
        if [ -d "$CERT_PATH" ]; then
            # Copy certificates
            sudo cp "$CERT_PATH/fullchain.pem" "$SSL_DIR/${domain}.crt" 2>/dev/null || \
                warn "Failed to copy certificate for $domain"
            sudo cp "$CERT_PATH/privkey.pem" "$SSL_DIR/${domain}.key" 2>/dev/null || \
                warn "Failed to copy private key for $domain"
            
            # Set proper permissions
            sudo chown $USER:$USER "$SSL_DIR/${domain}.crt" "$SSL_DIR/${domain}.key" 2>/dev/null || true
            chmod 600 "$SSL_DIR/${domain}.key" 2>/dev/null || true
            chmod 644 "$SSL_DIR/${domain}.crt" 2>/dev/null || true
        fi
    done
    
    # Reload nginx
    log "Reloading nginx..."
    if docker ps | grep -q aiia_nginx; then
        docker exec aiia_nginx nginx -s reload || warn "Failed to reload nginx"
        log "✓ Nginx reloaded with new certificates"
    else
        warn "Nginx container not running. Certificates copied but nginx not reloaded."
    fi
else
    log "No certificates needed renewal."
fi

log "SSL renewal check completed."

