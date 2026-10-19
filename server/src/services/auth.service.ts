import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import db from '../db/knex';
import dotenv from 'dotenv';

dotenv.config();

function requiredSecret(name: 'JWT_ACCESS_SECRET' | 'JWT_REFRESH_SECRET'): string {
  const value = process.env[name];

  if (!value || value === 'change_me') {
    throw new Error(`${name} must be set to a non-placeholder value`);
  }

  return value;
}

const ACCESS_SECRET = requiredSecret('JWT_ACCESS_SECRET');
const REFRESH_SECRET = requiredSecret('JWT_REFRESH_SECRET');
const ACCESS_TTL = parseInt(process.env.ACCESS_TTL_MIN || '15') * 60;
const REFRESH_TTL = parseInt(process.env.REFRESH_TTL_DAYS || '7') * 24 * 60 * 60;
const BCRYPT_COST = 12;

export class AuthService {
  // --- Password Management ---

  static async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, BCRYPT_COST);
  }

  static async verifyPassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }

  // --- Token Management ---

  static generateAccessToken(user: any) {
    return jwt.sign(
      { id: user.id, role: user.role, email: user.email },
      ACCESS_SECRET,
      { expiresIn: ACCESS_TTL }
    );
  }

  static generateRefreshToken(user: any) {
    return jwt.sign(
      { id: user.id, jti: randomUUID() },
      REFRESH_SECRET,
      { expiresIn: REFRESH_TTL }
    );
  }

  static async rotateRefreshToken(oldRefreshToken: string) {
    // Verify the old token
    const decoded = jwt.verify(oldRefreshToken, REFRESH_SECRET) as any;
    const userId = decoded.id;

    // A keyed, deterministic hash permits indexed lookup without storing the
    // bearer token itself. bcrypt is deliberately not used here because its
    // random salt makes a newly generated hash impossible to query by.
    const tokenHash = await this.hashToken(oldRefreshToken);

    // Check if token exists, has not expired, and has not been revoked.
    const tokenRecord = await db('refresh_tokens')
      .where({ token_hash: tokenHash, revoked_at: null })
      .andWhere('expires_at', '>', db.fn.now())
      .first();

    if (!tokenRecord) {
      throw new Error('Invalid or revoked refresh token');
    }

    const storedHash = Buffer.from(tokenRecord.token_hash, 'hex');
    const suppliedHash = Buffer.from(tokenHash, 'hex');
    if (
      storedHash.length !== suppliedHash.length ||
      !timingSafeEqual(storedHash, suppliedHash) ||
      tokenRecord.user_id !== userId
    ) {
      throw new Error('Invalid or revoked refresh token');
    }

    // Revoke atomically so that a replay racing this request cannot issue a
    // second replacement token.
    const revokedRows = await db('refresh_tokens')
      .where({ id: tokenRecord.id, revoked_at: null })
      .update({ revoked_at: db.fn.now() });
    if (revokedRows !== 1) {
      throw new Error('Invalid or revoked refresh token');
    }

    // Fetch user and issue new pair
    const user = await db('users').where({ id: userId }).first();
    if (!user) throw new Error('User not found');

    const newAccessToken = this.generateAccessToken(user);
    const newRefreshToken = this.generateRefreshToken(user);

    // Store new hashed refresh token
    const newHash = await this.hashToken(newRefreshToken);
    await db('refresh_tokens').insert({
      user_id: user.id,
      token_hash: newHash,
      expires_at: new Date(Date.now() + REFRESH_TTL * 1000)
    });

    return { accessToken: newAccessToken, refreshToken: newRefreshToken };
  }

  static async hashToken(token: string): Promise<string> {
    return createHmac('sha256', REFRESH_SECRET).update(token).digest('hex');
  }

  // --- Lockout Logic ---

  static async checkLockout(userId: string) {
    const user = await db('users').where({ id: userId }).first();
    if (!user) return;

    if (user.locked_until && new Date(user.locked_until) > new Date()) {
      const remaining = Math.ceil((new Date(user.locked_until).getTime() - Date.now()) / 60000);
      throw new Error(`Account locked. Try again in ${remaining} minutes.`);
    }
  }

  static async recordLoginFailure(userId: string) {
    const user = await db('users').where({ id: userId }).first();
    if (!user) return;

    const newFailCount = (user.failed_logins || 0) + 1;
    const lockoutUntil = newFailCount >= 5
      ? new Date(Date.now() + 5 * 60 * 1000)
      : null;

    await db('users').where({ id: userId }).update({
      failed_logins: newFailCount,
      locked_until: lockoutUntil
    });
  }

  static async resetLoginFailures(userId: string) {
    await db('users').where({ id: userId }).update({
      failed_logins: 0,
      locked_until: null
    });
  }
}
