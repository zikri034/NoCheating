import { Router, Request, Response } from 'express';
import { z } from 'zod';
import db from '../db/knex';
import { jwtMiddleware, requireRole } from '../middleware/auth.middleware';

const router = Router();

// Validation schema for creating a course
const createCourseSchema = z.object({
  code: z.string().min(2).max(20),
  name: z.string().min(2).max(100),
});

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

// POST /api/courses — Create course (lecturer)
router.post('/', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const data = createCourseSchema.parse(req.body);
    const userId = (req as any).user.id;

    const existing = await db('courses').where({ code: data.code }).first();
    if (existing) {
      return res.status(409).json({
        error: { code: 'COURSE_EXISTS', message: 'Kode mata kuliah sudah digunakan' },
      });
    }

    const [course] = await db('courses')
      .insert({
        code: data.code,
        name: data.name,
        lecturer_id: userId,
      })
      .returning('*');

    return res.status(201).json({ course });
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

export default router;
