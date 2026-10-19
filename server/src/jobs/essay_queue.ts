import crypto from 'crypto';
import db from '../db/knex';
import { geminiService } from '../ai/gemini.service';
import { appendBlock } from '../chain/blockchain.service';

interface QueueItem {
  answerId: string;
}

export class EssayGradingQueue {
  private queue: QueueItem[] = [];
  private activeCount = 0;
  private readonly concurrency = 2; // PRD F07: in-process antrean konkurensi 2

  public enqueue(answerId: string): void {
    this.queue.push({ answerId });
    this.processNext();
  }

  public enqueueBatch(answerIds: string[]): void {
    for (const id of answerIds) {
      this.queue.push({ answerId: id });
    }
    this.processNext();
  }

  public async drain(): Promise<void> {
    while (this.queue.length > 0 || this.activeCount > 0) {
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
  }

  private async processNext(): Promise<void> {
    if (this.activeCount >= this.concurrency || this.queue.length === 0) {
      return;
    }

    const item = this.queue.shift();
    if (!item) return;

    this.activeCount++;

    try {
      await this.processItem(item.answerId);
    } catch (err) {
      console.error(`[EssayQueue] Error processing answer ${item.answerId}:`, err);
    } finally {
      this.activeCount--;
      this.processNext();
    }
  }

  private async processItem(answerId: string): Promise<void> {
    // 1. Fetch answer along with question details & exam settings
    const row = await db('attempt_answers')
      .join('questions', 'attempt_answers.question_id', 'questions.id')
      .join('exam_attempts', 'attempt_answers.attempt_id', 'exam_attempts.id')
      .join('exams', 'exam_attempts.exam_id', 'exams.id')
      .where('attempt_answers.id', answerId)
      .select(
        'attempt_answers.id as answer_id',
        'attempt_answers.attempt_id',
        'attempt_answers.answer_text',
        'questions.body as question_text',
        'questions.rubric',
        'questions.model_answer',
        'questions.max_score',
        'exams.ai_auto_finalize'
      )
      .first();

    if (!row) {
      return;
    }

    // Ensure essay_grades record exists with 'pending' status
    let gradeRecord = await db('essay_grades').where({ answer_id: answerId }).first();
    if (!gradeRecord) {
      const [newRecord] = await db('essay_grades')
        .insert({
          answer_id: answerId,
          status: 'pending',
          flags: JSON.stringify([]),
        })
        .returning('*');
      gradeRecord = newRecord;
    }

    const studentAnswer = (row.answer_text || '').trim();

    // If student left essay blank
    if (!studentAnswer) {
      await db('essay_grades')
        .where({ id: gradeRecord.id })
        .update({
          ai_score: 0,
          ai_json: JSON.stringify({
            score: 0,
            rubric_breakdown: [],
            strengths: [],
            improvements: ['Jawaban kosong tidak diisi.'],
            feedback: 'Jawaban essay kosong sehingga tidak memperoleh poin.',
            confidence: 'high',
            flags: ['too_short'],
          }),
          ai_model: 'rule-based',
          confidence: 'high',
          flags: JSON.stringify(['too_short']),
          status: row.ai_auto_finalize ? 'finalized' : 'ai_graded',
          final_score: row.ai_auto_finalize ? 0 : null,
          teacher_score: row.ai_auto_finalize ? 0 : null,
          updated_at: new Date(),
        });

      await this.checkAndUpdateAttemptStatus(row.attempt_id, row.ai_auto_finalize);
      return;
    }

    // 2. Perform AI evaluation
    try {
      const { result, model } = await geminiService.gradeEssay({
        questionText: row.question_text,
        rubric: row.rubric || 'Nilai kesesuaian dan kelengkapan konsep.',
        modelAnswer: row.model_answer,
        maxScore: Number(row.max_score) || 10,
        studentAnswer,
      });

      // PRD F07: confidence = low atau flags tidak kosong -> status needs_review; selain itu ai_graded
      const hasFlags = result.flags && result.flags.length > 0;
      const isLowConfidence = result.confidence === 'low';
      let status = isLowConfidence || hasFlags ? 'needs_review' : 'ai_graded';

      let finalScore: number | null = null;
      let teacherScore: number | null = null;

      // Auto finalize if exam has ai_auto_finalize flag enabled AND not flagged for critical review
      if (row.ai_auto_finalize && !hasFlags && !isLowConfidence) {
        status = 'finalized';
        finalScore = result.score;
        teacherScore = result.score;
      }

      await db('essay_grades')
        .where({ id: gradeRecord.id })
        .update({
          ai_score: result.score,
          ai_json: JSON.stringify(result),
          ai_model: model,
          confidence: result.confidence,
          flags: JSON.stringify(result.flags),
          status,
          final_score: finalScore,
          teacher_score: teacherScore,
          updated_at: new Date(),
        });
    } catch (error) {
      console.error(`[EssayQueue] Gemini grading failed for answer ${answerId}:`, error);
      // Fallback: PRD F07: Jika AI gagal setelah retry -> status pending_manual
      await db('essay_grades')
        .where({ id: gradeRecord.id })
        .update({
          status: 'pending_manual',
          updated_at: new Date(),
        });
    }

    // 3. Check if all essays for this attempt are finished
    await this.checkAndUpdateAttemptStatus(row.attempt_id, row.ai_auto_finalize);
  }

  public async checkAndUpdateAttemptStatus(attemptId: string, _aiAutoFinalize?: boolean): Promise<void> {
    // Check all essay questions for this attempt
    const essayGrades = await db('attempt_answers')
      .join('questions', 'attempt_answers.question_id', 'questions.id')
      .leftJoin('essay_grades', 'attempt_answers.id', 'essay_grades.answer_id')
      .where('attempt_answers.attempt_id', attemptId)
      .where('questions.type', 'essay')
      .select(
        'essay_grades.id',
        'essay_grades.status',
        'essay_grades.final_score',
        'essay_grades.ai_score'
      );

    if (essayGrades.length === 0) return;

    // Check if any are still pending evaluation
    const anyPending = essayGrades.some((g) => !g.status || g.status === 'pending');
    if (anyPending) {
      return;
    }

    // If aiAutoFinalize is enabled and all are finalized:
    const allFinalized = essayGrades.every((g) => g.status === 'finalized');
    if (allFinalized) {
      // Calculate total score = existing MCQ score + sum of essay final_scores
      const attempt = await db('exam_attempts').where({ id: attemptId }).first();
      if (attempt) {
        // Calculate MCQ score from answers
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
          const ans = mcqAnswers.find((a) => a.question_id === q.id);
          if (ans && ans.selected_option === q.correct_option) {
            mcqTotal += Number(q.max_score);
          }
        }

        const essayTotal = essayGrades.reduce(
          (sum, g) => sum + (Number(g.final_score) || 0),
          0
        );

        const finalTotalScore = Number((mcqTotal + essayTotal).toFixed(2));
        await db('exam_attempts')
          .where({ id: attemptId })
          .update({
            total_score: finalTotalScore,
            status: 'graded',
          });

        // Append RESULT block to blockchain (PRD F16)
        try {
          const studentRef = crypto.createHash('sha256').update(attempt.student_id).digest('hex');
          await appendBlock('RESULT', {
            attempt_id: attemptId,
            exam_id: attempt.exam_id,
            student_ref: studentRef,
            final_score: finalTotalScore,
            graded_by: 'lecturer_finalized',
            finalized_at: new Date().toISOString(),
          });
        } catch (blockErr) {
          console.error('[Blockchain] Error appending result block:', blockErr);
        }
      }
    }
  }
}

export const essayGradingQueue = new EssayGradingQueue();
