import { Router, Request, Response } from 'express';
import { z } from 'zod';
import crypto from 'crypto';
import db from '../db/knex';
import { jwtMiddleware, requireRole } from '../middleware/auth.middleware';
import { essayGradingQueue } from '../jobs/essay_queue';
import { appendBlock } from '../chain/blockchain.service';

const router = Router();

const updateGradeSchema = z.object({
  teacher_score: z.number().min(0),
  teacher_comment: z.string().optional().nullable(),
  finalize: z.boolean().default(true),
});

const finalizeStudentEssaysSchema = z.object({
  total_essay_score: z.number().min(0),
  teacher_comment: z.string().optional().nullable(),
});

// GET /api/reviews — Antrean review essay untuk dosen (flat per-question, PRD 8)
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
        'exam_attempts.id as attempt_id',
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

    if (status && typeof status === 'string' && status !== 'ALL') {
      query = query.where('essay_grades.status', status);
    }

    if (exam_id && typeof exam_id === 'string') {
      query = query.where('exams.id', exam_id);
    }

    const reviews = await query;

    // Parse jsonb fields and numeric types
    const mapped = reviews.map((r) => ({
      ...r,
      max_score: r.max_score != null ? Number(r.max_score) : 0,
      ai_score: r.ai_score != null ? Number(r.ai_score) : null,
      teacher_score: r.teacher_score != null ? Number(r.teacher_score) : null,
      final_score: r.final_score != null ? Number(r.final_score) : null,
      flags: typeof r.flags === 'string' ? JSON.parse(r.flags) : (r.flags || []),
      ai_json: typeof r.ai_json === 'string' ? JSON.parse(r.ai_json) : r.ai_json,
    }));

    return res.json({ reviews: mapped });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// GET /api/reviews/by-student — Antrean review essay dikelompokkan per mahasiswa
