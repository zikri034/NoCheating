import knex from 'knex';
import dotenv from 'dotenv';

dotenv.config();

const dbUrl = process.env.DATABASE_URL || 'postgres://safeexam:change_me@localhost:5432/safeexam';
const isLocal = !dbUrl || dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');

const config = {
  client: 'pg',
  connection: isLocal
    ? dbUrl
    : { connectionString: dbUrl, ssl: { rejectUnauthorized: false } },
  pool: { min: 2, max: 10 },
  migrations: {
    directory: './migrations',
    tableName: 'knex_migrations'
  },
  seeds: {
    directory: './seeds'
  }
};

const db = knex(config);

export default db;
