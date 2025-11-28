# Secrets Management Guide

## Overview

This document describes the secrets management strategy for the AI-IA backend deployment system. All sensitive information must be managed securely and never committed to version control.

## Principles

1. **Never commit secrets** to version control
2. **Use environment variables** for runtime secrets
3. **Use GitHub Secrets** for CI/CD secrets
4. **Rotate secrets regularly** (quarterly minimum)
5. **Limit access** to secrets (principle of least privilege)

## Secrets Categories

### 1. Application Secrets

#### Django Secret Key
- **Location**: Environment variable `DJANGO_SECRET_KEY`
- **Usage**: Django cryptographic signing
- **Rotation**: Quarterly or after security incident
- **Generation**: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`

#### Database Credentials
- **Location**: Environment variables `POSTGRES_PASSWORD`, `DB_USER`, etc.
- **Usage**: Database connection
- **Rotation**: Quarterly
- **Storage**: GitHub Secrets for CI/CD, environment variables on server

#### Redis Connection
- **Location**: Configuration file (non-sensitive) or environment variable
- **Usage**: Cache and session storage
- **Rotation**: Not required (internal network)

### 2. CI/CD Secrets

#### GitHub Secrets Required
```
DEPLOY_KEY          # SSH private key for server access
DEPLOY_HOST         # Server hostname/IP
DEPLOY_USER         # SSH username
DEPLOY_PATH         # Deployment directory path
PROD_DB_BACKUP_KEY  # Database backup encryption key
```

#### Setting GitHub Secrets
1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret with appropriate value
4. Restrict access if using environments

### 3. External Service Secrets

#### BOG Payment Gateway
- **Location**: Environment variables or secure config
- **Variables**: `BOG_CLIENT_ID`, `BOG_CLIENT_SECRET`, `BOG_MERCHANT_ID`
- **Rotation**: As per BOG requirements

#### SSL Certificates
- **Location**: `docker/certbot/conf/`
- **Management**: Automated via Certbot
- **Rotation**: Automated (Let's Encrypt)

## Implementation

### Development Environment

1. Copy `config/dev/project.toml.example` to `config/dev/project.toml`
2. Update with local values (non-sensitive)
3. Use environment variables for sensitive values:
   ```bash
   export DJANGO_SECRET_KEY="your-dev-key"
   export POSTGRES_PASSWORD="dev-password"
   ```

### Staging Environment

1. Copy `config/staging/project.toml.example` to `config/staging/project.toml`
2. Use environment variables for all sensitive values
3. Set environment variables on staging server
4. Configure in CI/CD pipeline

### Production Environment

1. Copy `config/prod/project.toml.example` to `config/prod/project.toml`
2. **ALL** sensitive values must use environment variables
3. Set environment variables securely on production server
4. Use GitHub Secrets for CI/CD
5. Never log or expose secrets

## Environment Variable Setup

### On Server (Production/Staging)

Create `.env` file (not in version control):
```bash
# .env file (DO NOT COMMIT)
DJANGO_SECRET_KEY=your-production-secret-key
POSTGRES_PASSWORD=your-secure-password
BOG_CLIENT_SECRET=your-bog-secret
```

Load in deployment script:
```bash
set -a
source .env
set +a
```

### In Docker Compose

Use environment variables:
```yaml
environment:
  DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

## Secrets Rotation Procedure

### 1. Django Secret Key Rotation

```bash
# Generate new key
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Update environment variable
export DJANGO_SECRET_KEY="new-key"

# Restart services
docker compose restart app
```

**Note**: Existing sessions will be invalidated. Users will need to log in again.

### 2. Database Password Rotation

```bash
# Update password in database
docker compose exec psql psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'new-password';"

# Update environment variable
export POSTGRES_PASSWORD="new-password"

# Update docker-compose environment
# Restart database service
docker compose restart psql
```

### 3. GitHub Secrets Rotation

1. Generate new secret value
2. Update GitHub Secret
3. Update server environment variable
4. Test deployment
5. Remove old secret

## Security Best Practices

### 1. Access Control
- Limit who can view/modify secrets
- Use GitHub environments for production secrets
- Require approvals for production deployments

### 2. Audit Logging
- Log all secret access (GitHub Actions logs)
- Monitor for unauthorized access
- Regular security audits

### 3. Encryption
- Secrets encrypted at rest (GitHub Secrets)
- TLS for secrets in transit
- Encrypted backups

### 4. Backup Security
- Encrypt database backups
- Secure backup storage
- Limit backup access

## Emergency Procedures

### If Secrets Are Compromised

1. **Immediately rotate all compromised secrets**
2. **Revoke access** if credentials compromised
3. **Review audit logs** for unauthorized access
4. **Notify security team**
5. **Update incident log**

### Secret Recovery

1. Check GitHub Secrets (for CI/CD)
2. Check server environment variables
3. Check secure backup storage
4. Regenerate if necessary

## Compliance

- Follow organization security policies
- Comply with data protection regulations
- Regular security reviews
- Document all secret changes

## Tools and Resources

- **GitHub Secrets**: CI/CD secret storage
- **Environment Variables**: Runtime secret storage
- **Certbot**: SSL certificate management
- **Django Secret Key Generator**: Built-in utility

## Checklist

- [ ] All secrets use environment variables
- [ ] No secrets in version control
- [ ] GitHub Secrets configured
- [ ] Server environment variables set
- [ ] Secrets rotation schedule established
- [ ] Access controls configured
- [ ] Backup encryption enabled
- [ ] Audit logging enabled

