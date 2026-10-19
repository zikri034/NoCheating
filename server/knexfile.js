require('dotenv').config();

const dbUrl = process.env.DATABASE_URL || '';
const isLocal = !dbUrl || dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');

module.exports = {
  client: 'pg',
  connection: isLocal
    ? dbUrl
    : { connectionString: dbUrl, ssl: { rejectUnauthorized: false } },
  migrations: {
    directory: './migrations',
    tableName: 'knex_migrations'
  },
  seeds: {
    directory: './seeds'
  }
};
