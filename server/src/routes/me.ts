import { Request, Response, Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { z } from 'zod';
import db from '../db/knex';
import { AuthService } from '../services/auth.service';
import { jwtMiddleware } from '../middleware/auth.middleware';

const router = Router();

// Ensure upload directory exists
const uploadDir = path.join(process.cwd(), 'uploads', 'avatars');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Multer storage configuration
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `avatar-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 }, // 2 MB limit per PRD 9 & F13
  fileFilter: (_req, file, cb) => {
    const allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Format file tidak didukung. Harap gunakan JPEG, PNG, atau WebP.'));
    }
  }
});

// Validation Schemas
const updateProfileSchema = z.object({
  name: z.string().min(2, 'Nama minimal 2 karakter').max(100),
});

const changePasswordSchema = z.object({
  old_password: z.string().min(1, 'Password lama harus diisi'),
  new_password: z.string()
    .min(8, 'Password baru minimal 8 karakter')
    .regex(/[a-zA-Z]/, 'Password baru harus mengandung huruf')
    .regex(/[0-9]/, 'Password baru harus mengandung angka'),
});

// GET /api/me
// Returns profile of currently authenticated user
router.get('/', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({
        error: { code: 'UNAUTHORIZED', message: 'Token otentikasi diperlukan' }
      });
    }

    const user = await db('users')
      .select('id', 'name', 'nim', 'email', 'role', 'avatar_path', 'created_at')
      .where({ id: userId })
      .first();

    if (!user) {
      return res.status(404).json({
        error: { code: 'USER_NOT_FOUND', message: 'Pengguna tidak ditemukan' }
      });
    }

    return res.json({ user });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message }
    });
  }
});

// PATCH /api/me
// Update user profile name
router.patch('/', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    const data = updateProfileSchema.parse(req.body);

    const [updatedUser] = await db('users')
      .where({ id: userId })
      .update({ name: data.name })
      .returning(['id', 'name', 'nim', 'email', 'role', 'avatar_path', 'created_at']);

    return res.json({
      message: 'Profil berhasil diperbarui',
      user: updatedUser
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: error.issues[0].message }
      });
    }
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message }
    });
  }
});

// POST /api/me/avatar
// Upload avatar photo (multipart, max 2MB)
router.post('/avatar', jwtMiddleware, upload.single('avatar'), async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!req.file) {
      return res.status(400).json({
        error: { code: 'FILE_REQUIRED', message: 'File avatar tidak ditemukan' }
      });
    }

    const avatarUrl = `/uploads/avatars/${req.file.filename}`;

    const [updatedUser] = await db('users')
      .where({ id: userId })
      .update({ avatar_path: avatarUrl })
      .returning(['id', 'name', 'nim', 'email', 'role', 'avatar_path', 'created_at']);

    return res.json({
      message: 'Foto profil berhasil diunggah',
      avatar_url: avatarUrl,
      user: updatedUser
    });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'UPLOAD_ERROR', message: (error as Error).message }
    });
  }
});

// POST /api/me/password
// Change password and revoke all registered biometric devices (PRD F02 & F13)
router.post('/password', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    const { old_password, new_password } = changePasswordSchema.parse(req.body);

    const user = await db('users').where({ id: userId }).first();
    if (!user) {
      return res.status(404).json({
        error: { code: 'USER_NOT_FOUND', message: 'Pengguna tidak ditemukan' }
      });
    }

    const isMatch = await AuthService.verifyPassword(old_password, user.password_hash);
    if (!isMatch) {
      return res.status(400).json({
        error: { code: 'INVALID_OLD_PASSWORD', message: 'Password lama tidak sesuai' }
      });
    }

    const newHash = await AuthService.hashPassword(new_password);

    await db.transaction(async (trx) => {
      // 1. Update password hash
      await trx('users').where({ id: userId }).update({ password_hash: newHash });

      // 2. Revoke all biometric devices per PRD F02 / F13
      await trx('biometric_devices')
        .where({ user_id: userId })
        .update({ revoked_at: trx.fn.now() });

      // 3. Revoke active refresh tokens
      await trx('refresh_tokens')
        .where({ user_id: userId })
        .update({ revoked_at: trx.fn.now() });
    });

    return res.json({
      message: 'Password berhasil diubah. Semua perangkat biometrik telah dicabut demi keamanan.'
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: error.issues[0].message }
      });
    }
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message }
    });
  }
});

// GET /api/me/devices
// List all registered biometric devices for the user
router.get('/devices', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    const devices = await db('biometric_devices')
      .select('id', 'device_id', 'device_name', 'platform', 'created_at', 'revoked_at', 'last_used_at')
      .where({ user_id: userId })
      .orderBy('created_at', 'desc');

    return res.json({ devices });
  } catch (error) {
    return res.status(500).json({
      error: { code: 'INTERNAL_ERROR', message: (error as Error).message }
    });
  }
});

export default router;
