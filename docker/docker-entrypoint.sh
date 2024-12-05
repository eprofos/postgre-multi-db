#!/bin/bash
set -e

# Enhanced logging function with timestamps
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [PostgreSQL Entrypoint] $1" >&2
}

# Debug function to print system information
debug_system_info() {
    log "--- System Information ---"
    log "Hostname: $(hostname)"
    log "PostgreSQL Version: $(postgres --version)"
    log "SSL Directory: ${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}"
    log "Data Directory: ${PGDATA}"
    log "Current User: $(whoami)"
    log "------------------------"
}

# Function to generate secure password
generate_secure_password() {
    openssl rand -base64 32
}

# Function to verify SSL configuration
verify_ssl_config() {
    local ssl_dir="${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}"
    local cert_file="${SSL_CERT_FILE:-$ssl_dir/server.crt}"
    local key_file="${SSL_KEY_FILE:-$ssl_dir/server.key}"

    log "Verifying SSL configuration"
    
    # Check SSL files existence and permissions
    if [[ ! -f "$cert_file" ]] || [[ ! -f "$key_file" ]]; then
        log "Generating new SSL certificate and key"
        openssl req -x509 -nodes \
            -days "${SSL_CERT_DAYS:-365}" \
            -newkey rsa:"${SSL_KEY_BITS:-2048}" \
            -keyout "$key_file" \
            -out "$cert_file" \
            -subj "/C=${SSL_COUNTRY:-FR}/ST=${SSL_STATE:-IDF}/L=${SSL_LOCALITY:-Paris}/O=${SSL_ORGANIZATION:-Company}/CN=${SSL_COMMON_NAME:-localhost}"
    fi

    # Set correct permissions
    chmod "${SSL_KEY_MODE:-600}" "$key_file"
    chmod "${SSL_CERT_MODE:-644}" "$cert_file"
    log "SSL configuration verified successfully"
    
    # Copy certificate to .postgresql directory
    cp "$cert_file" /var/lib/postgresql/.postgresql/root.crt
    chmod 644 /var/lib/postgresql/.postgresql/root.crt
    log "SSL certificate copied to .postgresql directory"
}

# Function to setup initial configuration
setup_configuration() {
    log "Setting up initial PostgreSQL configuration"
    
    # Create necessary directories with proper permissions
    if [[ ! -d "$PGDATA" ]]; then
        log "Creating PGDATA directory: $PGDATA"
        mkdir -p "$PGDATA"
        chmod "${PGDATA_DIR_MODE:-700}" "$PGDATA"
    fi

    # Initialize database if needed
    if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
        log "Initializing PostgreSQL database"
        initdb ${POSTGRES_INITDB_ARGS} \
               --username="$POSTGRES_USER" \
               --pwfile=<(echo "$POSTGRES_PASSWORD") \
               -D "$PGDATA"

        # Configure postgresql.conf
        cat >> "$PGDATA/postgresql.conf" <<EOF
# Security settings
ssl = on
ssl_cert_file = '${SSL_CERT_FILE:-/var/lib/postgresql/ssl/server.crt}'
ssl_key_file = '${SSL_KEY_FILE:-/var/lib/postgresql/ssl/server.key}'
password_encryption = '${POSTGRES_PASSWORD_ENCRYPTION:-scram-sha-256}'
EOF
    fi

    # Copy pg_hba.conf if it exists
    if [[ -f "${DOCKER_ENTRYPOINT_DIR:-/docker-entrypoint-initdb.d}/pg_hba.conf" ]]; then
        log "Copying pg_hba.conf to data directory"
        cp "${DOCKER_ENTRYPOINT_DIR:-/docker-entrypoint-initdb.d}/pg_hba.conf" "$PGDATA/"
        chmod 600 "$PGDATA/pg_hba.conf"
    fi
}

