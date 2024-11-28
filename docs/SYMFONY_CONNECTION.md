# Connecting Symfony Application to PostgreSQL with SSL

This guide details how to connect your Symfony 7 application to the PostgreSQL database with SSL verification.

## 1. Copy SSL Certificate
First, copy the SSL certificate from the PostgreSQL container to your Symfony project:

```bash
# Create SSL directory in your Symfony project
mkdir -p config/ssl

# Copy the certificate from PostgreSQL container
docker compose cp postgres:/var/lib/postgresql/ssl/server.crt config/ssl/root.crt
```

## 2. Configure Environment Variables
Add these variables to your `.env` file:

```env
# PostgreSQL Connection
DATABASE_URL="postgresql://user1:your_password@localhost:5432/db1?serverVersion=17&charset=utf8&sslmode=verify-full&sslcert=%kernel.project_dir%/config/ssl/root.crt"

# Optional: Additional Database Settings
DATABASE_SSL_MODE=verify-full
DATABASE_SSL_CERT=%kernel.project_dir%/config/ssl/root.crt
DATABASE_VERSION=17
```

## 3. Configure Doctrine
Update your `config/packages/doctrine.yaml`:

```yaml
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%'
        driver: 'pdo_pgsql'
        server_version: '%env(DATABASE_VERSION)%'
        charset: utf8
        options:
            sslmode: '%env(DATABASE_SSL_MODE)%'
            sslcert: '%env(DATABASE_SSL_CERT)%'
    orm:
        auto_generate_proxy_classes: true
        enable_lazy_ghost_objects: true
        report_fields_where_declared: true
        validate_xml_mapping: true
        naming_strategy: doctrine.orm.naming_strategy.underscore_number_aware
        auto_mapping: true
        mappings:
            App:
                is_bundle: false
                dir: '%kernel.project_dir%/src/Entity'
                prefix: 'App\Entity'
                alias: App
```

## 4. Test Database Connection
Test the connection using Symfony console:

```bash
# Clear cache first
php bin/console cache:clear

# Test database connection
php bin/console doctrine:database:create --if-not-exists
php bin/console doctrine:schema:validate
```

## 5. Configure Entity Manager
If you need custom entity manager configuration, update `config/packages/doctrine.yaml`:

```yaml
doctrine:
    orm:
        entity_managers:
            default:
                connection: default
                naming_strategy: doctrine.orm.naming_strategy.underscore_number_aware
                auto_mapping: true
                mappings:
                    App:
                        is_bundle: false
                        dir: '%kernel.project_dir%/src/Entity'
                        prefix: 'App\Entity'
                        alias: App
```

## 6. Enable Logging (Optional)
To enable SQL query logging in development, update `config/packages/doctrine.yaml`:

```yaml
doctrine:
    dbal:
        logging: true
        profiling: true
```

## 7. Example Repository Usage
Example of using the database connection in a repository:

```php
<?php

namespace App\Repository;

use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use App\Entity\YourEntity;

class YourEntityRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, YourEntity::class);
    }

    public function findWithSSL(): array
    {
        return $this->createQueryBuilder('e')
            ->getQuery()
            ->getResult();
    }
}
```

## 8. Troubleshooting

### SSL Certificate Issues
If you encounter SSL certificate errors:

1. Verify certificate path:
```bash
ls -l config/ssl/root.crt
```

2. Check certificate permissions:
```bash
chmod 644 config/ssl/root.crt
```

3. Validate database connection:
```bash
php bin/console doctrine:query:sql "SELECT 1"
```

### Common Error Solutions

1. "SSL certificate verification failed":
   - Ensure the certificate path in DATABASE_URL is correct
   - Verify the certificate is readable by the web server

2. "Unable to connect to PostgreSQL server":
   - Check if PostgreSQL container is running
   - Verify port mapping in docker-compose.yml
   - Ensure credentials are correct

3. "Database schema out of sync":
```bash
php bin/console doctrine:schema:update --force
```

## 9. Production Considerations

1. Environment-specific configuration:
```yaml
# config/packages/prod/doctrine.yaml
doctrine:
    dbal:
        logging: false
        profiling: false
```

2. Secure certificate handling:
   - Store certificates outside web root
   - Use environment variables for paths
   - Regular certificate rotation

3. Connection pooling:
```yaml
doctrine:
    dbal:
        connections:
            default:
                wrapper_class: 'App\Database\ConnectionWrapper'
                pooled: true
```

## 10. Performance Optimization

1. Enable query cache:
```yaml
doctrine:
    orm:
        query_cache_driver:
            type: pool
            pool: doctrine.system_cache_pool
```

2. Configure metadata cache:
```yaml
doctrine:
    orm:
        metadata_cache_driver:
            type: pool
            pool: doctrine.system_cache_pool
```

Remember to adjust these settings based on your specific needs and environment.
