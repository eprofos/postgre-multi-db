# PostgreSQL SSL Connection Steps

This document outlines the exact steps needed to connect to PostgreSQL with SSL verification.

## 1. Copy SSL Certificate from Container
```bash
# Create directory for the certificate
mkdir -p /var/lib/postgresql/.postgresql

# Copy the server certificate from container
docker compose cp postgres:/var/lib/postgresql/ssl/server.crt ./root.crt

# Copy certificate to PostgreSQL directory in container
docker compose cp root.crt postgres:/var/lib/postgresql/.postgresql/root.crt
```

## 2. Test SSL Connection
Use this command to verify SSL connection with full verification:

```bash
docker compose exec postgres psql "host=localhost port=5432 dbname=db1 user=user1 password=test123 sslmode=verify-full sslcert=/var/lib/postgresql/ssl/server.crt sslkey=/var/lib/postgresql/ssl/server.key sslrootcert=/var/lib/postgresql/.postgresql/root.crt" -c "\conninfo"
```

Expected successful output:
```
You are connected to database "db1" as user "user1" on host "localhost" (address "127.0.0.1") at port "5432".
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
```

## 3. Connection Parameters Explained

- `host=localhost`: Database host
- `port=5432`: PostgreSQL port
- `dbname=db1`: Database name
- `user=user1`: Username
- `password=test123`: User password
- `sslmode=verify-full`: Require SSL and verify certificate
- `sslcert=/var/lib/postgresql/ssl/server.crt`: Server certificate path
- `sslkey=/var/lib/postgresql/ssl/server.key`: Server key path
- `sslrootcert=/var/lib/postgresql/.postgresql/root.crt`: Root certificate path

## 4. Troubleshooting

If you see this error:
```
psql: error: connection to server at "localhost" (127.0.0.1) port 5432 failed: root certificate file "/var/lib/postgresql/.postgresql/root.crt" does not exist
```

Make sure you've completed steps 1-2 to copy the certificate files correctly.
