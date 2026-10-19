import { Router, Request, Response } from 'express';
import { z } from 'zod';
import db from '../db/knex';
import { jwtMiddleware, requireRole } from '../middleware/auth.middleware';
import { essayGradingQueue } from '../jobs/essay_queue';

const router = Router();

const updateGradeSchema = z.object({
  teacher_score: z.number().min(0),
  teacher_comment: z.string().optional().nullable(),
  finalize: z.boolean().default(true),
});

// GET /api/reviews — Antrean review essay untuk dosen (PRD 8)
router.get('/', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { status, exam_id } = req.query;

    let query = db('essay_grades')
      .join('attempt_answers', 'essay_grades.answer_id', 'attempt_answers.id')
      .join('exam_attempts', 'attempt_answers.attempt_id', 'exam_attempts.id')
      .join('exams', 'exam_attempts.exam_id', 'exams.id')
      .join('courses', 'exams.course_id', 'courses.id')
      .join('users', 'exam_attempts.student_id', 'users.id')
      .join('questions', 'attempt_answers.question_id', 'questions.id')
      .select(
        'essay_grades.id as grade_id',
        'essay_grades.answer_id',
        'essay_grades.ai_score',
        'essay_grades.ai_json',
        'essay_grades.ai_model',
        'essay_grades.confidence',
        'essay_grades.flags',
        'essay_grades.status',
        'essay_grades.teacher_score',
        'essay_grades.teacher_comment',
        'essay_grades.final_score',
        'essay_grades.updated_at',
        'attempt_answers.answer_text',
        'questions.id as question_id',
        'questions.body as question_text',
        'questions.rubric',
        'questions.model_answer',
        'questions.max_score',
        'exams.id as exam_id',
        'exams.title as exam_title',
        'courses.name as course_name',
        'courses.code as course_code',
        'users.id as student_id',
        'users.name as student_name',
        'users.nim as student_nim'
      )
      .orderBy('essay_grades.updated_at', 'desc');

    if (status && typeof status === 'string') {
      query = query.where('essay_grades.status', status);
    }

    if (exam_id && typeof exam_id === 'string') {
      query = query.where('exams.id', exam_id);
    }

    const reviews = await query;

    // Parse jsonb fields if needed
    const mapped = reviews.map((r) => ({
      ...r,
      flags: typeof r.flags === 'string' ? JSON.parse(r.flags) : r.flags,
      ai_json: typeof r.ai_json === 'string' ? JSON.parse(r.ai_json) : r.ai_json,
    }));

    return res.json({ reviews: mapped });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// PATCH /api/essay-grades/:id — Ubah nilai dan/atau finalisasi nilai essay (PRD 8)
export const updateEssayGradeHandler = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const lecturerId = (req as any).user.id;
    const body = updateGradeSchema.parse(req.body);

    const grade = await db('essay_grades')
      .join('attempt_answers', 'essay_grades.answer_id', 'attempt_answers.id')
      .join('questions', 'attempt_answers.question_id', 'questions.id')
      .where('essay_grades.id', id)
      .select(
        'essay_grades.*',
        'attempt_answers.attempt_id',
        'questions.max_score'
      )
      .first();

    if (!grade) {
      return res.status(404).json({
        error: { code: 'GRADE_NOT_FOUND', message: 'Data penilaian essay tidak ditemukan' },
      });
    }

    // Clamp teacher_score to question max_score
    const maxScore = Number(grade.max_score) || 100;
    const clampedScore = Math.max(0, Math.min(maxScore, body.teacher_score));

    const finalStatus = body.finalize ? 'finalized' : grade.status;
    const finalScore = body.finalize ? clampedScore : grade.final_score;

    const [updated] = await db('essay_grades')
      .where({ id })
      .update({
        teacher_score: clampedScore,
        teacher_comment: body.teacher_comment ?? null,
        final_score: finalScore,
        status: finalStatus,
        graded_by: lecturerId,
        updated_at: new Date(),
      })
      .returning('*');

    // Trigger attempt status check
    if (body.finalize) {
      await essayGradingQueue.checkAndUpdateAttemptStatus(grade.attempt_id, true);
    }

    return res.json({
      message: body.finalize ? 'Nilai essay berhasil difinalisasi' : 'Nilai essay diperbarui',
      grade: updated,
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
};

export const essayGradesRouter = Router();
essayGradesRouter.patch('/:id', jwtMiddleware, requireRole('lecturer'), updateEssayGradeHandler);

export default router;
