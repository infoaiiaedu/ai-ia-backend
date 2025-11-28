# Validation and Testing Procedures

## Overview

This document outlines the validation and testing procedures for the modernized deployment system. These procedures ensure reliability, security, and correctness of deployments.

## Pre-Deployment Validation

### 1. Code Quality Checks

#### Linting
```bash
# Run linting
black --check code/
isort --check-only code/
flake8 code/
```

#### Type Checking
```bash
# Run type checking
mypy code/ --ignore-missing-imports
```

### 2. Configuration Validation

#### Validate TOML Files
```bash
# Validate configuration syntax
python -c "import tomli; tomli.load(open('config/prod/project.toml', 'rb'))"
```

#### Check for Secrets
```bash
# Ensure no secrets in config files
grep -r "password\|secret\|key" config/*/project.toml | grep -v "example\|${"
```

### 3. Docker Validation

#### Validate Compose Files
```bash
# Validate compose files
docker compose -f docker-compose.base.yml -f docker-compose.prod.yml config
```

#### Build Test
```bash
# Test image build
docker compose -f docker-compose.base.yml -f docker-compose.prod.yml build
```

## Deployment Validation

### 1. Service Health Checks

#### Container Status
```bash
# Check all containers are running
docker compose ps

# Check specific service
docker compose ps app
```

#### Health Endpoints
```bash
# Application health
curl -f http://localhost:5000/health

# Database health
docker compose exec psql pg_isready -U postgres

# Redis health
docker compose exec redis redis-cli ping
```

### 2. Functional Validation

#### Application Access
```bash
# Test main endpoint
curl -I http://localhost:5000/

# Test API endpoint
curl -I http://localhost:5000/api/
```

#### Database Connectivity
```bash
# Test database connection
docker compose exec app python manage.py dbshell
```

#### Static Files
```bash
# Verify static files collected
ls -la storage/static/
```

### 3. Performance Validation

#### Response Time
```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:5000/
```

#### Resource Usage
```bash
# Check container resource usage
docker stats --no-stream
```

## Post-Deployment Validation

### 1. Automated Health Checks

Run comprehensive health check:
```bash
bash scripts/health-check.sh --environment production --comprehensive
```

### 2. Smoke Tests

#### Basic Functionality
- [ ] Homepage loads
- [ ] API endpoints respond
- [ ] Database queries work
- [ ] Static files serve correctly
- [ ] SSL certificate valid

#### User Flows
- [ ] User registration works
- [ ] User login works
- [ ] Payment processing works (test mode)
- [ ] Search functionality works

### 3. Integration Tests

Run integration test suite:
```bash
cd code
python manage.py test apps.core apps.user apps.payments --verbosity=2
```

## Security Validation

### 1. Secrets Audit

- [ ] No secrets in version control
- [ ] Environment variables set correctly
- [ ] GitHub Secrets configured
- [ ] SSL certificates valid
- [ ] Database passwords secure

### 2. Security Scanning

#### Dependency Scanning
```bash
# Run safety check
safety check --file code/requirements.txt
```

#### Code Scanning
```bash
# Run bandit
bandit -r code/
```

#### Container Scanning
```bash
# Run Trivy scan
trivy image ai-ia-backend:production
```

### 3. Access Control

- [ ] SSH access restricted
- [ ] Database access restricted
- [ ] API endpoints protected
- [ ] Admin interface secured

## Performance Validation

### 1. Load Testing

#### Basic Load Test
```bash
# Simple load test with Apache Bench
ab -n 1000 -c 10 http://localhost:5000/
```

#### Response Time Monitoring
- Average response time < 200ms
- 95th percentile < 500ms
- 99th percentile < 1000ms

### 2. Resource Monitoring

- CPU usage < 80%
- Memory usage < 80%
- Disk usage < 80%
- Network bandwidth adequate

## Rollback Validation

### 1. Rollback Procedure Test

1. Deploy test change
2. Verify deployment
3. Execute rollback
4. Verify rollback successful
5. Confirm services healthy

### 2. Backup Validation

- [ ] Backups created before deployment
- [ ] Database backup valid
- [ ] Configuration backup valid
- [ ] Backup restoration tested

## Continuous Validation

### 1. CI/CD Pipeline

- [ ] All tests pass
- [ ] Security scans pass
- [ ] Build successful
- [ ] Deployment successful
- [ ] Health checks pass

### 2. Monitoring

- [ ] Application logs monitored
- [ ] Error rates tracked
- [ ] Performance metrics collected
- [ ] Alerts configured

## Validation Checklist

### Pre-Deployment
- [ ] Code quality checks pass
- [ ] Configuration validated
- [ ] Docker images build successfully
- [ ] Tests pass
- [ ] Security scans pass

### During Deployment
- [ ] Services start correctly
- [ ] Migrations apply successfully
- [ ] Static files collected
- [ ] Health checks pass

### Post-Deployment
- [ ] All services healthy
- [ ] Application accessible
- [ ] Functional tests pass
- [ ] Performance acceptable
- [ ] Security validated

## Failure Scenarios

### Deployment Failure

1. Check deployment logs
2. Verify service status
3. Check resource availability
4. Review error messages
5. Execute rollback if needed

### Health Check Failure

1. Check container logs
2. Verify network connectivity
3. Check service dependencies
4. Review configuration
5. Restart services if needed

### Performance Degradation

1. Check resource usage
2. Review application logs
3. Check database performance
4. Verify cache functionality
5. Scale resources if needed

## Validation Tools

### Automated Tools
- GitHub Actions (CI/CD)
- Health check script
- Security scanners
- Performance monitors

### Manual Procedures
- Smoke testing
- User acceptance testing
- Security audits
- Performance reviews

## Reporting

### Validation Reports

After each deployment, generate:
1. Deployment summary
2. Health check results
3. Test results
4. Performance metrics
5. Security scan results

### Metrics Tracking

Track over time:
- Deployment success rate
- Mean time to recovery (MTTR)
- Error rates
- Response times
- Resource usage

## Continuous Improvement

### Regular Reviews
- Weekly deployment review
- Monthly performance review
- Quarterly security audit
- Annual architecture review

### Feedback Loop
- Collect team feedback
- Monitor error patterns
- Track performance trends
- Update procedures

