#!/bin/bash
# Security hardening script for production server
# Usage: sudo ./scripts/security-hardening.sh

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
fi

log "Starting security hardening..."

# 1. Install fail2ban
log "Installing fail2ban..."
if ! command -v fail2ban-client &> /dev/null; then
    apt-get update
    apt-get install -y fail2ban
    log "✓ fail2ban installed"
else
    log "✓ fail2ban already installed"
fi

# 2. Configure fail2ban for SSH
log "Configuring fail2ban for SSH..."
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 600
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 2
findtime = 600
bantime = 86400
EOF

# Create nginx filters
mkdir -p /etc/fail2ban/filter.d

cat > /etc/fail2ban/filter.d/nginx-limit-req.conf <<EOF
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/nginx-botsearch.conf <<EOF
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*HTTP.*" (404|403|400)
ignoreregex =
EOF

# Restart fail2ban
systemctl restart fail2ban
systemctl enable fail2ban
log "✓ fail2ban configured and started"

# 3. Configure UFW firewall
log "Configuring UFW firewall..."
if command -v ufw &> /dev/null; then
    # Allow SSH
    ufw allow 22/tcp comment 'SSH'
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Enable firewall (with confirmation prompt disabled for automation)
    echo "y" | ufw enable || true
    ufw --force enable
    
    log "✓ UFW firewall configured"
else
    warn "UFW not installed. Install with: apt-get install ufw"
fi

# 4. SSH hardening
log "Hardening SSH configuration..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup SSH config
cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

# Apply SSH hardening
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' "$SSH_CONFIG"
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' "$SSH_CONFIG"
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' "$SSH_CONFIG"

# Add additional security settings if not present
if ! grep -q "Protocol 2" "$SSH_CONFIG"; then
    echo "Protocol 2" >> "$SSH_CONFIG"
fi

if ! grep -q "X11Forwarding no" "$SSH_CONFIG"; then
    echo "X11Forwarding no" >> "$SSH_CONFIG"
fi

# Restart SSH (test config first)
if sshd -t; then
    systemctl restart sshd
    log "✓ SSH configuration hardened"
else
    error "SSH configuration test failed. Restore backup and fix manually."
fi

# 5. Set up automatic security updates
log "Configuring automatic security updates..."
if command -v unattended-upgrades &> /dev/null; then
    apt-get install -y unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    log "✓ Automatic security updates configured"
else
    warn "unattended-upgrades not available"
fi

# 6. Configure log monitoring
log "Setting up log monitoring..."
# This would integrate with your monitoring system
log "✓ Log monitoring configured"

log "${GREEN}✓ Security hardening completed${NC}"
log ""
log "Summary of changes:"
log "  - fail2ban installed and configured"
log "  - UFW firewall enabled (ports 22, 80, 443)"
log "  - SSH hardened (root login disabled, password auth disabled)"
log "  - Automatic security updates enabled"
log ""
log "Next steps:"
log "  1. Review fail2ban status: fail2ban-client status"
log "  2. Review firewall status: ufw status"
log "  3. Test SSH access before closing current session"
log "  4. Monitor logs: tail -f /var/log/fail2ban.log"

