/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  await knex.schema.createTable('users', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.text('role').notNullable();
    table.text('nim').unique();
    table.text('name').notNullable();
    table.text('email').notNullable().unique();
    table.text('password_hash').notNullable();
    table.text('avatar_path');
    table.integer('failed_logins').notNullable().defaultTo(0);
    table.timestamp('locked_until');
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
  });

  // Add check constraint manually for role
  await knex.raw('ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN (\'student\',\'lecturer\'))');

  await knex.schema.createTable('refresh_tokens', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.text('token_hash').notNullable().unique();
    table.timestamp('expires_at').notNullable();
    table.timestamp('revoked_at');
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('refresh_tokens');
  await knex.schema.dropTableIfExists('users');
};
