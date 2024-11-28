# Connecting Laravel Application to PostgreSQL with SSL

This guide details how to connect your Laravel application to the PostgreSQL database with SSL verification.

## 1. Copy SSL Certificate
First, copy the SSL certificate from the PostgreSQL container to your Laravel project:

```bash
# Create SSL directory in your Laravel project
mkdir -p storage/certs

# Copy the certificate from PostgreSQL container
docker compose cp postgres:/var/lib/postgresql/ssl/server.crt storage/certs/root.crt
```

## 2. Configure Environment Variables
Add these variables to your `.env` file:

```env
DB_CONNECTION=pgsql
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=db1
DB_USERNAME=user1
DB_PASSWORD=your_password

# SSL Configuration
DB_SSLMODE=verify-full
DB_SSLCERT=storage/certs/root.crt
DB_SSLKEY=null
DB_SSLROOTCERT=storage/certs/root.crt
```

## 3. Configure Database Connection
Update your `config/database.php`:

```php
'pgsql' => [
    'driver' => 'pgsql',
    'url' => env('DATABASE_URL'),
    'host' => env('DB_HOST', 'localhost'),
    'port' => env('DB_PORT', '5432'),
    'database' => env('DB_DATABASE', 'db1'),
    'username' => env('DB_USERNAME', 'user1'),
    'password' => env('DB_PASSWORD', ''),
    'charset' => 'utf8',
    'prefix' => '',
    'prefix_indexes' => true,
    'search_path' => 'public',
    'sslmode' => env('DB_SSLMODE', 'verify-full'),
    'sslcert' => base_path(env('DB_SSLCERT')),
    'sslkey' => env('DB_SSLKEY'),
    'sslrootcert' => base_path(env('DB_SSLROOTCERT')),
],
```

## 4. Test Database Connection
Test the connection using Laravel Artisan:

```bash
# Clear configuration cache
php artisan config:clear

# Test database connection
php artisan migrate:status
```

## 5. Example Model Usage
Example of a model using the SSL-enabled connection:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class YourModel extends Model
{
    protected $connection = 'pgsql';
    protected $table = 'your_table';
    
    protected $fillable = [
        'column1',
        'column2'
    ];
}
```

## 6. Enable Query Logging (Development)
To enable query logging in development, add this to your `AppServiceProvider`:

```php
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class AppServiceProvider extends ServiceProvider
{
    public function boot()
    {
        if (config('app.debug')) {
            DB::listen(function($query) {
                Log::info(
                    $query->sql,
                    [
                        'bindings' => $query->bindings,
                        'time' => $query->time
                    ]
                );
            });
        }
    }
}
```

## 7. Troubleshooting

### SSL Certificate Issues

1. Verify certificate path:
```bash
ls -l storage/certs/root.crt
```

2. Check certificate permissions:
```bash
chmod 644 storage/certs/root.crt
```

3. Test connection using tinker:
```bash
php artisan tinker
DB::connection()->getPdo();
```

### Common Error Solutions

1. "SSL certificate verification failed":
   - Check certificate path in config/database.php
   - Ensure certificate file permissions are correct
   - Verify certificate is valid and not expired

2. "Unable to connect to PostgreSQL server":
   - Verify PostgreSQL container is running
   - Check port mapping in docker-compose.yml
   - Confirm credentials in .env file

3. "Database schema not found":
```bash
php artisan migrate:fresh
```

## 8. Production Considerations

1. Secure certificate storage:
   - Store certificates outside web root
   - Use environment variables for paths
   - Implement certificate rotation

2. Connection pooling:
```php
'pgsql' => [
    // ... other config
    'sticky' => true,
    'pool' => [
        'min' => 2,
        'max' => 10
    ],
],
```

3. SSL in production:
```env
# Production .env
DB_SSLMODE=verify-full
DB_SSLCERT=/path/to/production/certs/root.crt
```

## 9. Performance Optimization

1. Query caching:
```php
use Illuminate\Support\Facades\Cache;

public function getItems()
{
    return Cache::remember('items', 3600, function () {
        return DB::table('items')->get();
    });
}
```

2. Database indexing:
```php
Schema::table('your_table', function (Blueprint $table) {
    $table->index(['frequently_searched_column']);
});
```

3. Eager loading relationships:
```php
$items = YourModel::with('relation1', 'relation2')->get();
```

## 10. Monitoring and Logging

1. Query monitoring:
```php
DB::listen(function($query) {
    if ($query->time > 100) {  // Log slow queries (>100ms)
        Log::warning('Slow query detected', [
            'sql' => $query->sql,
            'time' => $query->time,
            'connection' => 'pgsql'
        ]);
    }
});
```

2. Connection events:
```php
Event::listen('Illuminate\Database\Events\ConnectionEvent', function ($event) {
    Log::info('Database connection event', [
        'name' => get_class($event)
    ]);
});
```

Remember to adjust these settings based on your specific requirements and environment.
