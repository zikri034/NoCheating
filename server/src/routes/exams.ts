import { Router, Request, Response } from 'express';
import { z } from 'zod';
import db from '../db/knex';
import { jwtMiddleware, requireRole } from '../middleware/auth.middleware';
import { startAttemptHandler, fetchAttemptResultData } from './attempts';

const router = Router();

// ---------- Validation Schemas ----------

const createExamSchema = z.object({
  course_id: z.string().uuid(),
  title: z.string().min(3).max(200),
  description: z.string().max(2000).nullish(),
  start_at: z.string().datetime(),
  end_at: z.string().datetime(),
  duration_min: z.number().int().positive(),
  fee_idr: z.number().int().min(0).nullish(),
  venue_lat: z.number().min(-90).max(90).nullish(),
  venue_lng: z.number().min(-180).max(180).nullish(),
  venue_radius_m: z.number().int().positive().nullish(),
  require_biometric: z.boolean().default(false),
  require_geofence: z.boolean().default(false),
  max_critical: z.number().int().positive().default(3),
  ai_auto_finalize: z.boolean().default(false),
  status: z.enum(['draft', 'published']).default('draft'),
  question_ids: z.array(z.string().uuid()).optional(),
});

const updateExamSchema = createExamSchema.partial();

const assignQuestionsSchema = z.object({
  question_ids: z.array(z.string().uuid()).min(1),
});

// ---------- Exam Routes ----------

