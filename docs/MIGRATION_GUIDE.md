# Migration Guide: Old to New Deployment System

## Overview

This guide provides step-by-step instructions for migrating from the current deployment system to the new, modernized deployment architecture.

## Pre-Migration Checklist

### 1. Backup Current System
- [ ] Create full database backup
- [ ] Backup configuration files
- [ ] Backup SSL certificates
- [ ] Document current environment variables
- [ ] Note current Git commit hash

### 2. Review New Architecture
- [ ] Read `DEPLOYMENT_ARCHITECTURE.md`
- [ ] Understand new branching strategy
- [ ] Review environment separation
- [ ] Understand secrets management

### 3. Prepare Team
- [ ] Train team on new Git workflow
- [ ] Review new CI/CD pipeline
- [ ] Understand rollback procedures
- [ ] Set up access to GitHub Secrets

## Migration Phases

### Phase 1: Foundation Setup (Week 1)

#### Step 1.1: Create New Branch Structure

```bash
# Create new branches
git checkout -b develop
git push -u origin develop

git checkout -b staging
git push -u origin staging

# Keep main as production
git checkout main
```

#### Step 1.2: Set Up GitHub Secrets

1. Go to repository Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `DEPLOY_KEY`: SSH private key for server access
   - `DEPLOY_HOST`: Server hostname/IP
   - `DEPLOY_USER`: SSH username
   - `DEPLOY_PATH`: Deployment directory (e.g., `/app/production`)
   - `PROD_DB_BACKUP_KEY`: Database backup encryption key

#### Step 1.3: Create Environment Configuration Directories

```bash
# Create environment config directories
mkdir -p config/dev config/staging config/prod

# Copy example configs
cp config/project.toml config/prod/project.toml.example
# Update with production values (using env vars for secrets)
```

#### Step 1.4: Update .gitignore

Ensure `.gitignore` includes:
```
config/*/project.toml
.env
*.env
```

### Phase 2: Infrastructure as Code (Week 1-2)

#### Step 2.1: Deploy New Docker Compose Files

```bash
# Test new compose structure locally
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml config

# On server, create staging environment
mkdir -p /app/staging
cd /app/staging
git clone -b staging <repo-url> .
```

#### Step 2.2: Test Staging Environment

1. Deploy to staging using new pipeline
2. Verify all services start correctly
3. Run health checks
4. Test application functionality

#### Step 2.3: Update Production (Gradual)

1. Keep old deployment running
2. Set up new production structure in parallel
3. Test new production deployment
4. Switch traffic when ready

### Phase 3: CI/CD Pipeline Migration (Week 2)

#### Step 3.1: Enable New Workflows

1. Merge new workflow files to `main`
2. Test CI pipeline on feature branch
3. Test staging deployment
4. Test production deployment (with manual approval)

#### Step 3.2: Configure Branch Protection

1. Go to repository Settings → Branches
2. Add rule for `main`:
   - Require pull request reviews (2 approvals)
   - Require status checks to pass
   - Require branches to be up to date
   - Do not allow force pushes

3. Add rule for `staging`:
   - Require pull request reviews (1 approval)
   - Require status checks to pass

#### Step 3.3: Test Deployment Pipeline

1. Create feature branch
2. Make changes
3. Create PR to `develop`
4. Verify CI passes
5. Merge to `develop`
6. Create PR from `develop` to `staging`
7. Deploy to staging
8. Verify staging deployment
9. Create PR from `staging` to `main`
10. Deploy to production (with approval)

### Phase 4: Secrets Migration (Week 2-3)

#### Step 4.1: Audit Current Secrets

1. List all secrets in current `config/project.toml`
2. Identify which need to be moved to environment variables
3. Document current values securely

#### Step 4.2: Migrate to Environment Variables

1. Create `.env` file on server (not in git)
2. Move secrets from config to environment variables
3. Update configuration files to use env vars
4. Test with new configuration

#### Step 4.3: Update CI/CD Secrets

1. Add all required secrets to GitHub
2. Update workflow files to use secrets
3. Test deployment with new secrets

### Phase 5: Monitoring and Health Checks (Week 3)

#### Step 5.1: Deploy Health Check Script

1. Copy `scripts/health-check.sh` to server
2. Make executable: `chmod +x scripts/health-check.sh`
3. Test health checks manually
4. Integrate into CI/CD pipeline

#### Step 5.2: Set Up Monitoring

1. Configure application health endpoints
2. Set up log aggregation (if applicable)
3. Configure alerts
4. Test alerting

### Phase 6: Rollback Procedures (Week 3)

#### Step 6.1: Test Rollback Script

1. Deploy test change to staging
2. Test rollback procedure
3. Verify rollback works correctly
4. Document any issues

#### Step 6.2: Create Rollback Documentation

1. Document rollback procedures
2. Create runbooks for common scenarios
3. Train team on rollback procedures

## Post-Migration Validation

### Functional Validation

- [ ] All services start correctly
- [ ] Application is accessible
- [ ] Database connections work
- [ ] Redis cache works
- [ ] Search service works
- [ ] SSL certificates valid
- [ ] Health checks pass

### Process Validation

- [ ] CI pipeline runs on all branches
- [ ] Staging deployment works
- [ ] Production deployment works
- [ ] Rollback procedure works
- [ ] Health checks integrated
- [ ] Monitoring active

### Security Validation

- [ ] No secrets in version control
- [ ] Environment variables set correctly
- [ ] GitHub Secrets configured
- [ ] Access controls in place
- [ ] Audit logging enabled

## Rollback Plan (If Migration Fails)

### Immediate Rollback

1. Revert to previous Git commit
2. Use old deployment script
3. Restore from backup if needed
4. Verify services are running

### Partial Rollback

1. Keep new infrastructure
2. Revert to old deployment process
3. Gradually migrate components

## Common Issues and Solutions

### Issue: Docker Compose File Not Found

**Solution**: Ensure you're using the correct compose files:
```bash
docker compose -f docker-compose.base.yml -f docker-compose.prod.yml up
```

### Issue: Environment Variables Not Loading

**Solution**: Check `.env` file exists and is loaded:
```bash
set -a
source .env
set +a
```

### Issue: Health Checks Failing

**Solution**: 
1. Check container logs
2. Verify health check endpoints
3. Check network connectivity
4. Review health check script

### Issue: Secrets Not Available in CI/CD

**Solution**:
1. Verify GitHub Secrets are set
2. Check secret names match workflow
3. Verify environment protection rules

## Timeline

- **Week 1**: Foundation setup, infrastructure as code
- **Week 2**: CI/CD pipeline, secrets migration
- **Week 3**: Monitoring, rollback, validation
- **Week 4**: Documentation, training, final validation

## Success Criteria

- [ ] All environments (dev, staging, prod) operational
- [ ] CI/CD pipeline fully functional
- [ ] Secrets properly managed
- [ ] Health checks passing
- [ ] Team trained on new processes
- [ ] Documentation complete
- [ ] Zero downtime during migration
- [ ] All services healthy

## Support and Resources

- Architecture Documentation: `docs/DEPLOYMENT_ARCHITECTURE.md`
- Secrets Management: `docs/SECRETS_MANAGEMENT.md`
- Analysis: `docs/DEPLOYMENT_ANALYSIS.md`
- GitHub Issues: For reporting problems
- Team Chat: For real-time support

## Next Steps After Migration

1. Monitor system for 1 week
2. Gather team feedback
3. Address any issues
4. Optimize based on learnings
5. Plan Phase 2 improvements (blue-green, auto-scaling, etc.)

