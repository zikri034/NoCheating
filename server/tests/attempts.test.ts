import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import db from '../src/db/knex';
import jwt from 'jsonwebtoken';
import {
  calculateServerDeadline,
  isDeadlineExceeded,
  randomizeQuestionsForAttempt,
  gradeMultipleChoice,
} from '../src/services/attempt.service';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'default_access_secret';

describe('Attempt Service Unit Tests (F04 Logic)', () => {
  it('calculateServerDeadline should take duration when before exam end_at', () => {
    const start = new Date('2026-10-18T09:00:00Z');
    const endAt = new Date('2026-10-18T12:00:00Z');
    const deadline = calculateServerDeadline(start, 60, endAt);
    expect(deadline.toISOString()).toBe('2026-10-18T10:00:00.000Z');
  });

  it('calculateServerDeadline should cap at exam end_at if duration exceeds it', () => {
    const start = new Date('2026-10-18T11:30:00Z');
    const endAt = new Date('2026-10-18T12:00:00Z');
    const deadline = calculateServerDeadline(start, 60, endAt);
    expect(deadline.toISOString()).toBe('2026-10-18T12:00:00.000Z');
  });

  it('isDeadlineExceeded respects grace period', () => {
    const deadline = new Date('2026-10-18T10:00:00Z');

    // Exactly at deadline -> not exceeded
    expect(isDeadlineExceeded(new Date('2026-10-18T10:00:00Z'), deadline, 60)).toBe(false);

    // 30 seconds after deadline (within 60s grace) -> not exceeded
    expect(isDeadlineExceeded(new Date('2026-10-18T10:00:30Z'), deadline, 60)).toBe(false);

    // 61 seconds after deadline -> exceeded
    expect(isDeadlineExceeded(new Date('2026-10-18T10:01:01Z'), deadline, 60)).toBe(true);
  });

  it('randomizeQuestionsForAttempt produces deterministic order for same seed', () => {
    const sampleQuestions = [
      { id: '1', type: 'mcq', body: 'Q1', options: ['A', 'B', 'C', 'D'], max_score: 10 },
      { id: '2', type: 'mcq', body: 'Q2', options: ['E', 'F', 'G', 'H'], max_score: 10 },
      { id: '3', type: 'essay', body: 'Q3', max_score: 20 },
    ];

    const run1 = randomizeQuestionsForAttempt(sampleQuestions, 12345);
    const run2 = randomizeQuestionsForAttempt(sampleQuestions, 12345);

    expect(run1.map((q) => q.id)).toEqual(run2.map((q) => q.id));
    expect(run1[0].options).toEqual(run2[0].options);
  });

  it('gradeMultipleChoice correctly calculates scores', () => {
    const questions = [
      { id: 'q1', type: 'mcq', max_score: 10, correct_option: 'B' },
      { id: 'q2', type: 'mcq', max_score: 15, correct_option: 'C' },
      { id: 'q3', type: 'essay', max_score: 25 },
    ];

    const answers = [
      { question_id: 'q1', selected_option: 'B' }, // correct (+10)
      { question_id: 'q2', selected_option: 'A' }, // wrong (0)
      { question_id: 'q3', selected_option: null },
    ];

    const result = gradeMultipleChoice(questions, answers);
    expect(result.totalMcqScore).toBe(10);
    expect(result.maxPossibleMcqScore).toBe(25);
    expect(result.hasEssay).toBe(true);
    expect(result.gradedQuestions[0].is_correct).toBe(true);
    expect(result.gradedQuestions[1].is_correct).toBe(false);
  });
});