// GET /api/exams — list with search, filter, pagination
router.get('/', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const { search, status, page = '1', limit = '50' } = req.query;
    const pageNum = Math.max(1, parseInt(page as string, 10) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(limit as string, 10) || 50));
    const offset = (pageNum - 1) * pageSize;

    const userId = (req as any).user?.id;
    const userRole = (req as any).user?.role;

    let query = db('exams')
      .join('courses', 'exams.course_id', 'courses.id')
      .join('users', 'exams.created_by', 'users.id')
      .leftJoin('enrollments', function () {
        this.on('exams.id', '=', 'enrollments.exam_id')
          .andOn('enrollments.student_id', '=', db.raw('?', [userId || '00000000-0000-0000-0000-000000000000']));
      })
      .leftJoin('exam_attempts', function () {
        this.on('exams.id', '=', 'exam_attempts.exam_id')
          .andOn('exam_attempts.student_id', '=', db.raw('?', [userId || '00000000-0000-0000-0000-000000000000']));
      })
      .select(
        'exams.id', 'exams.course_id', 'exams.title', 'exams.description',
        'exams.start_at', 'exams.end_at', 'exams.duration_min',
        'exams.fee_idr', 'exams.venue_lat', 'exams.venue_lng',
        'exams.venue_radius_m', 'exams.require_biometric',
        'exams.require_geofence', 'exams.max_critical',
        'exams.ai_auto_finalize', 'exams.status',
        'courses.name as course_name', 'courses.code as course_code',
        'users.name as lecturer_name',
        db.raw('CASE WHEN enrollments.student_id IS NOT NULL THEN true ELSE false END as is_enrolled'),
        'exam_attempts.id as my_attempt_id',
        'exam_attempts.status as my_attempt_status',
        'exam_attempts.total_score as my_attempt_score'
      );

    // Search by title, course name, or lecturer name (trigram)
    if (search && typeof search === 'string' && search.trim()) {
      const term = `%${search.trim()}%`;
      query = query.where(function () {
        this.whereILike('exams.title', term)
          .orWhereILike('courses.name', term)
          .orWhereILike('users.name', term);
      });
    }

    // Filter by status
    if (status && typeof status === 'string' && ['draft', 'published'].includes(status)) {
      query = query.where('exams.status', status);
    }

    // Non-lecturer users only see published exams
    if (userRole !== 'lecturer') {
      query = query.where('exams.status', 'published');
    }

    const countResult = await query.clone().clearSelect().count('exams.id as total').first();
    const total = parseInt((countResult as any)?.total || '0', 10);

    const exams = await query
      .orderBy('exams.start_at', 'desc')
      .limit(pageSize)
      .offset(offset);

    return res.json({
      exams,
      pagination: {
        page: pageNum,
        limit: pageSize,
        total,
        totalPages: Math.ceil(total / pageSize),
      },
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// GET /api/exams/:id — detail
router.get('/:id', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const userId = (req as any).user?.id;
    const userRole = (req as any).user?.role;

    const exam = await db('exams')
      .join('courses', 'exams.course_id', 'courses.id')
      .join('users', 'exams.created_by', 'users.id')
      .select(
        'exams.*',
        'courses.name as course_name', 'courses.code as course_code',
        'users.name as lecturer_name'
      )
      .where('exams.id', id)
      .first();

    if (!exam) {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan' },
      });
    }

    // Check if current user is enrolled
    const isEnrolled = userId
      ? !!(await db('enrollments').where({ exam_id: id, student_id: userId }).first())
      : false;

    // Check student's attempt if user exists
    let myAttempt = null;
    if (userId) {
      myAttempt = await db('exam_attempts')
        .where({ exam_id: id, student_id: userId })
        .first();
    }

    // Get questions for this exam
    let questionsQuery = db('exam_questions')
      .join('questions', 'exam_questions.question_id', 'questions.id')
      .where('exam_questions.exam_id', id)
      .orderBy('exam_questions.position');

    // Students must NOT see correct_option, rubric, model_answer (PRD Section 9)
    if (userRole === 'lecturer') {
      questionsQuery = questionsQuery.select('questions.*', 'exam_questions.position');
    } else {
      questionsQuery = questionsQuery.select(
        'questions.id', 'questions.type', 'questions.body',
        'questions.options', 'questions.max_score',
        'exam_questions.position'
      );
    }

    const questions = await questionsQuery;

    // Get enrollment count
    const enrollmentCount = await db('enrollments')
      .where({ exam_id: id })
      .count('student_id as total')
      .first();

    return res.json({
      exam: {
        ...exam,
        is_enrolled: isEnrolled,
        my_attempt_id: myAttempt?.id ?? null,
        my_attempt_status: myAttempt?.status ?? null,
        my_attempt_score: myAttempt?.total_score ?? null,
      },
      my_attempt: myAttempt,
      questions,
      enrollment_count: parseInt((enrollmentCount as any)?.total || '0', 10),
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// GET /api/exams/:id/my-result — Hasil pengerjaan ujian mahasiswa saat ini
router.get('/:id/my-result', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const { id: examId } = req.params;
    const userId = (req as any).user.id;
    const userRole = (req as any).user.role;

    const attempt = await db('exam_attempts')
      .where({ exam_id: examId, student_id: userId })
      .first();

    if (!attempt) {
      return res.status(404).json({
        error: { code: 'ATTEMPT_NOT_FOUND', message: 'Anda belum memiliki riwayat pengerjaan ujian ini' },
      });
    }

    const data = await fetchAttemptResultData(attempt.id, userId, userRole);
    if ('errorStatus' in data) {
      return res.status(data.errorStatus!).json({
        error: { code: data.errorCode, message: data.errorMessage },
      });
    }

    return res.json(data);
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// POST /api/exams — create (lecturer only)
router.post('/', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const data = createExamSchema.parse(req.body);
    const userId = (req as any).user.id;

    // Verify course exists and belongs to this lecturer
    const course = await db('courses').where({ id: data.course_id }).first();
    if (!course) {
      return res.status(404).json({
        error: { code: 'COURSE_NOT_FOUND', message: 'Mata kuliah tidak ditemukan' },
      });
    }

    const { question_ids, ...examData } = data;
    const [exam] = await db('exams').insert({
      ...examData,
      created_by: userId,
    }).returning('*');

    if (question_ids && question_ids.length > 0) {
      await db('exam_questions').insert(
        question_ids.map((qid: string, i: number) => ({
          exam_id: exam.id,
          question_id: qid,
          position: i + 1,
        }))
      );
    }

    const fullExam = await db('exams')
      .join('courses', 'exams.course_id', 'courses.id')
      .join('users', 'exams.created_by', 'users.id')
      .select(
        'exams.*',
        'courses.name as course_name',
        'courses.code as course_code',
        'users.name as lecturer_name'
      )
      .where('exams.id', exam.id)
      .first();

    return res.status(201).json({ exam: fullExam || exam });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: error.issues[0].message },
      });
    }
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// PATCH /api/exams/:id — update (lecturer only)
router.patch('/:id', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const data = updateExamSchema.parse(req.body);
    const userId = (req as any).user.id;

    const existing = await db('exams').where({ id, created_by: userId }).first();
    if (!existing) {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan atau Anda bukan pemilik' },
      });
    }

    const [updated] = await db('exams')
      .where({ id })
      .update(data)
      .returning('*');

    return res.json({ exam: updated });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: error.issues[0].message },
      });
    }
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// DELETE /api/exams/:id — delete exam (lecturer only)
router.delete('/:id', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const userId = (req as any).user.id;

    const exam = await db('exams').where({ id, created_by: userId }).first();
    if (!exam) {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan atau Anda bukan pemilik' },
      });
    }

    await db.transaction(async (trx) => {
      await trx('exam_attempts').where({ exam_id: id }).del();
      await trx('exam_questions').where({ exam_id: id }).del();
      await trx('enrollments').where({ exam_id: id }).del();
      await trx('exams').where({ id }).del();
    });

    return res.json({ success: true, message: 'Ujian berhasil dihapus' });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// POST /api/exams/:id/questions — assign questions to exam (lecturer only)
