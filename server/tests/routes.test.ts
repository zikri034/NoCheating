import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

describe('API Route Tests', () => {
  it('GET /api/health should return ok and connected status', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', database: 'connected' });
  });

  it('POST /api/auth/login with invalid payload should return validation error', async () => {
    const res = await request(app).post('/api/auth/login').send({});
    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('POST /api/auth/register with invalid email should return validation error', async () => {
    const res = await request(app).post('/api/auth/register').send({
      name: 'John Doe',
      email: 'invalid-email',
      password: 'password123',
      role: 'student'
    });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('GET /api/me without token should return 401 Unauthorized', async () => {
    const res = await request(app).get('/api/me');
    expect(res.status).toBe(401);
    expect(res.body.error).toBeDefined();
  });

  it('POST /api/auth/biometric/enroll without token should return 401 Unauthorized', async () => {
    const res = await request(app).post('/api/auth/biometric/enroll').send({
      device_id: '11111111-1111-4111-8111-111111111111',
      device_name: 'Test Device',
      platform: 'android',
      device_secret: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
    });
    expect(res.status).toBe(401);
  });
});
