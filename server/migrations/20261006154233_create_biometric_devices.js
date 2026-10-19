/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  await knex.schema.createTable('biometric_devices', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.uuid('device_id').notNullable();
    table.text('secret_hash').notNullable();
    table.text('device_name');
    table.text('platform');
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
    table.timestamp('last_used_at');
    table.timestamp('revoked_at');
    table.unique(['user_id', 'device_id']);
  });

  // Add check constraint manually for platform
  await knex.raw('ALTER TABLE biometric_devices ADD CONSTRAINT biometric_platform_check CHECK (platform IN (\'android\',\'ios\'))');
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('biometric_devices');
};