# Function to create databases with extensive error handling
create_databases() {
    log "Starting database creation process"
    
    # First, secure the postgres user
    log "Securing postgres superuser"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';
        ALTER SYSTEM SET password_encryption = '${POSTGRES_PASSWORD_ENCRYPTION:-scram-sha-256}';

        -- Create audit log table
        CREATE TABLE IF NOT EXISTS postgres_audit_log (
            id SERIAL PRIMARY KEY,
            action_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            action VARCHAR(50),
            object_type VARCHAR(50),
            object_name VARCHAR(100),
            details TEXT
        );
EOSQL

    # Process multiple databases
    IFS=',' read -ra DB_ARRAY <<< "$POSTGRES_MULTIPLE_DATABASES"
    for db in "${DB_ARRAY[@]}"; do
        database=$(echo "$db" | cut -d: -f1)
        owner=$(echo "$db" | cut -d: -f2)
        
        # Generate a secure password
        user_password=$(generate_secure_password)
        
        log "Creating database '$database' with owner '$owner'"
        
        # Create or update user with password
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
            DO \$\$
            BEGIN
                IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$owner') THEN
                    CREATE USER $owner WITH PASSWORD '$user_password';
                ELSE
                    ALTER USER $owner WITH PASSWORD '$user_password';
                END IF;
            END
            \$\$;

            INSERT INTO postgres_audit_log (action, object_type, object_name, details)
            VALUES ('CREATE/UPDATE', 'USER', '$owner', 'User created/updated with secure password');
EOSQL

        # Create database if it doesn't exist
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
            SELECT 'CREATE DATABASE $database'
            WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
EOSQL

        # Setup database permissions and audit
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" <<-EOSQL
            CREATE TABLE IF NOT EXISTS postgres_audit_log (
                id SERIAL PRIMARY KEY,
                action_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                action VARCHAR(50),
                object_type VARCHAR(50),
                object_name VARCHAR(100),
                details TEXT
            );

            GRANT ALL PRIVILEGES ON DATABASE $database TO $owner;
            ALTER DATABASE $database OWNER TO $owner;
            REVOKE CREATE ON SCHEMA public FROM PUBLIC;
            REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
            GRANT ALL ON SCHEMA public TO $owner;
            
            INSERT INTO postgres_audit_log (action, object_type, object_name, details)
            VALUES ('SECURE', 'DATABASE', '$database', 'Database secured and configured');
EOSQL

        # Save credentials securely
        {
            echo "Database: $database"
            echo "User: $owner"
            echo "Password: $user_password"
            echo "----------------------------------------"
        } >> "$PGDATA/credentials.txt"
    done
    
    chmod 600 "$PGDATA/credentials.txt"
    log "Database creation completed successfully"
}

# Main entrypoint logic
main() {
    log "Starting PostgreSQL initialization with enhanced security"
    debug_system_info
    
    # Verify SSL configuration
    verify_ssl_config
    
    # Setup initial configuration
    setup_configuration
    
    # Start PostgreSQL temporarily
    pg_ctl -D "$PGDATA" -o "-c listen_addresses='localhost'" start
    
    # Wait for PostgreSQL to start
    until pg_isready -U "$POSTGRES_USER" -h localhost; do
        log "Waiting for PostgreSQL to start..."
        sleep 1
    done
    
    # Create databases if specified
    if [[ -n "$POSTGRES_MULTIPLE_DATABASES" ]]; then
        create_databases
    fi
    
    # Stop PostgreSQL
    pg_ctl -D "$PGDATA" stop
    
    # Start PostgreSQL in foreground with custom configuration
    log "Starting PostgreSQL with production configuration"
    exec postgres -D "$PGDATA" \
        -c ssl=on \
        -c ssl_cert_file="${SSL_CERT_FILE:-/var/lib/postgresql/ssl/server.crt}" \
        -c ssl_key_file="${SSL_KEY_FILE:-/var/lib/postgresql/ssl/server.key}" \
        -c password_encryption="${POSTGRES_PASSWORD_ENCRYPTION:-scram-sha-256}"
}

# Run main entrypoint logic
main "$@"
