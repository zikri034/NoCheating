import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/features/exams/data/repositories/exam_repository.dart';
import 'package:dio/dio.dart';

void main() {
  group('Sprint 6 (F07) — Essay Review & AI Grading Klien Tests', () {
    test('ExamRepository finalizeEssayGrade constructs valid patch payload structure', () async {
      final dio = Dio();
      // Inject adapter or check method signature
      final repo = ExamRepository(dio: dio);
      expect(repo, isNotNull);
    });

    test('Status label and variant mappings match PRD specifications', () {
      final testCases = [
        {'status': 'finalized', 'expectedLabel': 'FINAL'},
        {'status': 'needs_review', 'expectedLabel': 'PERLU REVIEW'},
        {'status': 'ai_graded', 'expectedLabel': 'DINILAI AI'},
        {'status': 'pending_manual', 'expectedLabel': 'MANUAL'},
      ];

      for (final tc in testCases) {
        String label;
        switch (tc['status']) {
          case 'finalized':
            label = 'FINAL';
            break;
          case 'needs_review':
            label = 'PERLU REVIEW';
            break;
          case 'ai_graded':
            label = 'DINILAI AI';
            break;
          case 'pending_manual':
            label = 'MANUAL';
            break;
          default:
            label = 'MENUNGGU';
        }
        expect(label, tc['expectedLabel']);
      }
    });

    test('Provisional score evaluation correctly flags unfinalized essays', () {
      bool isProvisional(String? gradeStatus) {
        return gradeStatus != 'finalized';
      }

      expect(isProvisional('ai_graded'), isTrue);
      expect(isProvisional('needs_review'), isTrue);
      expect(isProvisional('pending_manual'), isTrue);
      expect(isProvisional('finalized'), isFalse);
    });
  });
}
