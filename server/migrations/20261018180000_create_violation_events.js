/**
 * S5 Migration: violation_events
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  await knex.schema.createTable('violation_events', (table) => {
    table.bigIncrements('id').primary();
    table.uuid('attempt_id').notNullable().references('id').inTable('exam_attempts').onDelete('CASCADE');
    table.text('type').notNullable();
    table.text('severity').notNullable();
    table.jsonb('detail');
    table.timestamp('occurred_at').notNullable().defaultTo(knex.fn.now());
  });

  await knex.raw("ALTER TABLE violation_events ADD CONSTRAINT violation_events_severity_check CHECK (severity IN ('warn','critical'))");
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('violation_events');
};