router.get('/by-student', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
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
        'attempt_answers.id as attempt_answer_id',
        'attempt_answers.answer_text',
        'exam_attempts.id as attempt_id',
        'exam_attempts.status as attempt_status',
        'exam_attempts.total_score as attempt_total_score',
        'exam_attempts.submitted_at',
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
      .orderBy('exam_attempts.submitted_at', 'desc')
      .orderBy('essay_grades.updated_at', 'desc');

    if (exam_id && typeof exam_id === 'string') {
      query = query.where('exams.id', exam_id);
    }

    const reviews = await query;

    // Group rows by attempt_id
    const attemptsMap = new Map<string, any>();
    for (const r of reviews) {
      const attId = r.attempt_id;
      if (!attemptsMap.has(attId)) {
        attemptsMap.set(attId, {
          attempt_id: attId,
          exam_id: r.exam_id,
          exam_title: r.exam_title,
          course_name: r.course_name,
          course_code: r.course_code,
          student_id: r.student_id,
          student_name: r.student_name,
          student_nim: r.student_nim,
          attempt_status: r.attempt_status,
          submitted_at: r.submitted_at,
          max_essay_score: 0,
          ai_essay_score_sum: 0,
          final_essay_score_sum: 0,
          all_finalized: true,
          has_needs_review: false,
          teacher_comment: r.teacher_comment || null,
          essays: [],
        });
      }

      const group = attemptsMap.get(attId);
      const maxScore = r.max_score != null ? Number(r.max_score) : 0;
      const aiScore = r.ai_score != null ? Number(r.ai_score) : null;
      const teacherScore = r.teacher_score != null ? Number(r.teacher_score) : null;
      const finalScore = r.final_score != null ? Number(r.final_score) : null;

      let flags: any[] = [];
      if (typeof r.flags === 'string') {
        try { flags = JSON.parse(r.flags); } catch (_) {}
      } else if (Array.isArray(r.flags)) {
        flags = r.flags;
      }

      let aiJson: any = null;
      if (typeof r.ai_json === 'string') {
        try { aiJson = JSON.parse(r.ai_json); } catch (_) {}
      } else if (r.ai_json) {
        aiJson = r.ai_json;
      }

      group.max_essay_score += maxScore;
      if (aiScore != null) group.ai_essay_score_sum += aiScore;
      if (finalScore != null) group.final_essay_score_sum += finalScore;
      if (r.teacher_comment && !group.teacher_comment) {
        group.teacher_comment = r.teacher_comment;
      }

      if (r.status !== 'finalized') {
        group.all_finalized = false;
      }
      if (r.status === 'needs_review' || r.status === 'pending_manual') {
        group.has_needs_review = true;
      }

      group.essays.push({
        grade_id: r.grade_id,
        answer_id: r.answer_id,
        question_id: r.question_id,
        question_text: r.question_text,
        student_answer: r.answer_text,
        max_score: maxScore,
        ai_score: aiScore,
        ai_json: aiJson,
        ai_model: r.ai_model,
        confidence: r.confidence,
        flags,
        teacher_score: teacherScore,
        teacher_comment: r.teacher_comment,
        final_score: finalScore,
        status: r.status,
      });
    }

    // Also fetch MCQ scores for these attempts to show full student breakdown
    const attemptIds = Array.from(attemptsMap.keys());
    if (attemptIds.length > 0) {
      const distinctExamIds = Array.from(new Set(Array.from(attemptsMap.values()).map((g: any) => g.exam_id)));
      const mcqQuestions = await db('exam_questions')
        .join('questions', 'exam_questions.question_id', 'questions.id')
        .whereIn('exam_questions.exam_id', distinctExamIds)
        .where('questions.type', 'mcq')
        .select('exam_questions.exam_id', 'questions.id', 'questions.correct_option', 'questions.max_score');

      const mcqAnswers = await db('attempt_answers')
        .whereIn('attempt_id', attemptIds)
        .select('attempt_id', 'question_id', 'selected_option');

      for (const group of attemptsMap.values()) {
        const examMcqs = mcqQuestions.filter((q: any) => q.exam_id === group.exam_id);
        const myAnswers = mcqAnswers.filter((a: any) => a.attempt_id === group.attempt_id);

        let mcqTotal = 0;
        let maxMcq = 0;
        for (const q of examMcqs) {
          const qMax = Number(q.max_score) || 0;
          maxMcq += qMax;
          const ans = myAnswers.find((a: any) => a.question_id === q.id);
          if (ans && ans.selected_option && q.correct_option && ans.selected_option.trim().toUpperCase() === q.correct_option.trim().toUpperCase()) {
            mcqTotal += qMax;
          }
        }
        group.mcq_score = Math.round(mcqTotal * 100) / 100;
        group.max_mcq_score = Math.round(maxMcq * 100) / 100;
        group.max_essay_score = Math.round(group.max_essay_score * 100) / 100;
        group.ai_essay_score_sum = Math.round(group.ai_essay_score_sum * 100) / 100;
        group.final_essay_score_sum = Math.round(group.final_essay_score_sum * 100) / 100;
        group.total_score = group.all_finalized
          ? Math.round((mcqTotal + group.final_essay_score_sum) * 100) / 100
          : Math.round(mcqTotal * 100) / 100;

        group.overall_status = group.all_finalized
          ? 'finalized'
          : (group.has_needs_review ? 'needs_review' : 'ai_graded');
        group.needs_review = !group.all_finalized;
      }
    }

    let students = Array.from(attemptsMap.values());

    if (status && typeof status === 'string' && status !== 'ALL') {
      students = students.filter((s: any) => s.overall_status === status);
    }

    return res.json({ students });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// POST /api/reviews/attempts/:attemptId/finalize — Finalisasi nilai seluruh essay dalam 1 siswa sekaligus
router.post('/attempts/:attemptId/finalize', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { attemptId } = req.params;
    const lecturerId = (req as any).user.id;
    const body = finalizeStudentEssaysSchema.parse(req.body);

    const attempt = await db('exam_attempts').where({ id: attemptId }).first();
    if (!attempt) {
      return res.status(404).json({
        error: { code: 'ATTEMPT_NOT_FOUND', message: 'Attempt ujian tidak ditemukan' },
      });
    }

    const essayAnswers = await db('attempt_answers')
      .join('questions', 'attempt_answers.question_id', 'questions.id')
      .leftJoin('essay_grades', 'attempt_answers.id', 'essay_grades.answer_id')
      .where('attempt_answers.attempt_id', attemptId)
      .where('questions.type', 'essay')
      .select(
        'attempt_answers.id as answer_id',
        'questions.id as question_id',
        'questions.max_score',
        'essay_grades.id as grade_id'
      );

    if (essayAnswers.length === 0) {
      return res.status(400).json({
        error: { code: 'NO_ESSAYS_FOUND', message: 'Tidak ada soal essay pada attempt ini' },
      });
    }

    const maxEssayScore = essayAnswers.reduce((sum: number, ea: any) => sum + (Number(ea.max_score) || 0), 0);
    const clampedTotal = Math.max(0, Math.min(maxEssayScore, body.total_essay_score));

    // Proportionally distribute clampedTotal among essay questions
    let distributed = 0;
    const now = new Date();
    for (let i = 0; i < essayAnswers.length; i++) {
      const item = essayAnswers[i];
      let assignedScore = 0;
      if (i === essayAnswers.length - 1) {
        assignedScore = Math.round((clampedTotal - distributed) * 100) / 100;
      } else {
        const ratio = maxEssayScore > 0 ? (Number(item.max_score) / maxEssayScore) : (1 / essayAnswers.length);
        assignedScore = Math.round(clampedTotal * ratio * 100) / 100;
        distributed += assignedScore;
      }

      if (item.grade_id) {
        await db('essay_grades')
          .where({ id: item.grade_id })
          .update({
            teacher_score: assignedScore,
            final_score: assignedScore,
            teacher_comment: body.teacher_comment ?? null,
            status: 'finalized',
            graded_by: lecturerId,
            updated_at: now,
          });
      } else {
        await db('essay_grades').insert({
          answer_id: item.answer_id,
          teacher_score: assignedScore,
          final_score: assignedScore,
          teacher_comment: body.teacher_comment ?? null,
          status: 'finalized',
          graded_by: lecturerId,
          flags: JSON.stringify([]),
          updated_at: now,
        });
      }
    }

    // Compute MCQ score
    const mcqQuestions = await db('exam_questions')
      .join('questions', 'exam_questions.question_id', 'questions.id')
      .where('exam_questions.exam_id', attempt.exam_id)
      .where('questions.type', 'mcq')
      .select('questions.id', 'questions.correct_option', 'questions.max_score');

    const mcqAnswers = await db('attempt_answers')
      .where({ attempt_id: attemptId })
      .select('question_id', 'selected_option');

    let mcqTotal = 0;
    for (const q of mcqQuestions) {
      const ans = mcqAnswers.find((a: any) => a.question_id === q.id);
      if (ans && ans.selected_option && q.correct_option && ans.selected_option.trim().toUpperCase() === q.correct_option.trim().toUpperCase()) {
        mcqTotal += Number(q.max_score);
      }
    }

    const finalTotalScore = Math.round((mcqTotal + clampedTotal) * 100) / 100;

    await db('exam_attempts')
      .where({ id: attemptId })
      .update({
        total_score: finalTotalScore,
        status: 'graded',
      });

    // Blockchain RESULT block
    try {
      const studentRef = crypto.createHash('sha256').update(attempt.student_id).digest('hex');
      await appendBlock('RESULT', {
        attempt_id: attemptId,
        exam_id: attempt.exam_id,
        student_ref: studentRef,
        final_score: finalTotalScore,
        graded_by: lecturerId,
        finalized_at: now.toISOString(),
      });
    } catch (blockErr) {
      console.error('[Blockchain] Error creating block on student essay finalize:', blockErr);
    }

    return res.json({
      message: 'Penilaian essay untuk siswa berhasil difinalisasi',
      attempt_id: attemptId,
      mcq_score: mcqTotal,
      essay_score: clampedTotal,
      total_score: finalTotalScore,
      status: 'graded',
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

// PATCH /api/essay-grades/:id — Ubah nilai dan/atau finalisasi nilai essay per butir soal (PRD 8)
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
