# Connecting Node.js Application to PostgreSQL with SSL

This guide details how to connect your Node.js application to the PostgreSQL database with SSL verification using different approaches.

## 1. Copy SSL Certificate
First, copy the SSL certificate from the PostgreSQL container:

```bash
# Create SSL directory in your Node.js project
mkdir -p config/ssl

# Copy the certificate from PostgreSQL container
docker compose cp postgres:/var/lib/postgresql/ssl/server.crt config/ssl/root.crt
```

## 2. Using Node-Postgres (pg)

### Installation
```bash
npm install pg
# or with yarn
yarn add pg
```

### Basic Connection
```javascript
const { Pool } = require('pg');

const pool = new Pool({
  user: 'user1',
  host: 'localhost',
  database: 'db1',
  password: 'your_password',
  port: 5432,
  ssl: {
    rejectUnauthorized: true,
    ca: require('fs').readFileSync('config/ssl/root.crt').toString(),
  }
});

// Test connection
async function testConnection() {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    console.log('Connected to PostgreSQL:', result.rows[0]);
    client.release();
  } catch (err) {
    console.error('Connection error:', err);
  }
}

testConnection();
```

### With Environment Variables
```javascript
// config/database.js
require('dotenv').config();

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: {
    rejectUnauthorized: true,
    ca: require('fs').readFileSync(process.env.SSL_CERT_PATH).toString(),
  }
});

module.exports = pool;
```

```env
# .env
DB_USER=user1
DB_HOST=localhost
DB_NAME=db1
DB_PASSWORD=your_password
DB_PORT=5432
SSL_CERT_PATH=config/ssl/root.crt
```

## 3. Using TypeORM

### Installation
```bash
npm install typeorm reflect-metadata pg
# or with yarn
yarn add typeorm reflect-metadata pg
```

### Configuration
```typescript
// config/database.config.ts
import { DataSource } from 'typeorm';
import { join } from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  entities: [join(__dirname, '../src/entities/**/*.entity{.ts,.js}')],
  migrations: [join(__dirname, '../src/migrations/**/*{.ts,.js}')],
  ssl: {
    rejectUnauthorized: true,
    ca: require('fs').readFileSync(process.env.SSL_CERT_PATH).toString(),
  },
  synchronize: false,
  logging: process.env.NODE_ENV === 'development',
});
```

### Entity Example
```typescript
// src/entities/user.entity.ts
import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @Column({ unique: true })
  email: string;
}
```

### Repository Usage
```typescript
// src/repositories/user.repository.ts
import { AppDataSource } from '../config/database.config';
import { User } from '../entities/user.entity';

export const UserRepository = AppDataSource.getRepository(User);

// Example usage
async function findUsers() {
  try {
    const users = await UserRepository.find();
    return users;
  } catch (error) {
    console.error('Error fetching users:', error);
    throw error;
  }
}
```

## 4. Connection Pooling with pg-pool

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: {
    rejectUnauthorized: true,
    ca: require('fs').readFileSync(process.env.SSL_CERT_PATH).toString(),
  },
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
  connectionTimeoutMillis: 2000, // Return an error after 2 seconds if connection could not be established
});

// Pool error handling
pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err);
});
```

## 5. Troubleshooting

### SSL Certificate Issues
```javascript
// Verify SSL certificate
const fs = require('fs');
const path = require('path');

function verifyCertificate() {
  const certPath = path.join(process.cwd(), 'config/ssl/root.crt');
  try {
    const cert = fs.readFileSync(certPath);
    console.log('Certificate loaded successfully');
    return cert;
  } catch (error) {
    console.error('Certificate error:', error);
    throw error;
  }
}
```

### Connection Testing
```javascript
async function testDatabaseConnection() {
  const pool = new Pool({/* config */});
  
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT version()');
    console.log('Database connection successful:', result.rows[0]);
    client.release();
    return true;
  } catch (error) {
    console.error('Database connection error:', error);
    return false;
  } finally {
    await pool.end();
  }
}
```

## 6. Production Best Practices

### Connection Management
```javascript
// Singleton pool instance
let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({
      // ... configuration
      max: process.env.NODE_ENV === 'production' ? 50 : 20,
      ssl: {
        rejectUnauthorized: true,
        ca: require('fs').readFileSync(process.env.SSL_CERT_PATH).toString(),
      }
    });
  }
  return pool;
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  if (pool) {
    await pool.end();
  }
  process.exit(0);
});
```

### Error Handling
```javascript
// Wrapper for database operations
async function executeQuery(query, params = []) {
  const client = await getPool().connect();
  try {
    const result = await client.query(query, params);
    return result.rows;
  } catch (error) {
    console.error('Query error:', error);
    throw error;
  } finally {
    client.release();
  }
}
```

## 7. Monitoring and Logging

### Query Logging
```javascript
const pool = new Pool({
  // ... other config
  log: (msg) => {
    if (process.env.NODE_ENV === 'development') {
      console.log('Database Log:', msg);
    }
  }
});

// Custom query logging
const loggedPool = new Proxy(pool, {
  get: (target, prop) => {
    if (prop === 'query') {
      return async (text, params) => {
        const start = Date.now();
        try {
          const result = await target.query(text, params);
          const duration = Date.now() - start;
          console.log('Executed query', { text, duration, rows: result.rowCount });
          return result;
        } catch (error) {
          console.error('Query error', { text, error });
          throw error;
        }
      };
    }
    return target[prop];
  }
});
```

Remember to adjust these configurations based on your specific needs and environment requirements.
