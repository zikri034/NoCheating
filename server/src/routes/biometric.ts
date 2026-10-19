import { Router } from 'express';
import { Request, Response } from 'express';
import { z } from 'zod';
import db from '../db/knex';
import { AuthService } from '../services/auth.service';
import { jwtMiddleware } from '../middleware/auth.middleware';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';

dotenv.config();

const router = Router();

// Validation Schemas
const biometricEnrollSchema = z.object({
  device_id: z.string().uuid(),
  device_name: z.string().min(1),
  platform: z.enum(['android', 'ios']),
  device_secret: z.string().min(32),
});

const biometricLoginSchema = z.object({
  device_id: z.string().uuid(),
  device_secret: z.string().min(32),
});

// --- Endpoints ---

// POST /api/auth/biometric/enroll
// Requirement: Must be authenticated
router.post('/enroll', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const data = biometricEnrollSchema.parse(req.body);
    const userId = (req as any).user.id;

    // Hash the device secret for storage
    const secretHash = await bcrypt.hash(data.device_secret, 10);

    const existingDevice = await db('biometric_devices')
      .where({ user_id: userId, device_id: data.device_id })
      .first();

    if (existingDevice) {
      await db('biometric_devices')
        .where({ id: existingDevice.id })
        .update({
          secret_hash: secretHash,
          device_name: data.device_name,
          platform: data.platform,
          revoked_at: null,
          created_at: db.fn.now()
        });
    } else {
      await db('biometric_devices').insert({
        user_id: userId,
        device_id: data.device_id,
        secret_hash: secretHash,
        device_name: data.device_name,
        platform: data.platform,
        created_at: db.fn.now()
      });
    }

    res.status(201).json({ message: 'Biometric device enrolled successfully' });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: error.issues[0].message } });
    }
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: (error as Error).message } });
  }
});

// POST /api/auth/biometric/login
// Requirement: Public (used after local_auth success on client)
router.post('/login', async (req: Request, res: Response) => {
  try {
    const data = biometricLoginSchema.parse(req.body);

    // Find the device
    const device = await db('biometric_devices')
      .where({ device_id: data.device_id, revoked_at: null })
      .first();

    if (!device) {
      return res.status(401).json({
        error: { code: 'DEVICE_NOT_FOUND', message: 'Biometric device not found or revoked' }
      });
    }

    // Verify the secret hash
    const isValid = await bcrypt.compare(data.device_secret, device.secret_hash);

    if (!isValid) {
      return res.status(401).json({
        error: { code: 'INVALID_SECRET', message: 'Biometric verification failed' }
      });
    }

    // Fetch user and issue tokens
    const user = await db('users').where({ id: device.user_id }).first();
    if (!user) {
      return res.status(404).json({ error: { code: 'USER_NOT_FOUND', message: 'User associated with device not found' } });
    }

    const accessToken = AuthService.generateAccessToken(user);
    const refreshToken = AuthService.generateRefreshToken(user);

    // Store new hashed refresh token
    const tokenHash = await AuthService.hashToken(refreshToken);
    await db('refresh_tokens').insert({
      user_id: user.id,
      token_hash: tokenHash,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });

    // Update last used
    await db('biometric_devices').where({ id: device.id }).update({ last_used_at: db.fn.now() });

    res.json({
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

// DELETE /api/auth/biometric/:deviceId
// Requirement: Must be authenticated
router.delete('/:deviceId', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const { deviceId } = req.params;
    const userId = (req as any).user.id;

    const affectedRows = await db('biometric_devices')
      .where({ device_id: deviceId, user_id: userId })
      .update({ revoked_at: db.fn.now() });

    if (affectedRows === 0) {
      return res.status(404).json({ error: { code: 'DEVICE_NOT_FOUND', message: 'Device not found' } });
    }

    res.json({ message: 'Biometric device revoked successfully' });
  } catch (error) {
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: (error as Error).message } });
  }
});

export default router;