router.post('/:id/questions', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { question_ids } = assignQuestionsSchema.parse(req.body);
    const userId = (req as any).user.id;

    const exam = await db('exams').where({ id, created_by: userId }).first();
    if (!exam) {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan atau Anda bukan pemilik' },
      });
    }

    // Get current max position
    const maxPos = await db('exam_questions')
      .where({ exam_id: id })
      .max('position as maxPos')
      .first();
    let startPos = ((maxPos as any)?.maxPos || 0) + 1;

    // Filter out already assigned questions
    const existing = await db('exam_questions')
      .where({ exam_id: id })
      .whereIn('question_id', question_ids)
      .pluck('question_id');

    const newIds = question_ids.filter((qid: string) => !existing.includes(qid));

    if (newIds.length > 0) {
      await db('exam_questions').insert(
        newIds.map((qid: string, i: number) => ({
          exam_id: id,
          question_id: qid,
          position: startPos + i,
        }))
      );
    }

    return res.status(201).json({
      message: `${newIds.length} soal berhasil ditambahkan ke ujian`,
      added: newIds.length,
      skipped: question_ids.length - newIds.length,
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: error.issues[0].message },
      });
    }
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// POST /api/exams/:id/enroll — student enrolls in exam
router.post('/:id/enroll', jwtMiddleware, requireRole('student'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const studentId = (req as any).user.id;

    const exam = await db('exams').where({ id, status: 'published' }).first();
    if (!exam) {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan atau belum dipublikasikan' },
      });
    }

    // Check if already enrolled
    const existing = await db('enrollments')
      .where({ exam_id: id, student_id: studentId })
      .first();
    if (existing) {
      return res.status(400).json({
        error: { code: 'ALREADY_ENROLLED', message: 'Anda sudah terdaftar di ujian ini' },
      });
    }

    await db('enrollments').insert({
      exam_id: id,
      student_id: studentId,
    });

    return res.status(201).json({ message: 'Berhasil mendaftar ujian' });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// POST /api/exams/:id/attempts — start or resume exam attempt (student only)
router.post('/:id/attempts', jwtMiddleware, requireRole('student'), startAttemptHandler);

// GET /api/exams/:id/monitor — Monitor peserta & timeline pelanggaran (dosen)
router.get('/:id/monitor', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const exam = await db('exams')
      .join('courses', 'exams.course_id', 'courses.id')
      .select(
        'exams.id', 'exams.title', 'exams.status',
        'exams.start_at', 'exams.end_at', 'exams.duration_min',
        'exams.max_critical', 'exams.require_biometric', 'exams.require_geofence',
        'exams.venue_lat', 'exams.venue_lng', 'exams.venue_radius_m',
        'courses.name as course_name', 'courses.code as course_code'
      )
      .where('exams.id', id)
      .first();

    if (!exam) {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan' },
      });
    }

    // Fetch all attempts for this exam with student info
    const attempts = await db('exam_attempts')
      .join('users', 'exam_attempts.student_id', 'users.id')
      .select(
        'exam_attempts.id',
        'exam_attempts.exam_id',
        'exam_attempts.student_id',
        'exam_attempts.started_at',
        'exam_attempts.server_deadline',
        'exam_attempts.submitted_at',
        'exam_attempts.status',
        'exam_attempts.critical_count',
        'exam_attempts.total_score',
        'users.name as student_name',
        'users.nim as student_nim',
        'users.email as student_email'
      )
      .where('exam_attempts.exam_id', id)
      .orderBy('exam_attempts.started_at', 'desc');

    const attemptIds = attempts.map((a) => a.id);
    let violations: any[] = [];
    if (attemptIds.length > 0) {
      violations = await db('violation_events')
        .whereIn('attempt_id', attemptIds)
        .orderBy('occurred_at', 'asc');
    }

    // Group violations by attempt_id
    const violationsByAttempt = violations.reduce((acc, v) => {
      if (!acc[v.attempt_id]) acc[v.attempt_id] = [];
      acc[v.attempt_id].push(v);
      return acc;
    }, {} as Record<string, any[]>);

    const attemptsWithViolations = attempts.map((a) => ({
      ...a,
      violations: violationsByAttempt[a.id] || [],
    }));

    const activeCount = attempts.filter((a) => a.status === 'in_progress').length;
    const terminatedCount = attempts.filter((a) => a.status === 'terminated').length;
    const submittedCount = attempts.filter((a) => a.status === 'submitted' || a.status === 'graded').length;
    const warnEventsCount = violations.filter((v) => v.severity === 'warn').length;
    const criticalEventsCount = violations.filter((v) => v.severity === 'critical').length;

    return res.json({
      exam,
      stats: {
        total_participants: attempts.length,
        active_count: activeCount,
        terminated_count: terminatedCount,
        submitted_count: submittedCount,
        warn_events_count: warnEventsCount,
        critical_events_count: criticalEventsCount,
      },
      participants: attemptsWithViolations,
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

export default router;

