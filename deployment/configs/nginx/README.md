# Nginx Configuration Files

This directory contains the nginx configuration files used on the production server.

## Files

### Host Nginx (System-level)

1. **nginx.conf** - Main nginx configuration
   - Location: `/etc/nginx/nginx.conf`
   - Includes: TLS 1.2/1.3 only, server_tokens off, rate limiting zones
   - Features:
     - Rate limiting zones for DDoS protection
     - Modern TLS configuration
     - Server version hiding

2. **eduaiia.com.conf** - Main site configuration
   - Location: `/etc/nginx/sites-available/eduaiia.com`
   - Symlink: `/etc/nginx/sites-enabled/eduaiia.com`
   - Features:
     - IP blocking (default_server returns 444)
     - Rate limiting applied to all locations
     - Routes for eduaiia.com, api.eduaiia.com, admin.eduaiia.com
     - SSL with Cloudflare Origin Certificate

3. **aiia_frontend_upstream.conf** - Frontend upstream definition
   - Location: `/etc/nginx/conf.d/aiia_frontend_upstream.conf`
   - Defines upstream for Next.js frontend on port 3002

### Container Nginx (Docker)

Located in `../../docker/nginx/`:
- `nginx.conf` - Container nginx configuration with rate limiting
- `subdomain.conf` - Backend API/admin routing with default_server block

## Deployment Instructions

### Installing Host Nginx Configuration:

```bash
# Copy files
sudo cp nginx.conf /etc/nginx/nginx.conf
sudo cp eduaiia.com.conf /etc/nginx/sites-available/eduaiia.com
sudo cp aiia_frontend_upstream.conf /etc/nginx/conf.d/

# Create symlink if not exists
sudo ln -sf /etc/nginx/sites-available/eduaiia.com /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

## Security Features Implemented

### 1. TLS Configuration
- Only TLS 1.2 and 1.3 enabled (TLS 1.0/1.1 deprecated)
- Strong cipher suites
- Cloudflare Origin Certificate

### 2. Rate Limiting
- Frontend: 50 req/s (burst 100)
- API: 100 req/s (burst 200)
- Connection limits per IP

### 3. IP Access Blocking
- Direct IP access returns 444 (connection closed)
- Prevents reconnaissance
- Forces access through domain names

### 4. Security Headers
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY/SAMEORIGIN
- X-XSS-Protection: 1; mode=block

### 5. Server Information Hiding
- server_tokens off
- No version disclosure

## Rate Limiting Details

**Zones defined in nginx.conf:**
```nginx
limit_req_zone $binary_remote_addr zone=frontend:10m rate=50r/s;
limit_req_zone $binary_remote_addr zone=api_proxy:10m rate=100r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
```

**Applied in eduaiia.com.conf:**
- Frontend: `limit_req zone=frontend burst=100 nodelay;`
- API/Admin: `limit_req zone=api_proxy burst=200 nodelay;`

## Maintenance

### Updating Cloudflare IPs (run monthly):
```bash
curl https://www.cloudflare.com/ips-v4 > /tmp/cf-ips-v4.txt
curl https://www.cloudflare.com/ips-v6 > /tmp/cf-ips-v6.txt
# Compare with /etc/nginx/conf.d/cloudflare-real-ip.conf
```

### Testing Configuration:
```bash
sudo nginx -t
```

### Reloading (zero downtime):
```bash
sudo systemctl reload nginx
```

### Checking Logs:
```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

## Troubleshooting

### 502 Bad Gateway
- Check if backend services are running
- Verify upstream configuration
- Check firewall rules

### Rate Limiting Triggered
- Check logs: `grep "limiting requests" /var/log/nginx/error.log`
- Adjust rates if legitimate traffic is blocked

### SSL Issues
- Verify certificate paths
- Check Cloudflare SSL mode (should be "Full")
- Ensure certificate not expired
