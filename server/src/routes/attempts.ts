import { Router, Request, Response } from 'express';
import { z } from 'zod';
import db from '../db/knex';
import { jwtMiddleware, requireRole } from '../middleware/auth.middleware';
import {
  calculateServerDeadline,
  isDeadlineExceeded,
  randomizeQuestionsForAttempt,
  gradeMultipleChoice,
} from '../services/attempt.service';
import {
  evaluateViolation,
  calculateDistanceMeters,
} from '../services/violation.service';
import crypto from 'crypto';
import { essayGradingQueue } from '../jobs/essay_queue';
import { appendBlock } from '../chain/blockchain.service';

const router = Router();

const GRACE_SECONDS = parseInt(process.env.GRACE_SECONDS || '60', 10);

// Validation Schemas
const syncAnswersSchema = z.object({
  answers: z.array(
    z.object({
      question_id: z.string().uuid(),
      selected_option: z.string().nullable().optional(),
      answer_text: z.string().max(5000).nullable().optional(),
    })
  ),
});

const recordViolationSchema = z.object({
  type: z.string().min(1),
  severity: z.enum(['warn', 'critical']),
  detail: z.record(z.string(), z.any()).optional(),
  occurred_at: z.string().datetime().optional(),
});

// ---------- Attempt Routes ----------

