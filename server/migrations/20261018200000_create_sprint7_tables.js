/**
 * Sprint 7 Migration: blocks, fx_rates, study_pairs, game_scores, course_feedback
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  // 1. blocks (F16 Blockchain Audit Trail)
  await knex.schema.createTable('blocks', (table) => {
    table.bigInteger('idx').primary();
    table.text('type').notNullable();
    table.specificType('prev_hash', 'char(64)').notNullable();
    table.specificType('hash', 'char(64)').notNullable().unique();
    table.text('data_canonical').notNullable();
    table.jsonb('data').notNullable();
    table.bigInteger('nonce').notNullable();
    table.timestamp('created_at', { useTz: true }).notNullable().defaultTo(knex.fn.now());
  });
  await knex.raw("ALTER TABLE blocks ADD CONSTRAINT blocks_type_check CHECK (type IN ('GENESIS','SUBMISSION','RESULT'))");

  // 2. fx_rates (F09 Currency Conversion Cache)
  await knex.schema.createTable('fx_rates', (table) => {
    table.text('base').notNullable();
    table.text('quote').notNullable();
    table.decimal('rate', 18, 8).notNullable();
    table.timestamp('fetched_at', { useTz: true }).notNullable();
    table.primary(['base', 'quote']);
  });

  // 3. study_pairs (F11 Mini Game Pair Rush Terms & Definitions)
  await knex.schema.createTable('study_pairs', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('course_id').notNullable().references('id').inTable('courses').onDelete('CASCADE');
    table.text('term').notNullable();
    table.text('definition').notNullable();
  });

  // 4. game_scores (F11 Pair Rush Leaderboard)
  await knex.schema.createTable('game_scores', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.integer('score').notNullable();
    table.integer('duration_ms').notNullable();
    table.timestamp('created_at', { useTz: true }).notNullable().defaultTo(knex.fn.now());
  });

  // 5. course_feedback (F14 Saran dan Kesan)
  await knex.schema.createTable('course_feedback', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.text('impression').notNullable();
    table.text('suggestion');
    table.integer('rating').notNullable();
    table.timestamp('created_at', { useTz: true }).notNullable().defaultTo(knex.fn.now());
  });
  await knex.raw("ALTER TABLE course_feedback ADD CONSTRAINT course_feedback_rating_check CHECK (rating BETWEEN 1 AND 5)");
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('course_feedback');
  await knex.schema.dropTableIfExists('game_scores');
  await knex.schema.dropTableIfExists('study_pairs');
  await knex.schema.dropTableIfExists('fx_rates');
  await knex.schema.dropTableIfExists('blocks');
};
