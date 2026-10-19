import { Router, Request, Response } from 'express';
import { z } from 'zod';
import multer from 'multer';
import db from '../db/knex';
import { jwtMiddleware, requireRole } from '../middleware/auth.middleware';
import { geminiService } from '../ai/gemini.service';

const router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB
});

// Validation schema for creating question
const createQuestionSchema = z.object({
  course_id: z.string().uuid(),
  type: z.enum(['mcq', 'essay']),
  body: z.string().min(3).max(5000),
  options: z.array(z.string()).min(2).optional(),
  correct_option: z.string().optional(),
  rubric: z.string().optional(),
  model_answer: z.string().optional(),
  max_score: z.number().positive().default(10),
}).refine((data) => {
  if (data.type === 'mcq') {
    return !!data.options && data.options.length >= 2 && !!data.correct_option;
  }
  return true;
}, {
  message: 'Soal pilihan ganda harus memiliki opsi dan kunci jawaban yang valid',
});

// GET /api/questions — Bank soal dengan pencarian, filter, dan pagination (dosen)
router.get('/', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { course_id, type, search, page = '1', limit = '20' } = req.query;
    const pageNum = Math.max(1, parseInt(page as string, 10) || 1);
    const pageSize = Math.min(50, Math.max(1, parseInt(limit as string, 10) || 20));
    const offset = (pageNum - 1) * pageSize;

    let query = db('questions')
      .join('courses', 'questions.course_id', 'courses.id')
      .select(
        'questions.*',
        'courses.name as course_name',
        'courses.code as course_code'
      );

    if (course_id && typeof course_id === 'string') {
      query = query.where('questions.course_id', course_id);
    }

    if (type && typeof type === 'string' && ['mcq', 'essay'].includes(type)) {
      query = query.where('questions.type', type);
    }

    if (search && typeof search === 'string' && search.trim()) {
      const term = `%${search.trim()}%`;
      query = query.whereILike('questions.body', term);
    }

    const countResult = await query.clone().clearSelect().count('questions.id as total').first();
    const total = parseInt((countResult as any)?.total || '0', 10);

    const questions = await query
      .orderBy('questions.id', 'desc')
      .limit(pageSize)
      .offset(offset);

    return res.json({
      questions,
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

// POST /api/questions — Buat soal baru ke bank soal (dosen)
router.post('/', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const data = createQuestionSchema.parse(req.body);

    // Verify course exists
    const course = await db('courses').where({ id: data.course_id }).first();
    if (!course) {
      return res.status(404).json({
        error: { code: 'COURSE_NOT_FOUND', message: 'Mata kuliah tidak ditemukan' },
      });
    }

    const [question] = await db('questions').insert({
      course_id: data.course_id,
      type: data.type,
      body: data.body,
      options: data.options ? JSON.stringify(data.options) : null,
      correct_option: data.correct_option || null,
      rubric: data.rubric || null,
      model_answer: data.model_answer || null,
      max_score: data.max_score,
    }).returning('*');

    return res.status(201).json({ question });
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

const batchQuestionItemSchema = z.object({
  type: z.enum(['mcq', 'essay']),
  body: z.string().min(1).max(5000),
  options: z.array(z.string()).min(2).optional(),
  correct_option: z.string().optional(),
  rubric: z.string().optional(),
  model_answer: z.string().optional(),
  max_score: z.number().positive().default(10),
});

const batchCreateQuestionsSchema = z.object({
  course_id: z.string().uuid(),
  questions: z.array(batchQuestionItemSchema).min(1).max(100),
});

// POST /api/questions/extract-document — Ekstraksi naskah soal dari dokumen Word/PDF (dosen)
router.post(
  '/extract-document',
  jwtMiddleware,
  requireRole('lecturer'),
  upload.single('document'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: {
            code: 'NO_FILE',
            message: 'Berkas dokumen wajib diunggah (format .pdf, .docx, atau .txt)',
          },
        });
      }

      const originalName = req.file.originalname || '';
      const ext = originalName.split('.').pop()?.toLowerCase();
      const allowedExts = ['pdf', 'docx', 'doc', 'txt'];

      if (!ext || !allowedExts.includes(ext)) {
        return res.status(400).json({
          error: {
            code: 'INVALID_FILE_TYPE',
            message: `Tipe berkas .${ext} tidak didukung. Harap unggah berkas .pdf, .docx, atau .txt`,
          },
        });
      }

      const extraction = await geminiService.extractQuestionsFromDocument({
        buffer: req.file.buffer,
        mimeType: req.file.mimetype,
        originalFilename: originalName,
      });

      return res.json({
        success: true,
        extracted: extraction.result,
        model: extraction.model,
      });
    } catch (error: any) {
      console.error('Error extracting questions from document:', error);
      let userMessage = error.message || 'Gagal mengekstrak soal dari dokumen';
      if (
        error?.status === 503 ||
        error?.message?.includes('503') ||
        error?.message?.includes('high demand') ||
        error?.message?.includes('UNAVAILABLE')
      ) {
        userMessage =
          'Layanan Google Gemini AI sedang mengalami lonjakan beban server (High Demand / 503). Silakan ulangi dalam beberapa detik.';
      } else if (error?.status === 429 || error?.message?.includes('429')) {
        userMessage =
          'Batas kuota harian/menit API Gemini tercapai (Rate Limit / 429). Silakan tunggu sebentar.';
      }

      return res.status(500).json({
        error: {
          code: 'EXTRACTION_FAILED',
          message: userMessage,
        },
      });
    }
  }
);

// POST /api/questions/batch — Simpan banyak soal sekaligus ke bank soal (dosen)
router.post(
  '/batch',
  jwtMiddleware,
  requireRole('lecturer'),
  async (req: Request, res: Response) => {
    try {
      const data = batchCreateQuestionsSchema.parse(req.body);

      const course = await db('courses').where({ id: data.course_id }).first();
      if (!course) {
        return res.status(404).json({
          error: { code: 'COURSE_NOT_FOUND', message: 'Mata kuliah tidak ditemukan' },
        });
      }

      const inserted = await db.transaction(async (trx) => {
        const rowsToInsert = data.questions.map((q) => ({
          course_id: data.course_id,
          type: q.type,
          body: q.body,
          options: q.options ? JSON.stringify(q.options) : null,
          correct_option: q.correct_option || null,
          rubric: q.rubric || null,
          model_answer: q.model_answer || null,
          max_score: q.max_score,
        }));

        return await trx('questions').insert(rowsToInsert).returning('*');
      });

      return res.status(201).json({
        success: true,
        count: inserted.length,
        questions: inserted,
      });
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({
          error: { code: 'VALIDATION_ERROR', message: error.issues[0].message },
        });
      }
      return res.status(500).json({
        error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
      });
    }
  }
);


export default router;
