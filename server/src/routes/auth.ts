import { Router } from 'express';
import { Request, Response } from 'express';
import { z } from 'zod';
import db from '../db/knex';
import { AuthService } from '../services/auth.service';
import dotenv from 'dotenv';

dotenv.config();

const router = Router();

// Validation Schemas
const registerSchema = z.object({
  name: z.string().min(2),
  nim: z.string().min(5).optional(),
  email: z.string().email(),
  password: z.string().min(8).regex(/[a-zA-Z]/, 'Password must contain letters').regex(/[0-9]/, 'Password must contain numbers'),
  role: z.enum(['student', 'lecturer']),
  inviteCode: z.string().optional(),
});

const loginSchema = z.object({
  identifier: z.string().min(3), // Email or NIM
  password: z.string(),
});

const refreshSchema = z.object({
  refreshToken: z.string(),
});

// --- Endpoints ---

// POST /api/auth/register
router.post('/register', async (req: Request, res: Response) => {
  try {
    const data = registerSchema.parse(req.body);

    // Lecturer invite code check
    if (data.role === 'lecturer') {
      if (data.inviteCode !== process.env.LECTURER_INVITE_CODE) {
        return res.status(400).json({
          error: { code: 'INVALID_INVITE_CODE', message: 'Invalid lecturer invite code' }
        });
      }
    }

    // Check if user exists
    const existingUser = await db('users')
      .where({ email: data.email })
      .orWhere(function() {
        this.where('nim', data.nim).andWhere('nim', 'is not null');
      })
      .first();

    if (existingUser) {
      return res.status(400).json({
        error: { code: 'USER_EXISTS', message: 'Email or NIM already registered' }
      });
    }

    const passwordHash = await AuthService.hashPassword(data.password);

    const [user] = await db('users').insert({
      name: data.name,
      nim: data.nim,
      email: data.email,
      password_hash: passwordHash,
      role: data.role,
    }).returning('*');

    const accessToken = AuthService.generateAccessToken(user);
    const refreshToken = AuthService.generateRefreshToken(user);

    // Store hashed refresh token
    const tokenHash = await AuthService.hashToken(refreshToken);
    await db('refresh_tokens').insert({
      user_id: user.id,
      token_hash: tokenHash,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });

    res.status(201).json({
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
      accessToken,
      refreshToken
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: error.issues[0].message } });
    }
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: (error as Error).message } });
  }
});

// POST /api/auth/login
router.post('/login', async (req: Request, res: Response) => {
  try {
    const data = loginSchema.parse(req.body);

    // Find user by email or NIM
    const user = await db('users')
      .where({ email: data.identifier })
      .orWhere({ nim: data.identifier })
      .first();

    if (!user) {
      return res.status(401).json({
        error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email/NIM or password' }
      });
    }

    // 1. Check Lockout
    await AuthService.checkLockout(user.id);

    // 2. Verify Password
    const isValid = await AuthService.verifyPassword(data.password, user.password_hash);

    if (!isValid) {
      await AuthService.recordLoginFailure(user.id);
      return res.status(401).json({
        error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email/NIM or password' }
      });
    }

    // 3. Reset failures and issue tokens
    await AuthService.resetLoginFailures(user.id);
    const accessToken = AuthService.generateAccessToken(user);
    const refreshToken = AuthService.generateRefreshToken(user);

    const tokenHash = await AuthService.hashToken(refreshToken);
    await db('refresh_tokens').insert({
      user_id: user.id,
      token_hash: tokenHash,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });

    res.json({
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
      accessToken,
      refreshToken
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: error.issues[0].message } });
    }
    res.status(error instanceof Error ? (error as any).status || 500 : 500).json({
      error: { code: 'AUTH_ERROR', message: (error as Error).message }
    });
  }
});

// POST /api/auth/refresh
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = refreshSchema.parse(req.body);
    const tokens = await AuthService.rotateRefreshToken(refreshToken);

    res.json(tokens);
  } catch (error) {
    res.status(401).json({
      error: { code: 'INVALID_REFRESH_TOKEN', message: (error as Error).message }
    });
  }
});

// POST /api/auth/logout
router.post('/logout', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: { code: 'TOKEN_REQUIRED', message: 'Refresh token is required' } });
    }

    const tokenHash = await AuthService.hashToken(refreshToken);
    await db('refresh_tokens')
      .where({ token_hash: tokenHash })
      .update({ revoked_at: db.fn.now() });

    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: (error as Error).message } });
  }
});

export default router;

