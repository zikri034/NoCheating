import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import db from '../src/db/knex';
import jwt from 'jsonwebtoken';
import {
  ensureGenesisBlock,
  appendBlock,
  verifyChain,
  deterministicStringify,
  computeBlockHash,
  computeDataHash,
  mineNonce,
} from '../src/chain/blockchain.service';

const jwtSecret = process.env.JWT_ACCESS_SECRET || 'change_me';

describe('Sprint 7 — Blockchain, FX, Pair Rush & Feedback Tests', () => {
  let studentToken: string;
  let lecturerToken: string;
  let studentId: string;
  let lecturerId: string;
  let courseId: string;

  beforeAll(async () => {
    const student = await db('users').where({ email: 'citra.student@safeexam.ac.id' }).first();
    const lecturer = await db('users').where({ role: 'lecturer' }).first();
    const course = await db('courses').first();

    studentId = student.id;
    lecturerId = lecturer.id;
    courseId = course ? course.id : '';

    studentToken = jwt.sign(
      { id: student.id, email: student.email, role: 'student', name: student.name },
      jwtSecret,
      { expiresIn: '1h' }
    );

    lecturerToken = jwt.sign(
      { id: lecturer.id, email: lecturer.email, role: 'lecturer', name: lecturer.name },
      jwtSecret,
      { expiresIn: '1h' }
    );
  });

  afterAll(async () => {
    // cleanup test blocks created during tests (keep genesis)
    await db('blocks').where('idx', '>', 0).del();
  });

  describe('F16 — Blockchain & Hash Chain Verification', () => {
    it('deterministicStringify produces sorted keys deterministically', () => {
      const obj1 = { z: 1, a: 2, m: { b: 3, a: 4 } };
      const obj2 = { a: 2, m: { a: 4, b: 3 }, z: 1 };
      expect(deterministicStringify(obj1)).toBe(deterministicStringify(obj2));
      expect(deterministicStringify(obj1)).toBe('{"a":2,"m":{"a":4,"b":3},"z":1}');
    });

    it('mineNonce produces hash starting with difficulty zeros', () => {
      const dataHash = computeDataHash('{"test":"payload"}');
      const { nonce, hash } = mineNonce(1, '0'.repeat(64), dataHash, 2);
      expect(hash.startsWith('00')).toBe(true);
      expect(computeBlockHash(1, '0'.repeat(64), dataHash, nonce)).toBe(hash);
    });

    it('ensureGenesisBlock creates or returns valid genesis block (idx = 0)', async () => {
      const genesis = await ensureGenesisBlock();
      expect(genesis.idx).toBe(0);
      expect(genesis.type).toBe('GENESIS');
      expect(genesis.prev_hash).toBe('0'.repeat(64));
      expect(genesis.hash).toBeDefined();
    });

    it('appendBlock appends SUBMISSION block and links prev_hash correctly', async () => {
      const block = await appendBlock('SUBMISSION', {
        attempt_id: '99999999-9999-9999-9999-999999999999',
        exam_id: '88888888-8888-8888-8888-888888888888',
        student_ref: 'student_hash_abc',
        answers_hash: 'answers_hash_def',
        submitted_at: new Date().toISOString(),
      });

      expect(block.idx).toBeGreaterThan(0);
      expect(block.type).toBe('SUBMISSION');
      expect(block.prev_hash).toBeDefined();
    });

    it('verifyChain confirms valid chain integrity', async () => {
      const check = await verifyChain();
      expect(check.valid).toBe(true);
      expect(check.blockCount).toBeGreaterThanOrEqual(1);
    });

    it('verifyChain detects tampering if canonical data is mutated in DB', async () => {
      // Tamper latest block
      const latest = await db('blocks').orderBy('idx', 'desc').first();
      const originalCanonical = latest.data_canonical;

      await db('blocks')
        .where({ idx: latest.idx })
        .update({ data_canonical: '{"tampered":true}' });

      const check = await verifyChain();
      expect(check.valid).toBe(false);
      expect(check.corruptedIndex).toBe(Number(latest.idx));

      // Restore data
      await db('blocks')
        .where({ idx: latest.idx })
        .update({ data_canonical: originalCanonical });

      const restoredCheck = await verifyChain();
      expect(restoredCheck.valid).toBe(true);
    });

    it('GET /api/chain returns blockchain list', async () => {
      const res = await request(app)
        .get('/api/chain')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.blocks)).toBe(true);
      expect(res.body.blocks.length).toBeGreaterThanOrEqual(1);
    });

    it('GET /api/chain/verify returns valid status', async () => {
      const res = await request(app)
        .get('/api/chain/verify')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.valid).toBe(true);
    });

    it('GET /api/chain/receipt/:attemptId returns receipts with QR payload', async () => {
      const res = await request(app)
        .get('/api/chain/receipt/99999999-9999-9999-9999-999999999999')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.receipts)).toBe(true);
      expect(res.body.receipts.length).toBeGreaterThanOrEqual(1);
      expect(res.body.receipts[0].qr_payload).toContain('SAFEEXAM:BLOCK:');
    });
  });

  describe('F09 — Currency Conversion (FX Rates)', () => {
    it('GET /api/fx returns exchange rates for USD, EUR, MYR, JPY', async () => {
      const res = await request(app)
        .get('/api/fx')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.base).toBe('IDR');
      expect(res.body.rates.USD).toBeDefined();
      expect(res.body.rates.EUR).toBeDefined();
      expect(res.body.rates.MYR).toBeDefined();
      expect(res.body.rates.JPY).toBeDefined();
    });

    it('GET /api/fx?amount=100000 calculates converted amounts', async () => {
      const res = await request(app)
        .get('/api/fx?amount=100000')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.input_amount).toBe(100000);
      expect(res.body.converted.USD).toBeGreaterThan(0);
      expect(res.body.converted.EUR).toBeGreaterThan(0);
    });
  });

  describe('F11 — Mini Game Pair Rush & Leaderboard', () => {
    it('GET /api/pairs returns study pairs for matching game', async () => {
      const res = await request(app)
        .get('/api/pairs')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.pairs)).toBe(true);
      expect(res.body.pairs.length).toBeGreaterThanOrEqual(6);
      expect(res.body.pairs[0]).toHaveProperty('term');
      expect(res.body.pairs[0]).toHaveProperty('definition');
    });

    it('POST /api/game/scores records student game score when no exam is in progress', async () => {
      const res = await request(app)
        .post('/api/game/scores')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          score: 880,
          duration_ms: 19500,
        });

      expect(res.status).toBe(201);
      expect(res.body.score.score).toBe(880);
    });

    it('POST /api/game/scores blocks score submission if user is taking an exam (PRD F11)', async () => {
      // Create a temporary in_progress attempt with valid seed
      let exam = await db('exams').first();
      if (!exam) {
        const [createdExam] = await db('exams').insert({
          course_id: courseId,
          title: 'Temporary Exam for Pair Rush Test',
          description: 'Test Exam',
          start_at: new Date(),
          end_at: new Date(Date.now() + 3600000),
          duration_min: 60,
          created_by: lecturerId,
        }).returning('*');
        exam = createdExam;
      }
      const [attempt] = await db('exam_attempts')
        .insert({
          exam_id: exam.id,
          student_id: studentId,
          seed: 12345,
          status: 'in_progress',
          server_deadline: new Date(Date.now() + 3600000),
        })
        .returning('*');

      const res = await request(app)
        .post('/api/game/scores')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          score: 500,
          duration_ms: 20000,
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('EXAM_IN_PROGRESS');

      // Cleanup
      await db('exam_attempts').where({ id: attempt.id }).del();
    });

    it('GET /api/game/scores returns top 10 leaderboard with ranks', async () => {
      const res = await request(app)
        .get('/api/game/scores')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.leaderboard)).toBe(true);
      expect(res.body.leaderboard[0].rank).toBe(1);
      expect(res.body.leaderboard[0]).toHaveProperty('user_name');
    });
  });

  describe('F14 — Saran & Kesan (Course Feedback)', () => {
    it('POST /api/feedback saves user impression and rating', async () => {
      const res = await request(app)
        .post('/api/feedback')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          impression: 'Materi arsitektur keamanan ujian sangat aplikatif dan membuka wawasan.',
          suggestion: 'Perbanyak studi kasus implementasi sensor perangkat.',
          rating: 5,
        });

      expect(res.status).toBe(201);
      expect(res.body.feedback.rating).toBe(5);
    });

    it('POST /api/feedback rejects invalid rating outside 1..5', async () => {
      const res = await request(app)
        .post('/api/feedback')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          impression: 'Terlalu pendek',
          rating: 6,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('GET /api/feedback/me returns logged in student feedbacks', async () => {
      const res = await request(app)
        .get('/api/feedback/me')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.feedbacks)).toBe(true);
      expect(res.body.feedbacks.length).toBeGreaterThanOrEqual(1);
    });

    it('GET /api/feedback allows lecturer to view all feedbacks', async () => {
      const res = await request(app)
        .get('/api/feedback')
        .set('Authorization', `Bearer ${lecturerToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.feedbacks)).toBe(true);
    });

    it('GET /api/feedback forbids students from accessing all feedbacks', async () => {
      const res = await request(app)
        .get('/api/feedback')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(403);
    });
  });
});
