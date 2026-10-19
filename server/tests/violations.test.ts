import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import db from '../src/db/knex';
import {
  evaluateViolation,
  calculateDistanceMeters,
  isInsideGeofence,
} from '../src/services/violation.service';

describe('S5: Pure Logic — Violation & Geofence (F05 & F06)', () => {
  it('evaluateViolation: warn signals do not increment critical count or terminate', () => {
    const res1 = evaluateViolation(0, 'warn', 3);
    expect(res1.newCriticalCount).toBe(0);
    expect(res1.isTerminated).toBe(false);

    const res2 = evaluateViolation(2, 'warn', 3);
    expect(res2.newCriticalCount).toBe(2);
    expect(res2.isTerminated).toBe(false);
  });

  it('evaluateViolation: critical signals increment critical count and terminate at max', () => {
    const res1 = evaluateViolation(0, 'critical', 3);
    expect(res1.newCriticalCount).toBe(1);
    expect(res1.isTerminated).toBe(false);

    const res2 = evaluateViolation(1, 'critical', 3);
    expect(res2.newCriticalCount).toBe(2);
    expect(res2.isTerminated).toBe(false);

    const res3 = evaluateViolation(2, 'critical', 3);
    expect(res3.newCriticalCount).toBe(3);
    expect(res3.isTerminated).toBe(true);
  });

  it('calculateDistanceMeters & isInsideGeofence: accurately calculates distance and checks bounds', () => {
    // Monas Jakarta (-6.175392, 106.827153)
    const lat1 = -6.175392;
    const lon1 = 106.827153;

    // Same point
    expect(calculateDistanceMeters(lat1, lon1, lat1, lon1)).toBe(0);
    expect(isInsideGeofence(lat1, lon1, lat1, lon1, 50)).toBe(true);

    // Nearby point ~40 meters away
    const latNearby = -6.17505;
    const lonNearby = 106.827153;
    const dist = calculateDistanceMeters(lat1, lon1, latNearby, lonNearby);
    expect(dist).toBeGreaterThan(30);
    expect(dist).toBeLessThan(50);
    expect(isInsideGeofence(lat1, lon1, latNearby, lonNearby, 100)).toBe(true);
    expect(isInsideGeofence(lat1, lon1, latNearby, lonNearby, 20)).toBe(false);
  });
});

import jwt from 'jsonwebtoken';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'change_me';

