/**
 * S4 Migration: exam_attempts, attempt_answers, essay_grades
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  // --- exam_attempts ---
  await knex.schema.createTable('exam_attempts', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('exam_id').notNullable().references('id').inTable('exams');
    table.uuid('student_id').notNullable().references('id').inTable('users');
    table.timestamp('started_at').notNullable().defaultTo(knex.fn.now());
    table.timestamp('server_deadline').notNullable();
    table.timestamp('submitted_at');
    table.text('status').notNullable().defaultTo('in_progress');
    table.integer('critical_count').notNullable().defaultTo(0);
    table.decimal('total_score', 7, 2);
    table.bigInteger('seed').notNullable();
    table.unique(['exam_id', 'student_id']);
  });

  await knex.raw("ALTER TABLE exam_attempts ADD CONSTRAINT exam_attempts_status_check CHECK (status IN ('in_progress','submitted','terminated','graded'))");

  // --- attempt_answers ---
  await knex.schema.createTable('attempt_answers', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('attempt_id').notNullable().references('id').inTable('exam_attempts').onDelete('CASCADE');
    table.uuid('question_id').notNullable().references('id').inTable('questions');
    table.text('selected_option');
    table.text('answer_text');
    table.timestamp('updated_at').notNullable().defaultTo(knex.fn.now());
    table.unique(['attempt_id', 'question_id']);
  });

  // --- essay_grades ---
  await knex.schema.createTable('essay_grades', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'));
    table.uuid('answer_id').notNullable().unique().references('id').inTable('attempt_answers').onDelete('CASCADE');
    table.decimal('ai_score', 6, 2);
    table.jsonb('ai_json');
    table.text('ai_model');
    table.text('confidence');
    table.jsonb('flags').notNullable().defaultTo('[]');
    table.text('status').notNullable().defaultTo('pending');
    table.decimal('teacher_score', 6, 2);
    table.text('teacher_comment');
    table.decimal('final_score', 6, 2);
    table.uuid('graded_by').references('id').inTable('users');
    table.timestamp('updated_at').notNullable().defaultTo(knex.fn.now());
  });

  await knex.raw("ALTER TABLE essay_grades ADD CONSTRAINT essay_grades_confidence_check CHECK (confidence IS NULL OR confidence IN ('low','medium','high'))");
  await knex.raw("ALTER TABLE essay_grades ADD CONSTRAINT essay_grades_status_check CHECK (status IN ('pending','ai_graded','needs_review','pending_manual','finalized'))");
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('essay_grades');
  await knex.schema.dropTableIfExists('attempt_answers');
  await knex.schema.dropTableIfExists('exam_attempts');
};
