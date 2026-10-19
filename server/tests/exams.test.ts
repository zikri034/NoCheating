import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import db from '../src/db/knex';
import jwt from 'jsonwebtoken';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'default_access_secret';

describe('Exams and Questions API Tests (F03 & F10)', () => {
  let lecturerToken: string;
  let studentToken: string;
  let lecturerId: string;
  let studentId: string;
  let courseId: string;
  let examId: string;
  let questionId: string;

  beforeAll(async () => {
    // Fetch seeded lecturer, student, and course
    const lecturer = await db('users').where({ role: 'lecturer' }).first();
    const student = await db('users').where({ role: 'student' }).first();
    const course = await db('courses').first();

    lecturerId = lecturer.id;
    studentId = student.id;
    courseId = course.id;

    lecturerToken = jwt.sign(
      { id: lecturer.id, email: lecturer.email, role: lecturer.role, name: lecturer.name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    studentToken = jwt.sign(
      { id: student.id, email: student.email, role: student.role, name: student.name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );
  });

  it('GET /api/exams without token should return 401 Unauthorized', async () => {
    const res = await request(app).get('/api/exams');
    expect(res.status).toBe(401);
  });

  it('POST /api/exams with student role should return 403 Forbidden', async () => {
    const res = await request(app)
      .post('/api/exams')
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        course_id: courseId,
        title: 'Ujian Ilegal',
        start_at: new Date(Date.now() + 3600000).toISOString(),
        end_at: new Date(Date.now() + 7200000).toISOString(),
        duration_min: 60,
      });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('POST /api/exams with lecturer role should create an exam (F03)', async () => {
    const res = await request(app)
      .post('/api/exams')
      .set('Authorization', `Bearer ${lecturerToken}`)
      .send({
        course_id: courseId,
        title: 'Kuis 1 Pemrograman Mobile',
        description: 'Materi dasar Flutter & State Management',
        start_at: new Date(Date.now() + 3600000).toISOString(),
        end_at: new Date(Date.now() + 7200000).toISOString(),
        duration_min: 60,
        status: 'published',
        require_biometric: true,
      });

    expect(res.status).toBe(201);
    expect(res.body.exam).toBeDefined();
    expect(res.body.exam.title).toBe('Kuis 1 Pemrograman Mobile');
    expect(res.body.exam.require_biometric).toBe(true);
    examId = res.body.exam.id;
  });

  it('POST /api/questions should allow lecturer to add question to bank (F03)', async () => {
    const res = await request(app)
      .post('/api/questions')
      .set('Authorization', `Bearer ${lecturerToken}`)
      .send({
        course_id: courseId,
        type: 'mcq',
        body: 'Apa kepanjangan dari APK?',
        options: ['Android Package Kit', 'Application Pack Kit', 'Apple Package Kernel', 'Android Process Kernel'],
        correct_option: 'A',
        max_score: 10,
      });

    expect(res.status).toBe(201);
    expect(res.body.question).toBeDefined();
    expect(res.body.question.body).toBe('Apa kepanjangan dari APK?');
    questionId = res.body.question.id;
  });

  it('POST /api/exams/:id/questions should assign questions to exam (F03)', async () => {
    const res = await request(app)
      .post(`/api/exams/${examId}/questions`)
      .set('Authorization', `Bearer ${lecturerToken}`)
      .send({
        question_ids: [questionId],
      });

    expect(res.status).toBe(201);
    expect(res.body.added).toBe(1);
  });

  it('GET /api/exams should search and filter exams (F10)', async () => {
    const res = await request(app)
      .get('/api/exams?search=Kuis 1&status=published')
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.exams).toBeDefined();
    expect(res.body.exams.length).toBeGreaterThanOrEqual(1);
    expect(res.body.exams[0].title).toContain('Kuis 1');
    expect(res.body.exams[0].is_enrolled).toBe(false);
  });

  it('POST /api/exams/:id/enroll should allow student to enroll (F10)', async () => {
    const res = await request(app)
      .post(`/api/exams/${examId}/enroll`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(201);
    expect(res.body.message).toContain('Berhasil');
  });

  it('POST /api/exams/:id/enroll duplicate should return 400 ALREADY_ENROLLED', async () => {
    const res = await request(app)
      .post(`/api/exams/${examId}/enroll`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('ALREADY_ENROLLED');
  });

  it('GET /api/exams/:id for student MUST NOT leak correct_option or rubric (PRD Rule 6 & F03)', async () => {
    const res = await request(app)
      .get(`/api/exams/${examId}`)
      .set('Authorization', `Bearer ${studentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.exam.is_enrolled).toBe(true);
    expect(res.body.questions).toBeDefined();
    expect(res.body.questions.length).toBeGreaterThan(0);

    // Verify security: student must NOT see correct_option or rubric
    for (const q of res.body.questions) {
      expect(q.correct_option).toBeUndefined();
      expect(q.rubric).toBeUndefined();
      expect(q.model_answer).toBeUndefined();
    }
  });

  it('GET /api/questions for lecturer should show full details and search (F10)', async () => {
    const res = await request(app)
      .get('/api/questions?search=APK')
      .set('Authorization', `Bearer ${lecturerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.questions.length).toBeGreaterThan(0);
    expect(res.body.questions[0].correct_option).toBe('A');
  });

  it('GET /api/courses should list courses for dropdown selection', async () => {
    const res = await request(app)
      .get('/api/courses')
      .set('Authorization', `Bearer ${lecturerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.courses).toBeDefined();
    expect(res.body.courses.length).toBeGreaterThan(0);
  });
});