describe('S5: API — Violations & Exam Monitor (F05 & F06)', () => {
  let studentToken: string;
  let otherStudentToken: string;
  let lecturerToken: string;
  let studentId: string;
  let otherStudentId: string;
  let lecturerId: string;
  let examId: string;
  let attemptId: string;

  beforeAll(async () => {
    const students = await db('users').where({ role: 'student' }).limit(2);
    const lecturer = await db('users').where({ role: 'lecturer' }).first();
    const course = await db('courses').first();

    studentId = students[0].id;
    otherStudentId = students[1].id;
    lecturerId = lecturer.id;

    studentToken = jwt.sign(
      { id: studentId, email: students[0].email, role: 'student', name: students[0].name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    otherStudentToken = jwt.sign(
      { id: otherStudentId, email: students[1].email, role: 'student', name: students[1].name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    lecturerToken = jwt.sign(
      { id: lecturer.id, email: lecturer.email, role: 'lecturer', name: lecturer.name },
      ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const courseId = course.id;

    const [createdExam] = await db('exams')
      .insert({
        course_id: courseId,
        created_by: lecturerId,
        title: 'Ujian Pengawasan S5 & Geofence',
        start_at: new Date(Date.now() - 3600000),
        end_at: new Date(Date.now() + 7200000),
        duration_min: 90,
        venue_lat: -6.175392,
        venue_lng: 106.827153,
        venue_radius_m: 200,
        require_geofence: true,
        max_critical: 3,
        status: 'published',
      })
      .returning('*');
    examId = createdExam.id;

    // Enroll student
    await db('enrollments').insert({ exam_id: examId, student_id: studentId });

    // Start attempt inside geofence
    const attemptRes = await request(app)
      .post(`/api/exams/${examId}/attempts`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        latitude: -6.175392,
        longitude: 106.827153,
      });
    expect(attemptRes.status).toBe(201);
    attemptId = attemptRes.body.attempt.id;
  });

  it('rejects attempt start outside geofence if required', async () => {
    await db('enrollments').insert({ exam_id: examId, student_id: otherStudentId });

    // Location in Bandung (-6.9175, 107.6191) while exam is in Jakarta (-6.175, 106.827)
    const res = await request(app)
      .post(`/api/exams/${examId}/attempts`)
      .set('Authorization', `Bearer ${otherStudentToken}`)
      .send({
        latitude: -6.9175,
        longitude: 107.6191,
      });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('OUTSIDE_GEOFENCE');
  });

  it('POST /api/attempts/:id/violations: records warn violation without incrementing critical count', async () => {
    const res = await request(app)
      .post(`/api/attempts/${attemptId}/violations`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        type: 'device_shake',
        severity: 'warn',
        detail: { magnitude: 7.2, duration_ms: 450 },
      });

    expect(res.status).toBe(201);
    expect(res.body.violation.type).toBe('device_shake');
    expect(res.body.critical_count).toBe(0);
    expect(res.body.is_terminated).toBe(false);
  });

  it('POST /api/attempts/:id/violations: records critical violation and terminates at max_critical', async () => {
    // 1st critical: app_background
    const res1 = await request(app)
      .post(`/api/attempts/${attemptId}/violations`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        type: 'app_background',
        severity: 'critical',
        detail: { paused_seconds: 8 },
      });
    expect(res1.status).toBe(201);
    expect(res1.body.critical_count).toBe(1);
    expect(res1.body.is_terminated).toBe(false);

    // 2nd critical: mock_location
    const res2 = await request(app)
      .post(`/api/attempts/${attemptId}/violations`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        type: 'mock_location',
        severity: 'critical',
      });
    expect(res2.status).toBe(201);
    expect(res2.body.critical_count).toBe(2);
    expect(res2.body.is_terminated).toBe(false);

    // 3rd critical: geofence_exit -> must terminate!
    const res3 = await request(app)
      .post(`/api/attempts/${attemptId}/violations`)
      .set('Authorization', `Bearer ${studentToken}`)
      .send({
        type: 'geofence_exit',
        severity: 'critical',
        detail: { out_seconds: 35 },
      });
    expect(res3.status).toBe(201);
    expect(res3.body.critical_count).toBe(3);
    expect(res3.body.is_terminated).toBe(true);
    expect(res3.body.status).toBe('terminated');

    // Attempt in DB should be 'terminated'
    const attemptInDb = await db('exam_attempts').where('id', attemptId).first();
    expect(attemptInDb.status).toBe('terminated');
  });

  it('GET /api/exams/:id/monitor: lecturer can monitor participants and violation timeline', async () => {
    // Student access forbidden
    const forbiddenRes = await request(app)
      .get(`/api/exams/${examId}/monitor`)
      .set('Authorization', `Bearer ${studentToken}`);
    expect(forbiddenRes.status).toBe(403);

    // Lecturer access allowed
    const res = await request(app)
      .get(`/api/exams/${examId}/monitor`)
      .set('Authorization', `Bearer ${lecturerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.exam.id).toBe(examId);
    expect(res.body.stats.terminated_count).toBeGreaterThanOrEqual(1);
    expect(res.body.participants).toBeDefined();

    const monitoredAttempt = res.body.participants.find((p: any) => p.id === attemptId);
    expect(monitoredAttempt).toBeDefined();
    expect(monitoredAttempt.status).toBe('terminated');
    expect(monitoredAttempt.violations.length).toBe(4); // 1 warn + 3 critical
  });
});