describe('Exam Attempt API Integration Tests (F04)', () => {
  let studentToken: string;
  let otherStudentToken: string;
  let lecturerToken: string;
  let studentId: string;
  let otherStudentId: string;
  let examId: string;
  let attemptId: string;
  let questionId: string;

  beforeAll(async () => {
    const students = await db('users').where({ role: 'student' }).limit(2);
    const lecturer = await db('users').where({ role: 'lecturer' }).first();
    const course = await db('courses').first();

    studentId = students[0].id;
    otherStudentId = students[1].id;

    studentToken = jwt.sign(
      { id: studentId, email: students[0].email, role: 'student', name: students[0].name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    otherStudentToken = jwt.sign(
      { id: otherStudentId, email: students[1].email, role: 'student', name: students[1].name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    lecturerToken = jwt.sign(
      { id: lecturer.id, email: lecturer.email, role: 'lecturer', name: lecturer.name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    // Create a published exam with 1 MCQ question
    const [exam] = await db('exams')
      .insert({
        course_id: course.id,
        title: 'Ujian Sprint 4 Test',
        start_at: new Date(Date.now() - 3600000).toISOString(), // started 1h ago
        end_at: new Date(Date.now() + 7200000).toISOString(),   // ends in 2h
        duration_min: 60,
        status: 'published',
        created_by: lecturer.id,
      })
      .returning('*');
    examId = exam.id;

    // Create an MCQ question
    const [q] = await db('questions')
      .insert({
        course_id: course.id,
        type: 'mcq',
        body: 'Framework apa yang digunakan untuk mobile frontend SafeExam?',
        options: JSON.stringify(['React Native', 'Flutter', 'Swift', 'Kotlin']),
        correct_option: 'Flutter',
        max_score: 100,
      })
      .returning('*');
    questionId = q.id;

    // Assign question to exam
    await db('exam_questions').insert({
      exam_id: examId,
      question_id: questionId,
      position: 1,
    });

    // Enroll student 1
    await db('enrollments').insert({
      exam_id: examId,
      student_id: studentId,
    });
  });

  it('GET /api/time returns current server time', async () => {
    const res = await request(app).get('/api/time');
    expect(res.status).toBe(200);
    expect(res.body.time).toBeDefined();
    expect(new Date(res.body.time).getTime()).not.toBeNaN();
  });

  it('POST /api/exams/:id/attempts without enrollment should return 403 NOT_ENROLLED', async () => {
    const res = await request(app)
      .post(`/api/exams/${examId}/attempts`)
      .set('Authorization', `Bearer ${otherStudentToken}`);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('NOT_ENROLLED');
  });

  it('POST /api/exams/:id/attempts starts attempt and returns sanitized questions (PRD Rule 6)', async () => {
    const res = await request(app)
      .post(`/api/exams/${examId}/attempts`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(201);
    expect(res.body.attempt).toBeDefined();
    expect(res.body.attempt.status).toBe('in_progress');
    expect(res.body.questions).toBeDefined();
    expect(res.body.questions.length).toBe(1);

    // Rule 6: must not leak correct_option
    expect(res.body.questions[0].correct_option).toBeUndefined();
    expect(res.body.questions[0].rubric).toBeUndefined();

    attemptId = res.body.attempt.id;
  });

  it('PUT /api/attempts/:id/answers synchronizes answers batch', async () => {
    const res = await request(app)
      .put(`/api/attempts/${attemptId}/answers`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        answers: [
          {
            question_id: questionId,
            selected_option: 'Flutter',
          },
        ],
      });

    expect(res.status).toBe(200);
    expect(res.body.saved_count).toBe(1);
  });

  it('PUT /api/attempts/:id/answers rejects if deadline + grace exceeded', async () => {
    // Temporarily set server_deadline in past
    await db('exam_attempts')
      .where({ id: attemptId })
      .update({ server_deadline: new Date(Date.now() - 120000) }); // 2 mins ago (>60s grace)

    const res = await request(app)
      .put(`/api/attempts/${attemptId}/answers`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        answers: [
          {
            question_id: questionId,
            selected_option: 'Flutter',
          },
        ],
      });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('DEADLINE_EXCEEDED');

    // Restore deadline to future for submit test
    await db('exam_attempts')
      .where({ id: attemptId })
      .update({ server_deadline: new Date(Date.now() + 3600000) });
  });

  it('POST /api/attempts/:id/submit locks attempt and auto-grades MCQ', async () => {
    const res = await request(app)
      .post(`/api/attempts/${attemptId}/submit`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.attempt).toBeDefined();
    expect(res.body.attempt.status).toBe('graded'); // Only MCQ -> graded
    expect(res.body.attempt.total_score).toBe('100.00');
  });

  it('POST /api/attempts/:id/submit again should return 400 ALREADY_SUBMITTED', async () => {
    const res = await request(app)
      .post(`/api/attempts/${attemptId}/submit`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('ALREADY_SUBMITTED');
  });

  it('GET /api/attempts/:id/result returns attempt score and answers for student', async () => {
    const res = await request(app)
      .get(`/api/attempts/${attemptId}/result`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.attempt.total_score).toBe('100.00');
    expect(res.body.answers.length).toBe(1);
    expect(res.body.answers[0].selected_option).toBe('Flutter');
  });

  it('GET /api/exams/:id/my-result returns attempt score and exam meta for student', async () => {
    const res = await request(app)
      .get(`/api/exams/${examId}/my-result`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.attempt.total_score).toBe('100.00');
    expect(res.body.exam.title).toBeDefined();
    expect(res.body.answers.length).toBe(1);
  });
});
