# Use the specified version from .env
ARG POSTGRES_VERSION=17-alpine
FROM postgres:${POSTGRES_VERSION}

# Install additional packages specified in .env
RUN apk add --no-cache \
    bash \
    postgresql-client \
    netcat-openbsd \
    procps \
    bind-tools \
    iputils \
    openssl

# Create necessary directories with proper permissions
RUN mkdir -p /docker-entrypoint-initdb.d && \
    mkdir -p ${POSTGRESQL_RUN_DIR:-/var/run/postgresql} && \
    mkdir -p ${POSTGRESQL_DATA_DIR:-/var/lib/postgresql/data}/pgdata && \
    mkdir -p ${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}

# Copy configuration files and set permissions
COPY ./docker/pg_hba.conf /docker-entrypoint-initdb.d/
COPY ./docker/docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod 755 /usr/local/bin/custom-entrypoint.sh

# Generate SSL certificates with configurable parameters
ARG SSL_COUNTRY=FR
ARG SSL_STATE=IDF
ARG SSL_LOCALITY=Paris
ARG SSL_ORGANIZATION=Company
ARG SSL_COMMON_NAME=localhost
ARG SSL_CERT_DAYS=365
ARG SSL_KEY_BITS=2048

RUN openssl req -x509 -nodes \
    -days ${SSL_CERT_DAYS} \
    -newkey rsa:${SSL_KEY_BITS} \
    -keyout ${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}/server.key \
    -out ${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}/server.crt \
    -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORGANIZATION}/CN=${SSL_COMMON_NAME}" && \
    chmod 600 ${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}/server.key && \
    chmod 644 ${POSTGRESQL_SSL_DIR:-/var/lib/postgresql/ssl}/server.crt

# Set proper permissions for PostgreSQL directories
RUN chown -R postgres:postgres /var/run/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chown -R postgres:postgres /docker-entrypoint-initdb.d && \
    chmod 700 ${POSTGRESQL_DATA_DIR:-/var/lib/postgresql/data}/pgdata && \
    chmod 755 /docker-entrypoint-initdb.d

# Switch to postgres user for security
USER postgres

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["postgres"]
