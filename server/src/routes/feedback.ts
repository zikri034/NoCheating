import { Router, Request, Response } from 'express';
import { jwtMiddleware } from '../middleware/auth.middleware';
import { z } from 'zod';
import { createFeedback, getFeedbackByUser, getAllFeedback } from '../services/feedback.service';

const router = Router();

const feedbackSchema = z.object({
  impression: z.string().min(5, 'Kesan minimal 5 karakter').max(2000),
  suggestion: z.string().max(2000).optional(),
  rating: z.number().int().min(1, 'Rating minimal 1').max(5, 'Rating maksimal 5'),
});

/**
 * POST /api/feedback
 * Submit course feedback
 */
router.post('/', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const validation = feedbackSchema.safeParse(req.body);

    if (!validation.success) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: validation.error.issues.map((e) => e.message).join(', '),
        },
      });
    }

    const feedback = await createFeedback(userId, validation.data);
    return res.status(201).json({
      message: 'Saran dan kesan berhasil dikirim!',
      feedback,
    });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'FEEDBACK_SUBMIT_ERROR', message: error.message },
    });
  }
});

/**
 * GET /api/feedback/me
 * Get feedback submitted by the logged-in user
 */
router.get('/me', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.id;
    const feedbacks = await getFeedbackByUser(userId);
    return res.json({ feedbacks });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'FEEDBACK_FETCH_ERROR', message: error.message },
    });
  }
});

/**
 * GET /api/feedback
 * Get all feedback (lecturer only)
 */
router.get('/', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userRole = (req as any).user.role;
    if (userRole !== 'lecturer') {
      return res.status(403).json({
        error: { code: 'FORBIDDEN', message: 'Hanya dosen yang dapat mengakses rekap seluruh saran dan kesan!' },
      });
    }

    const feedbacks = await getAllFeedback();
    return res.json({ feedbacks });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'FEEDBACK_FETCH_ERROR', message: error.message },
    });
  }
});

export default router;
