# Modern Deployment System - Quick Start Guide

## Overview

This repository now includes a modernized deployment system with:
- Environment separation (dev, staging, production)
- Automated CI/CD pipelines
- Infrastructure as code
- Automated rollback capabilities
- Comprehensive health checks
- Secrets management

## Quick Start

### 1. Local Development

```bash
# Clone repository
git clone <repo-url>
cd ai-ia-backend

# Set up development environment
cp config/dev/project.toml.example config/dev/project.toml
# Edit config/dev/project.toml with your values

# Start development environment
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up
```

### 2. Deploy to Staging

```bash
# Push to staging branch
git checkout staging
git push origin staging

# GitHub Actions will automatically deploy to staging
```

### 3. Deploy to Production

```bash
# Merge staging to main
git checkout main
git merge staging
git push origin main

# GitHub Actions will deploy to production (requires approval)
```

## Directory Structure

```
.
├── .github/
│   └── workflows/          # CI/CD pipeline definitions
├── config/
│   ├── dev/                # Development configuration
│   ├── staging/            # Staging configuration
│   └── prod/               # Production configuration
├── docker/
│   ├── nginx/              # Nginx configuration
│   ├── postgres/           # PostgreSQL configuration
│   └── redis/              # Redis configuration
├── docs/                   # Documentation
├── scripts/                # Deployment scripts
├── docker-compose.base.yml # Base Docker Compose config
├── docker-compose.dev.yml   # Development environment
├── docker-compose.staging.yml # Staging environment
└── docker-compose.prod.yml  # Production environment
```

## Key Files

### Configuration Files
- `config/{env}/project.toml.example` - Configuration templates
- `config/{env}/project.toml` - Actual configuration (not in git)

### Deployment Scripts
- `scripts/deploy-modern.sh` - Modern deployment script
- `scripts/health-check.sh` - Health check script
- `scripts/rollback.sh` - Rollback script

### CI/CD Workflows
- `.github/workflows/ci.yml` - Continuous Integration
- `.github/workflows/cd-staging.yml` - Staging deployment
- `.github/workflows/cd-production.yml` - Production deployment
- `.github/workflows/rollback.yml` - Rollback automation

## Environment Setup

### Development
```bash
ENVIRONMENT=dev docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up
```

### Staging
```bash
ENVIRONMENT=staging docker compose -f docker-compose.base.yml -f docker-compose.staging.yml up
```

### Production
```bash
ENVIRONMENT=production docker compose -f docker-compose.base.yml -f docker-compose.prod.yml up
```

## Git Workflow

### Branching Strategy
- `main` - Production (protected)
- `staging` - Staging environment
- `develop` - Integration branch
- `feature/*` - Feature branches

### Workflow
1. Create feature branch from `develop`
2. Make changes and commit
3. Create PR to `develop`
4. After review, merge to `develop`
5. Create PR from `develop` to `staging`
6. Deploy to staging
7. Create PR from `staging` to `main`
8. Deploy to production (with approval)

## Secrets Management

### Setting Up Secrets

1. **GitHub Secrets** (for CI/CD):
   - Go to repository Settings → Secrets
   - Add required secrets

2. **Server Environment Variables**:
   - Create `.env` file on server
   - Add environment variables
   - Never commit `.env` to git

See `docs/SECRETS_MANAGEMENT.md` for details.

## Health Checks

### Manual Health Check
```bash
bash scripts/health-check.sh --environment production --comprehensive
```

### Automated Health Checks
- Run automatically after deployment
- Integrated into CI/CD pipeline
- Can trigger rollback on failure

## Rollback

### Manual Rollback
```bash
bash scripts/rollback.sh --environment production
```

### Automated Rollback
- Triggered via GitHub Actions
- Can rollback to specific backup
- Verifies health after rollback

## Monitoring

### Health Endpoints
- Application: `http://localhost:5000/health`
- Database: Check via `pg_isready`
- Redis: Check via `redis-cli ping`

### Logs
- Application logs: `docker compose logs app`
- All logs: `docker compose logs`
- Deployment logs: `logs/deployment_*.log`

## Troubleshooting

### Services Not Starting
1. Check logs: `docker compose logs`
2. Verify configuration
3. Check resource availability
4. Review health checks

### Deployment Failures
1. Check GitHub Actions logs
2. Review deployment logs
3. Verify secrets are set
4. Check server connectivity

### Health Check Failures
1. Check container status
2. Verify service connectivity
3. Review application logs
4. Check resource usage

## Documentation

- **Architecture**: `docs/DEPLOYMENT_ARCHITECTURE.md`
- **Analysis**: `docs/DEPLOYMENT_ANALYSIS.md`
- **Secrets**: `docs/SECRETS_MANAGEMENT.md`
- **Migration**: `docs/MIGRATION_GUIDE.md`
- **Validation**: `docs/VALIDATION_PROCEDURES.md`

## Support

For issues or questions:
1. Check documentation
2. Review GitHub Issues
3. Contact team lead
4. Escalate if needed

## Best Practices

1. **Always test in staging first**
2. **Use feature branches for changes**
3. **Review PRs before merging**
4. **Monitor deployments**
5. **Keep secrets secure**
6. **Document changes**
7. **Test rollback procedures**

## Next Steps

1. Review architecture documentation
2. Set up GitHub Secrets
3. Configure environments
4. Test deployment process
5. Train team on new workflow