// POST /api/exams/:id/attempts — Mulai ujian / resume attempt (mahasiswa)
export const startAttemptHandler = async (req: Request, res: Response) => {
  try {
    const { id: examId } = req.params;
    const studentId = (req as any).user.id;
    const now = new Date();

    const exam = await db('exams')
      .join('courses', 'exams.course_id', 'courses.id')
      .select('exams.*', 'courses.name as course_name', 'courses.code as course_code')
      .where('exams.id', examId)
      .first();

    if (!exam || exam.status !== 'published') {
      return res.status(404).json({
        error: { code: 'EXAM_NOT_FOUND', message: 'Ujian tidak ditemukan atau belum dipublikasikan' },
      });
    }

    // Check enrollment
    const enrollment = await db('enrollments')
      .where({ exam_id: examId, student_id: studentId })
      .first();
    if (!enrollment) {
      return res.status(403).json({
        error: { code: 'NOT_ENROLLED', message: 'Anda belum terdaftar untuk ujian ini' },
      });
    }

    // Geofence check if exam requires geofence
    if (exam.require_geofence && exam.venue_lat != null && exam.venue_lng != null) {
      const { latitude, longitude } = req.body || {};
      if (latitude === undefined || longitude === undefined) {
        return res.status(400).json({
          error: {
            code: 'GEOFENCE_LOCATION_REQUIRED',
            message: 'Koordinat lokasi GPS (latitude & longitude) wajib dikirimkan untuk ujian ber-geofence.',
          },
        });
      }
      const distance = calculateDistanceMeters(
        Number(latitude),
        Number(longitude),
        Number(exam.venue_lat),
        Number(exam.venue_lng)
      );
      const radius = Number(exam.venue_radius_m) || 100;
      if (distance > radius) {
        return res.status(403).json({
          error: {
            code: 'OUTSIDE_GEOFENCE',
            message: `Anda berada di luar radius lokasi ujian (${Math.round(distance)}m > ${radius}m)`,
            distance_meters: Math.round(distance),
            max_radius: radius,
          },
        });
      }
    }

    // Check if attempt already exists
    let isNew = false;
    let attempt = await db('exam_attempts')
      .where({ exam_id: examId, student_id: studentId })
      .first();

    if (attempt) {
      if (attempt.status !== 'in_progress') {
        return res.status(400).json({
          error: { code: 'ATTEMPT_ALREADY_FINISHED', message: 'Ujian ini sudah diselesaikan' },
        });
      }
    } else {
      isNew = true;
      // Calculate server deadline: min(now + duration, end_at)
      const serverDeadline = calculateServerDeadline(
        now,
        exam.duration_min,
        new Date(exam.end_at)
      );

      const seed = Math.floor(Math.random() * 1000000000) + 1;

      const [newAttempt] = await db('exam_attempts')
        .insert({
          exam_id: examId,
          student_id: studentId,
          started_at: now,
          server_deadline: serverDeadline,
          status: 'in_progress',
          seed,
        })
        .returning('*');

      attempt = newAttempt;
    }

    // Fetch questions assigned to this exam
    const rawQuestions = await db('exam_questions')
      .join('questions', 'exam_questions.question_id', 'questions.id')
      .select(
        'questions.id', 'questions.type', 'questions.body',
        'questions.options', 'questions.max_score',
        'exam_questions.position'
      )
      .where('exam_questions.exam_id', examId)
      .orderBy('exam_questions.position');

    // Deterministically randomize questions & options based on attempt seed
    const questions = randomizeQuestionsForAttempt(rawQuestions, Number(attempt.seed));

    // Fetch existing saved answers
    const existingAnswers = await db('attempt_answers')
      .where({ attempt_id: attempt.id })
      .select('question_id', 'selected_option', 'answer_text', 'updated_at');

    return res.status(isNew ? 201 : 200).json({
      attempt,
      exam: {
        id: exam.id,
        title: exam.title,
        duration_min: exam.duration_min,
        require_biometric: exam.require_biometric,
        require_geofence: exam.require_geofence,
        max_critical: exam.max_critical,
        course_name: exam.course_name,
        course_code: exam.course_code,
      },
      questions,
      answers: existingAnswers,
      server_time: now.toISOString(),
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
};

// PUT /api/attempts/:id/answers — Sinkronisasi draft jawaban (batch)
router.put('/:id/answers', jwtMiddleware, requireRole('student'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const studentId = (req as any).user.id;
    const now = new Date();
    const data = syncAnswersSchema.parse(req.body);

    const attempt = await db('exam_attempts')
      .where({ id, student_id: studentId })
      .first();

    if (!attempt) {
      return res.status(404).json({
        error: { code: 'ATTEMPT_NOT_FOUND', message: 'Attempt ujian tidak ditemukan' },
      });
    }

    if (attempt.status !== 'in_progress') {
      return res.status(400).json({
        error: { code: 'ATTEMPT_NOT_ACTIVE', message: 'Ujian sudah diserahkan atau dihentikan' },
      });
    }

    // Authoritative deadline check: server_deadline + GRACE_SECONDS
    if (isDeadlineExceeded(now, new Date(attempt.server_deadline), GRACE_SECONDS)) {
      return res.status(403).json({
        error: {
          code: 'DEADLINE_EXCEEDED',
          message: 'Batas waktu ujian telah habis. Jawaban baru tidak dapat disimpan.',
        },
      });
    }

    // Upsert answers
    for (const ans of data.answers) {
      const existing = await db('attempt_answers')
        .where({ attempt_id: id, question_id: ans.question_id })
        .first();

      if (existing) {
        await db('attempt_answers')
          .where({ id: existing.id })
          .update({
            selected_option: ans.selected_option || null,
            answer_text: ans.answer_text || null,
            updated_at: now,
          });
      } else {
        await db('attempt_answers').insert({
          attempt_id: id,
          question_id: ans.question_id,
          selected_option: ans.selected_option || null,
          answer_text: ans.answer_text || null,
          updated_at: now,
        });
      }
    }

    return res.json({
      message: 'Draft jawaban berhasil disinkronkan',
      saved_count: data.answers.length,
      server_time: now.toISOString(),
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

// POST /api/attempts/:id/submit — Kumpulkan ujian & auto-grading MCQ (mahasiswa)
router.post('/:id/submit', jwtMiddleware, requireRole('student'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const studentId = (req as any).user.id;
    const now = new Date();

    const attempt = await db('exam_attempts')
      .where({ id, student_id: studentId })
      .first();

    if (!attempt) {
      return res.status(404).json({
        error: { code: 'ATTEMPT_NOT_FOUND', message: 'Attempt ujian tidak ditemukan' },
      });
    }

    if (attempt.status !== 'in_progress') {
      return res.status(400).json({
        error: { code: 'ALREADY_SUBMITTED', message: 'Ujian sudah pernah dikumpulkan' },
      });
    }

    // Fetch questions with correct_option for grading
    const questions = await db('exam_questions')
      .join('questions', 'exam_questions.question_id', 'questions.id')
      .where('exam_questions.exam_id', attempt.exam_id)
      .select('questions.id', 'questions.type', 'questions.max_score', 'questions.correct_option');

    // Fetch student's submitted answers
    const answers = await db('attempt_answers')
      .where({ attempt_id: id })
      .select('question_id', 'selected_option', 'answer_text');

    // Grade Multiple Choice questions
    const grading = gradeMultipleChoice(questions, answers);

    // If only MCQ, status becomes 'graded'; if has essay, status is 'submitted'
    const newStatus = grading.hasEssay ? 'submitted' : 'graded';

    const [updatedAttempt] = await db('exam_attempts')
      .where({ id })
      .update({
        status: newStatus,
        submitted_at: now,
        total_score: grading.totalMcqScore,
      })
      .returning('*');

    // Trigger AI grading queue for essay answers (PRD F07)
    if (grading.hasEssay) {
      const essayAnswers = await db('attempt_answers')
        .join('questions', 'attempt_answers.question_id', 'questions.id')
        .where('attempt_answers.attempt_id', id)
        .where('questions.type', 'essay')
        .select('attempt_answers.id as answer_id');

      for (const ea of essayAnswers) {
        essayGradingQueue.enqueue(ea.answer_id);
      }
    }

    // Append blockchain SUBMISSION block (PRD F16)
    try {
      const studentRef = crypto.createHash('sha256').update(studentId).digest('hex');
      const answersHash = crypto.createHash('sha256').update(JSON.stringify(answers)).digest('hex');
      await appendBlock('SUBMISSION', {
        attempt_id: id,
        exam_id: attempt.exam_id,
        student_ref: studentRef,
        answers_hash: answersHash,
        submitted_at: now.toISOString(),
      });

      if (!grading.hasEssay) {
        await appendBlock('RESULT', {
          attempt_id: id,
          exam_id: attempt.exam_id,
          student_ref: studentRef,
          final_score: grading.totalMcqScore,
          graded_by: 'system_mcq_auto_grader',
          finalized_at: now.toISOString(),
        });
      }
    } catch (blockErr) {
      console.error('[Blockchain] Error creating block on submit:', blockErr);
    }

    return res.json({
      message: 'Ujian berhasil dikumpulkan',
      attempt: {
        id: updatedAttempt.id,
        status: updatedAttempt.status,
        submitted_at: updatedAttempt.submitted_at,
        total_score: updatedAttempt.total_score,
        has_essay: grading.hasEssay,
      },
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// Helper to fetch attempt result data for student or lecturer
export const fetchAttemptResultData = async (attemptId: string, userId: string, userRole: string) => {
  const attempt = await db('exam_attempts')
    .join('exams', 'exam_attempts.exam_id', 'exams.id')
    .join('courses', 'exams.course_id', 'courses.id')
    .join('users', 'exam_attempts.student_id', 'users.id')
    .where('exam_attempts.id', attemptId)
    .select(
      'exam_attempts.*',
      'exams.title as exam_title',
      'courses.name as course_name',
      'courses.code as course_code',
      'users.name as student_name',
      'users.nim as student_nim'
    )
    .first();

  if (!attempt) {
    return { errorStatus: 404, errorCode: 'ATTEMPT_NOT_FOUND', errorMessage: 'Hasil ujian tidak ditemukan' };
  }

  // Authorization: owner student or lecturer
  if (userRole === 'student' && attempt.student_id !== userId) {
    return { errorStatus: 403, errorCode: 'FORBIDDEN', errorMessage: 'Anda tidak memiliki akses ke hasil ujian ini' };
  }

  const rawAnswers = await db('attempt_answers')
    .join('questions', 'attempt_answers.question_id', 'questions.id')
    .leftJoin('essay_grades', 'attempt_answers.id', 'essay_grades.answer_id')
    .where('attempt_answers.attempt_id', attemptId)
    .select(
      'attempt_answers.id',
      'attempt_answers.question_id',
      'attempt_answers.selected_option',
      'attempt_answers.answer_text',
      'questions.type',
      'questions.body as question_text',
      'questions.max_score',
      'essay_grades.ai_score',
      'essay_grades.ai_json',
      'essay_grades.confidence',
      'essay_grades.flags',
      'essay_grades.final_score as essay_final_score',
      'essay_grades.status as essay_grade_status',
      'essay_grades.teacher_comment'
    );

  const answers = rawAnswers.map((a) => {
    let aiParsed = null;
    if (a.ai_json) {
      aiParsed = typeof a.ai_json === 'string' ? JSON.parse(a.ai_json) : a.ai_json;
    }
    let flagsParsed = [];
    if (a.flags) {
      flagsParsed = typeof a.flags === 'string' ? JSON.parse(a.flags) : a.flags;
    }

    const isProvisional = a.type === 'essay' && a.essay_grade_status !== 'finalized';

    return {
      id: a.id,
      question_id: a.question_id,
      selected_option: a.selected_option,
      answer_text: a.answer_text,
      type: a.type,
      question_text: a.question_text,
      max_score: a.max_score,
      essay_final_score: a.essay_final_score,
      essay_ai_score: a.ai_score,
      essay_grade_status: a.essay_grade_status,
      is_provisional: isProvisional,
      ai_breakdown: aiParsed,
      flags: flagsParsed,
      teacher_comment: a.teacher_comment,
    };
  });

  return {
    attempt: {
      ...attempt,
      has_essay: answers.some((a) => a.type === 'essay'),
    },
    exam: {
      id: attempt.exam_id,
      title: attempt.exam_title,
      course_name: attempt.course_name,
      course_code: attempt.course_code,
    },
    answers,
  };
};

// GET /api/attempts/:id/result — Hasil ujian & umpan balik
router.get('/:id/result', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const userId = (req as any).user.id;
    const userRole = (req as any).user.role;

    const data = await fetchAttemptResultData(id, userId, userRole);
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

// POST /api/attempts/:id/violations — Catat kejadian pelanggaran sensor / background / geofence
export const recordViolationHandler = async (req: Request, res: Response) => {
  try {
    const { id: attemptId } = req.params;
    const studentId = (req as any).user.id;
    const body = recordViolationSchema.parse(req.body);

    const attempt = await db('exam_attempts')
      .where({ id: attemptId, student_id: studentId })
      .first();

    if (!attempt) {
      return res.status(404).json({
        error: { code: 'ATTEMPT_NOT_FOUND', message: 'Sesi ujian tidak ditemukan' },
      });
    }

    if (attempt.status !== 'in_progress') {
      return res.status(400).json({
        error: { code: 'ATTEMPT_NOT_ACTIVE', message: 'Sesi ujian sudah tidak aktif' },
      });
    }

    const exam = await db('exams').where('id', attempt.exam_id).first();
    const maxCritical = exam?.max_critical ?? 3;

    const evaluation = evaluateViolation(
      attempt.critical_count,
      body.severity,
      maxCritical
    );

    const occurredAt = body.occurred_at ? new Date(body.occurred_at) : new Date();

    const [violation] = await db('violation_events')
      .insert({
        attempt_id: attemptId,
        type: body.type,
        severity: body.severity,
        detail: body.detail ? JSON.stringify(body.detail) : null,
        occurred_at: occurredAt,
      })
      .returning('*');

    const updateData: any = {};
    if (body.severity === 'critical') {
      updateData.critical_count = evaluation.newCriticalCount;
    }
    if (evaluation.isTerminated) {
      updateData.status = 'terminated';
      updateData.submitted_at = new Date();
    }

    if (Object.keys(updateData).length > 0) {
      await db('exam_attempts')
        .where('id', attemptId)
        .update(updateData);
    }

    return res.status(201).json({
      violation,
      critical_count: evaluation.newCriticalCount,
      max_critical: maxCritical,
      is_terminated: evaluation.isTerminated,
      status: evaluation.isTerminated ? 'terminated' : attempt.status,
    });
  } catch (error: any) {
    if (error.name === 'ZodError') {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: error.errors } });
    }
    return res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: error.message } });
  }
};

router.post('/:id/violations', jwtMiddleware, requireRole('student'), recordViolationHandler);

export default router;
