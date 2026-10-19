import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/storage/local_exam_database.dart';
import 'package:thereisnocheating/core/services/local_encryption_service.dart';
import 'encryption_service_test.dart';

void main() {
  group('LocalExamDatabase Tests (F04 Autosave & Cache)', () {
    late LocalExamDatabase db;
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
      final enc = LocalEncryptionService(storage: mockStorage);
      db = LocalExamDatabase(encryptionService: enc, useMemoryFallback: true);
    });

    test('saveAttemptState and getAttemptState stores attempt metadata', () async {
      final deadline = DateTime.now().add(const Duration(hours: 1));
      await db.saveAttemptState(
        attemptId: 'att-123',
        examId: 'exam-456',
        serverDeadline: deadline,
        seed: 9876,
        questionsJson: [
          {'id': 'q1', 'body': 'Soal 1', 'type': 'mcq'}
        ],
      );

      final state = await db.getAttemptState('att-123');
      expect(state, isNotNull);
      expect(state?['attempt_id'], 'att-123');
      expect(state?['seed'], 9876);
    });

    test('saveAnswerDraft encrypts payload and retrieves decrypted', () async {
      await db.saveAnswerDraft(
        attemptId: 'att-123',
        questionId: 'q-mcq-1',
        selectedOption: 'Flutter',
        isSynced: false,
      );

      final drafts = await db.getDecryptedDrafts('att-123');
      expect(drafts.length, 1);
      expect(drafts[0]['question_id'], 'q-mcq-1');
      expect(drafts[0]['selected_option'], 'Flutter');
      expect(drafts[0]['is_synced'], false);

      await db.markAnswersSynced('att-123', ['q-mcq-1']);
      final updatedDrafts = await db.getDecryptedDrafts('att-123');
      expect(updatedDrafts[0]['is_synced'], true);
    });
  });
}
