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
  body: z.string().min(1).max(5000),
  options: z.array(z.string()).optional().nullable(),
  correct_option: z.string().optional().nullable(),
  rubric: z.string().optional().nullable(),
  model_answer: z.string().optional().nullable(),
  max_score: z.union([z.number(), z.string()]).transform((v) => Number(v) || 10).optional().nullable(),
}).refine((data) => {
  if (data.type === 'mcq') {
    return Array.isArray(data.options) && data.options.length >= 2;
  }
  return true;
}, {
  message: 'Soal pilihan ganda harus memiliki minimal 2 opsi pilihan',
});

// GET /api/questions — Bank soal dengan pencarian, filter, dan pagination (dosen)
router.get('/', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { course_id, type, search, page = '1', limit } = req.query;
    const pageNum = Math.max(1, parseInt(page as string, 10) || 1);
    const pageSize = limit ? Math.min(1000, Math.max(1, parseInt(limit as string, 10) || 1000)) : 1000;
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
  options: z.array(z.string()).optional().nullable(),
  correct_option: z.string().optional().nullable(),
  rubric: z.string().optional().nullable(),
  model_answer: z.string().optional().nullable(),
  max_score: z.union([z.number(), z.string()]).transform((v) => Number(v) || 10).optional().nullable(),
}).refine((data) => {
  if (data.type === 'mcq') {
    return Array.isArray(data.options) && data.options.length >= 2;
  }
  return true;
}, {
  message: 'Soal pilihan ganda harus memiliki minimal 2 opsi pilihan',
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
        const rowsToInsert = data.questions.map((q) => {
          let opts: string[] | null = null;
          if (q.type === 'mcq' && Array.isArray(q.options) && q.options.length > 0) {
            opts = q.options;
          }
          return {
            course_id: data.course_id,
            type: q.type,
            body: q.body,
            options: opts ? JSON.stringify(opts) : null,
            correct_option: q.correct_option || (opts ? opts[0] : null),
            rubric: q.rubric || null,
            model_answer: q.model_answer || null,
            max_score: q.max_score || 10,
          };
        });

        const rows = await trx('questions').insert(rowsToInsert).returning('*');
        return rows.map((r: any) => ({
          ...r,
          max_score: Number(r.max_score) || 10,
        }));
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


// DELETE /api/questions/:id — Hapus satu butir soal dari bank soal (dosen)
router.delete('/:id', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const question = await db('questions').where({ id }).first();
    if (!question) {
      return res.status(404).json({
        error: { code: 'QUESTION_NOT_FOUND', message: 'Butir soal tidak ditemukan' },
      });
    }

    await db.transaction(async (trx) => {
      // Hapus riwayat penilaian essay jika ada
      await trx('essay_grades')
        .whereIn('answer_id', function() {
          this.select('id').from('attempt_answers').where({ question_id: id });
        })
        .del();
      // Hapus riwayat jawaban siswa jika ada
      await trx('attempt_answers').where({ question_id: id }).del();
      // Hapus alokasi soal pada ujian
      await trx('exam_questions').where({ question_id: id }).del();
      await trx('questions').where({ id }).del();
    });

    return res.json({
      success: true,
      message: 'Butir soal berhasil dihapus dari bank soal',
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message },
    });
  }
});

// POST /api/questions/batch-delete — Hapus banyak butir soal sekaligus dari bank soal (dosen)
router.post('/batch-delete', jwtMiddleware, requireRole('lecturer'), async (req: Request, res: Response) => {
  try {
    const { question_ids } = z.object({
      question_ids: z.array(z.string().uuid()).min(1, 'Pilih minimal satu soal untuk dihapus'),
    }).parse(req.body);

    const deletedCount = await db.transaction(async (trx) => {
      // Hapus riwayat penilaian essay jika ada
      await trx('essay_grades')
        .whereIn('answer_id', function() {
          this.select('id').from('attempt_answers').whereIn('question_id', question_ids);
        })
        .del();
      // Hapus riwayat jawaban siswa jika ada
      await trx('attempt_answers').whereIn('question_id', question_ids).del();
      // Hapus alokasi soal pada ujian
      await trx('exam_questions').whereIn('question_id', question_ids).del();
      return await trx('questions').whereIn('id', question_ids).del();
    });

    return res.json({
      success: true,
      count: deletedCount,
      message: `${deletedCount} butir soal berhasil dihapus dari bank soal`,
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
});

export default router;
