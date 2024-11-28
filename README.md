# Multi-Database PostgreSQL Docker Setup

This repository contains a Docker-based PostgreSQL setup that supports multiple databases with separate users and enhanced security features. The configuration automatically creates multiple databases upon startup, each with its dedicated user, proper permissions, and security measures.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Security Features](#security-features)
- [Configuration](#configuration)
- [Installation and Setup](#installation-and-setup)
- [Database Details](#database-details)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Prerequisites

- Docker Engine
- Docker Compose
- At least 256MB of available memory for PostgreSQL (configurable via POSTGRES_SHM_SIZE)
- Available port 5432 on your host machine (configurable via POSTGRES_PORT)
- OpenSSL for certificate generation

## Security Features

### Authentication
- SCRAM-SHA-256 password encryption (enforced by default)
- Secure password generation using OpenSSL
- SSL/TLS required for all connections
- Host-based authentication with peer authentication for local connections
- Rejection of non-secure connections

### Audit System
- Built-in audit logging (`postgres_audit_log` table)
- Timestamp-based logging with detailed action tracking
- Database modification logging
- User activity monitoring
- Security event tracking

### Access Control
- Strict user isolation per database
- Database-level permissions with owner-based access
- Public schema privileges revocation
- SSL certificate verification
- Secure file permissions management

## Configuration

### Environment Variables

Key environment variables that can be configured in `.env` file (see `.env.example` for all options):

```bash
# Core Configuration
POSTGRES_PASSWORD=StrongP@ssw0rd2024!
POSTGRES_USER=postgres
POSTGRES_MULTIPLE_DATABASES=db1:user1,db2:user2,db3:user3
POSTGRES_PORT=5432

# Security Configuration
POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=peer
POSTGRES_PASSWORD_ENCRYPTION=scram-sha-256

# SSL Configuration
SSL_COUNTRY=FR
SSL_STATE=IDF
SSL_LOCALITY=Paris
SSL_ORGANIZATION=Company
SSL_COMMON_NAME=localhost
SSL_CERT_DAYS=365
SSL_KEY_BITS=2048
```

### Security Configuration

- SSL certificates auto-generated during container build
- SCRAM-SHA-256 password encryption enforced
- Comprehensive audit logging enabled for all databases
- Secure connection settings in pg_hba.conf
- File permissions automatically managed for sensitive files

### Default Configuration

- PostgreSQL 17 (Alpine-based image)
- Three secure databases with isolated users
- UTF8 encoding
- Timezone: UTC
- Shared memory: 256MB (configurable)
- Health checks enabled

## Installation and Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd <repository-directory>
```

2. Create your environment file:
```bash
cp .env.example .env
# Edit .env with your desired configuration
```

3. Start the PostgreSQL container:
```bash
docker compose up -d
```

4. Verify the installation:
```bash
# List running containers
docker ps

# Check container health
docker compose ps

# Check database logs
docker compose logs postgres
```

## Database Details

### Connection Information

- Host: localhost (default)
- Port: 5432 (configurable)
- Available Databases: Configured via POSTGRES_MULTIPLE_DATABASES
- Credentials: Automatically generated and stored securely in container at `/var/lib/postgresql/data/pgdata/credentials.txt`

### Connecting to Databases

Using psql with SSL:
- [SSL Connection Steps](docs/SSL_CONNECTION_STEPS.md)

## Usage Examples

### 1. Docker Compose Configuration

```yaml
# Custom configuration in compose.yaml
services:
  postgres:
    environment:
      POSTGRES_MULTIPLE_DATABASES: "myapp:myuser,testdb:testuser"
      POSTGRES_PASSWORD: "YourSecurePassword"
```

### 2. Checking Audit Logs

```sql
-- View recent audit entries
SELECT * FROM postgres_audit_log 
WHERE action_time >= NOW() - INTERVAL '1 day'
ORDER BY action_time DESC;

-- View security events
SELECT * FROM postgres_audit_log 
WHERE action LIKE '%SECURITY%'
ORDER BY action_time DESC;
```

### 3. Framework Connection Guides

- [Symfony Connection Guide](docs/SYMFONY_CONNECTION.md)
- [Laravel Connection Guide](docs/LARAVEL_CONNECTION.md)
- [Node.js Connection Guide](docs/NODEJS_CONNECTION.md)

## Security Considerations

1. **Password Management**
   - Secure passwords automatically generated using OpenSSL
   - SCRAM-SHA-256 encryption enforced
   - Credentials stored securely with proper permissions
   - Regular password rotation recommended

2. **Network Security**
   - SSL/TLS enforced for all connections
   - Custom SSL certificate configuration supported
   - Non-SSL connections rejected by default
   - Health checks ensure service availability

3. **Access Control**
   - Database-level user isolation
   - Public schema access restricted
   - Owner-based permissions model
   - Comprehensive audit logging

4. **Container Security**
   - Alpine-based minimal image
   - Non-root user execution
   - Secure file permissions
   - Volume management for data persistence

## Maintenance

### Health Monitoring

```bash
# Check container health
docker compose ps

# View container logs
docker compose logs postgres

# Monitor PostgreSQL processes
docker compose exec postgres ps aux
```

### Backup and Restore

```bash
# Secure backup with SSL
docker compose exec postgres pg_dump \
  -h localhost \
  -U user1 \
  -d db1 \
  --format=custom \
  -f /var/lib/postgresql/data/backup.dump

# Restore with SSL
docker compose exec postgres pg_restore \
  -h localhost \
  -U user1 \
  -d db1 \
  /var/lib/postgresql/data/backup.dump
```

### Security Best Practices

1. Regularly rotate passwords and SSL certificates
2. Monitor audit logs for suspicious activity
3. Keep PostgreSQL and container images updated
4. Review SSL certificate expiration dates
5. Perform regular security audits
6. Monitor failed login attempts
7. Review user permissions periodically
8. Maintain secure backups
9. Configure appropriate resource limits
10. Use environment-specific SSL certificates in production
