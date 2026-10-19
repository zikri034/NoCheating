/**
 * S3 Migration: courses, exams, questions, exam_questions, enrollments
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  // Enable trigram extension for search
  await knex.raw('CREATE EXTENSION IF NOT EXISTS pg_trgm');

  // --- courses ---
  await knex.schema.createTable('courses', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.text('code').notNullable().unique();
    table.text('name').notNullable();
    table.uuid('lecturer_id').notNullable().references('id').inTable('users');
  });

  // --- exams ---
  await knex.schema.createTable('exams', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('course_id').notNullable().references('id').inTable('courses');
    table.text('title').notNullable();
    table.text('description');
    table.timestamp('start_at').notNullable();
    table.timestamp('end_at').notNullable();
    table.integer('duration_min').notNullable();
    table.bigInteger('fee_idr');
    table.float('venue_lat');
    table.float('venue_lng');
    table.integer('venue_radius_m');
    table.boolean('require_biometric').notNullable().defaultTo(false);
    table.boolean('require_geofence').notNullable().defaultTo(false);
    table.integer('max_critical').notNullable().defaultTo(3);
    table.boolean('ai_auto_finalize').notNullable().defaultTo(false);
    table.text('status').notNullable().defaultTo('draft');
    table.uuid('created_by').notNullable().references('id').inTable('users');
  });

  // Add check constraints
  await knex.raw('ALTER TABLE exams ADD CONSTRAINT exams_duration_check CHECK (duration_min > 0)');
  await knex.raw('ALTER TABLE exams ADD CONSTRAINT exams_fee_check CHECK (fee_idr IS NULL OR fee_idr >= 0)');
  await knex.raw("ALTER TABLE exams ADD CONSTRAINT exams_status_check CHECK (status IN ('draft','published'))");
  await knex.raw('ALTER TABLE exams ADD CONSTRAINT exams_dates_check CHECK (end_at > start_at)');

  // Trigram index for title search
  await knex.raw('CREATE INDEX exams_title_trgm_idx ON exams USING gin (title gin_trgm_ops)');

  // --- questions ---
  await knex.schema.createTable('questions', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('course_id').notNullable().references('id').inTable('courses');
    table.text('type').notNullable();
    table.text('body').notNullable();
    table.jsonb('options');           // MCQ options array
    table.text('correct_option');     // MCQ correct answer key
    table.text('rubric');             // Essay rubric
    table.text('model_answer');       // Essay model answer
    table.decimal('max_score', 6, 2).notNullable().defaultTo(1);
  });

  await knex.raw("ALTER TABLE questions ADD CONSTRAINT questions_type_check CHECK (type IN ('mcq','essay'))");
  await knex.raw('CREATE INDEX questions_body_trgm_idx ON questions USING gin (body gin_trgm_ops)');

  // --- exam_questions (pivot) ---
  await knex.schema.createTable('exam_questions', (table) => {
    table.uuid('exam_id').notNullable().references('id').inTable('exams').onDelete('CASCADE');
    table.uuid('question_id').notNullable().references('id').inTable('questions');
    table.integer('position').notNullable();
    table.primary(['exam_id', 'question_id']);
  });

  // --- enrollments ---
  await knex.schema.createTable('enrollments', (table) => {
    table.uuid('exam_id').notNullable().references('id').inTable('exams').onDelete('CASCADE');
    table.uuid('student_id').notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
    table.primary(['exam_id', 'student_id']);
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('enrollments');
  await knex.schema.dropTableIfExists('exam_questions');
  await knex.schema.dropTableIfExists('questions');
  await knex.schema.dropTableIfExists('exams');
  await knex.schema.dropTableIfExists('courses');
};
