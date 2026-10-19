import { describe, it, expect } from 'vitest';
import { AuthService } from '../src/services/auth.service';

describe('AuthService Unit Tests', () => {
  it('should hash a password and verify it successfully', async () => {
    const password = 'SecretPassword123';
    const hash = await AuthService.hashPassword(password);

    expect(hash).toBeDefined();
    expect(hash).not.toBe(password);

    const isMatch = await AuthService.verifyPassword(password, hash);
    expect(isMatch).toBe(true);

    const isWrong = await AuthService.verifyPassword('WrongPassword321', hash);
    expect(isWrong).toBe(false);
  });

  it('should generate valid JWT access token and verify payload', () => {
    const user = { id: 'user-uuid-123', role: 'student', email: 'test@student.id' };
    const token = AuthService.generateAccessToken(user);

    expect(token).toBeDefined();
    expect(typeof token).toBe('string');
    expect(token.split('.').length).toBe(3);
  });

  it('should generate valid JWT refresh token and verify format', () => {
    const user = { id: 'user-uuid-123', role: 'student', email: 'test@student.id' };
    const refreshToken = AuthService.generateRefreshToken(user);

    expect(refreshToken).toBeDefined();
    expect(typeof refreshToken).toBe('string');
    expect(refreshToken.split('.').length).toBe(3);
  });

  it('should hash token deterministically with HMAC sha256', async () => {
    const token = 'sample-random-refresh-token';
    const hash1 = await AuthService.hashToken(token);
    const hash2 = await AuthService.hashToken(token);

    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64); // sha256 hex
  });
});
