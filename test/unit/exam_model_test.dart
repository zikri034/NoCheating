import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/widgets/neo_tag.dart';
import 'package:thereisnocheating/features/exams/data/models/exam_model.dart';
import 'package:thereisnocheating/features/exams/data/models/question_model.dart';
import 'package:thereisnocheating/features/exams/data/models/course_model.dart';

void main() {
  group('ExamModel Tests (F03 & F10)', () {
    test('fromJson & toJson correctly serializes exam data', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'course_id': '22222222-2222-2222-2222-222222222222',
        'title': 'Ujian Akhir Semester',
        'description': 'Materi Flutter Komprehensif',
        'start_at': '2026-10-18T09:00:00.000Z',
        'end_at': '2026-10-18T11:00:00.000Z',
        'duration_min': 120,
        'fee_idr': 50000,
        'require_biometric': true,
        'require_geofence': true,
        'status': 'published',
        'course_name': 'Pemrograman Aplikasi Mobile',
        'course_code': 'IF4501',
        'lecturer_name': 'Dr. Budi Santoso',
        'is_enrolled': true,
      };

      final exam = ExamModel.fromJson(json);

      expect(exam.id, '11111111-1111-1111-1111-111111111111');
      expect(exam.title, 'Ujian Akhir Semester');
      expect(exam.durationMin, 120);
      expect(exam.feeIdr, 50000);
      expect(exam.requireBiometric, true);
      expect(exam.requireGeofence, true);
      expect(exam.isEnrolled, true);
      expect(exam.courseCode, 'IF4501');

      final serialized = exam.toJson();
      expect(serialized['id'], exam.id);
      expect(serialized['fee_idr'], 50000);
    });

    test('computedStatus calculates status correctly', () {
      final now = DateTime.now();

      final futureExam = ExamModel(
        id: '1',
        courseId: 'c1',
        title: 'Masa Depan',
        startAt: now.add(const Duration(days: 2)),
        endAt: now.add(const Duration(days: 2, hours: 2)),
        durationMin: 60,
      );
      expect(futureExam.computedStatus, 'AKAN DATANG');
      expect(futureExam.statusVariant, NeoTagVariant.info);

      final activeExam = ExamModel(
        id: '2',
        courseId: 'c1',
        title: 'Sedang Berjalan',
        startAt: now.subtract(const Duration(minutes: 30)),
        endAt: now.add(const Duration(minutes: 30)),
        durationMin: 60,
      );
      expect(activeExam.computedStatus, 'BERLANGSUNG');
      expect(activeExam.statusVariant, NeoTagVariant.success);

      final pastExam = ExamModel(
        id: '3',
        courseId: 'c1',
        title: 'Sudah Lewat',
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
        durationMin: 60,
      );
      expect(pastExam.computedStatus, 'SELESAI');
      expect(pastExam.statusVariant, NeoTagVariant.muted);

      final draftExam = ExamModel(
        id: '4',
        courseId: 'c1',
        title: 'Draft',
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 2)),
        durationMin: 60,
        status: 'draft',
      );
      expect(draftExam.computedStatus, 'DRAFT');
    });

    test('copyWith immutably updates exam fields', () {
      final original = ExamModel(
        id: '1',
        courseId: 'c1',
        title: 'Judul Lama',
        startAt: DateTime.now(),
        endAt: DateTime.now().add(const Duration(hours: 1)),
        durationMin: 60,
        isEnrolled: false,
      );

      final updated = original.copyWith(isEnrolled: true, title: 'Judul Baru');
      expect(original.isEnrolled, false);
      expect(original.title, 'Judul Lama');
      expect(updated.isEnrolled, true);
      expect(updated.title, 'Judul Baru');
    });
  });

  group('QuestionModel and CourseModel Tests', () {
    test('QuestionModel correctly parses options array and json string', () {
      final q1 = QuestionModel.fromJson({
        'id': 'q1',
        'course_id': 'c1',
        'type': 'mcq',
        'body': 'Soal 1',
        'options': ['Opsi A', 'Opsi B', 'Opsi C'],
        'max_score': 10,
      });
      expect(q1.options?.length, 3);
      expect(q1.options?[0], 'Opsi A');

      final q2 = QuestionModel.fromJson({
        'id': 'q2',
        'course_id': 'c1',
        'type': 'mcq',
        'body': 'Soal 2',
        'options': '["Alpha", "Beta"]',
        'max_score': 5,
      });
      expect(q2.options?.length, 2);
      expect(q2.options?[1], 'Beta');
    });

    test('CourseModel correctly parses fromJson', () {
      final course = CourseModel.fromJson({
        'id': 'c1',
        'code': 'IF4501',
        'name': 'Pemrograman Mobile',
        'lecturer_name': 'Dr. Budi',
      });
      expect(course.code, 'IF4501');
      expect(course.name, 'Pemrograman Mobile');
      expect(course.lecturerName, 'Dr. Budi');
    });
  });
}
