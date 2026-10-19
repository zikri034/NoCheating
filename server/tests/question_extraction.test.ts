import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import db from '../src/db/knex';
import jwt from 'jsonwebtoken';
import { geminiService } from '../src/ai/gemini.service';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'default_access_secret';

describe('Question Document Extraction and Batch Create Tests', () => {
  let lecturerToken: string;
  let studentToken: string;
  let courseId: string;

  beforeAll(async () => {
    const lecturer = await db('users').where({ role: 'lecturer' }).first();
    const student = await db('users').where({ role: 'student' }).first();
    const course = await db('courses').first();

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

    // Setup mock handler for extraction so tests don't require live Gemini API network calls
    geminiService.setMockExtractionHandler(async () => {
      return {
        course_topic_detected: 'Pemrograman Aplikasi Mobile',
        total_questions: 2,
        questions: [
          {
            number: 1,
            type: 'mcq',
            body: 'Apa framework yang digunakan untuk mengembangkan aplikasi multiplatform ini?',
            options: ['A. React Native', 'B. Flutter', 'C. Xamarin', 'D. Ionic'],
            correct_option: 'B',
            max_score: 10,
          },
          {
            number: 2,
            type: 'essay',
            body: 'Jelaskan konsep Single Source of Truth dalam state management!',
            rubric: 'Kriteria: Penjelasan definisi (5 poin), Manfaat arsitektur (5 poin)',
            model_answer: 'State hanya disimpan di satu tempat terpusat untuk mencegah desinkronisasi.',
            max_score: 15,
          },
        ],
      };
    });
  });

  afterAll(() => {
    geminiService.setMockExtractionHandler(null);
  });

  it('POST /api/questions/extract-document should return 401 without auth', async () => {
    const res = await request(app)
      .post('/api/questions/extract-document')
      .attach('document', Buffer.from('dummy content'), 'soal.txt');

    expect(res.status).toBe(401);
  });

  it('POST /api/questions/extract-document should return 403 for student', async () => {
    const res = await request(app)
      .post('/api/questions/extract-document')
      .set('Authorization', `Bearer ${studentToken}`)
      .attach('document', Buffer.from('dummy content'), 'soal.txt');

    expect(res.status).toBe(403);
  });

  it('POST /api/questions/extract-document should return 400 when no file attached', async () => {
    const res = await request(app)
      .post('/api/questions/extract-document')
      .set('Authorization', `Bearer ${lecturerToken}`);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('NO_FILE');
  });

  it('POST /api/questions/extract-document should return 400 for unsupported file extension', async () => {
    const res = await request(app)
      .post('/api/questions/extract-document')
      .set('Authorization', `Bearer ${lecturerToken}`)
      .attach('document', Buffer.from('dummy content'), 'soal.exe');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_FILE_TYPE');
  });

  it('POST /api/questions/extract-document should extract questions from uploaded document', async () => {
    const res = await request(app)
      .post('/api/questions/extract-document')
      .set('Authorization', `Bearer ${lecturerToken}`)
      .attach('document', Buffer.from('1. Apa framework?\nA. React\nB. Flutter'), 'bank_soal.docx');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.extracted.total_questions).toBe(2);
    expect(res.body.extracted.questions[0].type).toBe('mcq');
    expect(res.body.extracted.questions[0].correct_option).toBe('B');
    expect(res.body.extracted.questions[1].type).toBe('essay');
  });

  it('POST /api/questions/batch should insert multiple questions into database', async () => {
    const questionsToInsert = [
      {
        type: 'mcq' as const,
        body: 'Batch MCQ: Berapa bit enkripsi AES-GCM?',
        options: ['128 bit', '256 bit', '512 bit'],
        correct_option: '256 bit',
        max_score: 10,
      },
      {
        type: 'essay' as const,
        body: 'Batch Essay: Jelaskan prinsip Neo-Brutalism!',
        rubric: 'Border tebal (5 poin), bayangan keras tanpa blur (5 poin)',
        model_answer: 'Neo-brutalism menonjolkan border hitam 3px dan bayangan offset tajam.',
        max_score: 20,
      },
    ];

    const res = await request(app)
      .post('/api/questions/batch')
      .set('Authorization', `Bearer ${lecturerToken}`)
      .send({
        course_id: courseId,
        questions: questionsToInsert,
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.count).toBe(2);
    expect(res.body.questions).toHaveLength(2);
    expect(res.body.questions[0].course_id).toBe(courseId);
  });

  it('POST /api/questions/batch should succeed when options and rubric contain null from extraction', async () => {
    const questionsFromClient = [
      {
        type: 'mcq' as const,
        body: 'Soal MCQ dengan rubric null',
        options: ['Opsi A', 'Opsi B', 'Opsi C'],
        correct_option: 'Opsi B',
        rubric: null,
        model_answer: null,
        max_score: 10,
      },
      {
        type: 'essay' as const,
        body: 'Soal Essay dengan options null',
        options: null,
        correct_option: null,
        rubric: 'Rubrik penilaian ringkas',
        model_answer: 'Jawaban acuan lengkap',
        max_score: 15,
      },
    ];

    const res = await request(app)
      .post('/api/questions/batch')
      .set('Authorization', `Bearer ${lecturerToken}`)
      .send({
        course_id: courseId,
        questions: questionsFromClient,
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.count).toBe(2);
    expect(res.body.questions[1].type).toBe('essay');
    expect(res.body.questions[1].options).toBeNull();
  });
});
