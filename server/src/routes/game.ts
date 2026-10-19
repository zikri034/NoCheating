import { Router, Request, Response } from 'express';
import { jwtMiddleware } from '../middleware/auth.middleware';
import { z } from 'zod';
import db from '../db/knex';
import { getStudyPairs, submitScore, getLeaderboard } from '../services/game.service';

const router = Router();

const submitScoreSchema = z.object({
  score: z.number().int().min(0).max(10000),
  duration_ms: z.number().int().min(1000).max(600000),
});

/**
 * GET /api/pairs
 * Get study pairs for Pair Rush matching game
 */
router.get('/pairs', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const courseId = req.query.courseId as string | undefined;
    const pairs = await getStudyPairs(courseId);
    return res.json({ pairs });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'PAIRS_FETCH_ERROR', message: error.message },
    });
  }
});

/**
 * POST /api/game/scores
 * Submit a game score (blocked if user has an in_progress exam attempt)
 */
router.post('/game/scores', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;

    // Check if user currently has an active in_progress exam attempt (PRD Rule F11)
    const activeAttempt = await db('exam_attempts')
      .where({ student_id: userId, status: 'in_progress' })
      .first();

    if (activeAttempt) {
      return res.status(403).json({
        error: {
          code: 'EXAM_IN_PROGRESS',
          message: 'Mini game Pair Rush dinonaktifkan saat Anda sedang dalam sesi ujian aktif!',
        },
      });
    }

    const validation = submitScoreSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: validation.error.issues.map((e) => e.message).join(', '),
        },
      });
    }

    const { score, duration_ms } = validation.data;
    const recorded = await submitScore(userId, score, duration_ms);

    return res.status(201).json({
      message: 'Skor berhasil disimpan!',
      score: recorded,
    });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'SCORE_SUBMIT_ERROR', message: error.message },
    });
  }
});

/**
 * GET /api/game/scores
 * Top 10 Leaderboard
 */
router.get('/game/scores', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 10;
    const leaderboard = await getLeaderboard(limit);
    return res.json({ leaderboard });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'LEADERBOARD_FETCH_ERROR', message: error.message },
    });
  }
});

export default router;
