import { Router, Request, Response } from 'express';
import db from '../db/knex';
import { jwtMiddleware } from '../middleware/auth.middleware';

const router = Router();

// GET /api/courses — List all courses
router.get('/', jwtMiddleware, async (_req: Request, res: Response) => {
  try {
    const courses = await db('courses')
      .join('users', 'courses.lecturer_id', 'users.id')
      .select('courses.*', 'users.name as lecturer_name')
      .orderBy('courses.code', 'asc');

    return res.json({ courses });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

export default router;
