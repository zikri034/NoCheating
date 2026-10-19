import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/services/sensor_integrity_service.dart';
import 'package:thereisnocheating/core/storage/local_exam_database.dart';
import 'package:thereisnocheating/features/exams/data/models/attempt_model.dart';
import 'package:thereisnocheating/features/exams/data/models/question_model.dart';
import 'package:thereisnocheating/features/exams/data/repositories/attempt_repository.dart';
import 'package:thereisnocheating/features/exams/presentation/providers/exam_runner_provider.dart';

class MockAttemptRepository extends AttemptRepository {
  MockAttemptRepository({super.localDb});

  @override
  Future<DateTime> fetchServerTime() async => DateTime.now();

  @override
  Future<Map<String, dynamic>> startOrResumeAttempt(
    String examId, {
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();
    final attempt = AttemptModel(
      id: 'att-1',
      examId: examId,
      studentId: 'stud-1',
      startedAt: now,
      serverDeadline: now.add(const Duration(minutes: 60)),
      status: 'in_progress',
      seed: 42,
    );

    final questions = [
      QuestionModel(
        id: 'q1',
        courseId: 'c1',
        type: 'mcq',
        body: 'Framework apa?',
        options: ['Flutter', 'React'],
        maxScore: 50,
      ),
      QuestionModel(
        id: 'q2',
        courseId: 'c1',
        type: 'essay',
        body: 'Jelaskan widget!',
        maxScore: 50,
      ),
    ];

    return {
      'attempt': attempt,
      'exam': {'id': examId, 'title': 'Ujian Mock', 'duration_min': 60, 'max_critical': 3},
      'questions': questions,
      'answers': [],
      'server_time': now,
    };
  }

  @override
  Future<void> syncAnswers(String attemptId, List<Map<String, dynamic>> answers) async {}

  @override
  Future<Map<String, dynamic>> recordViolation(
    String attemptId, {
    required String type,
    required String severity,
    Map<String, dynamic>? detail,
    DateTime? occurredAt,
  }) async {
    return {
      'violation': {'type': type, 'severity': severity},
      'critical_count': 1,
      'is_terminated': false,
    };
  }

  @override
  Future<Map<String, dynamic>> submitAttempt(String attemptId) async {
    return {
      'message': 'Ujian berhasil dikumpulkan',
      'attempt': {
        'id': attemptId,
        'status': 'graded',
        'total_score': 100.0,
      },
    };
  }
}

class MockSensorIntegrityService extends SensorIntegrityService {
  @override
  void startMonitoring({
    Stream<dynamic>? accelStream,
    Stream<dynamic>? gyroStream,
  }) {}

  @override
  void stopMonitoring() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamRunnerProvider Tests (F04 Pelaksanaan Ujian)', () {
    late ExamRunnerProvider runner;

    setUp(() {
      final mockRepo = MockAttemptRepository(
        localDb: LocalExamDatabase(useMemoryFallback: true),
      );
      runner = ExamRunnerProvider(
        repository: mockRepo,
        sensorService: MockSensorIntegrityService(),
      );
    });

    tearDown(() {
      runner.dispose();
    });

    test('initExamSession loads attempt, questions, and sets remaining time', () async {
      await runner.initExamSession('exam-1');

      expect(runner.isLoading, false);
      expect(runner.attempt?.id, 'att-1');
      expect(runner.questions.length, 2);
      expect(runner.remainingSeconds, greaterThan(3500)); // ~3600 seconds
      expect(runner.formattedRemainingTime.contains(':'), true);
      expect(runner.isTimeCritical, false);
    });

    test('selectOption and setAnswerText updates answer state and answered count', () async {
      await runner.initExamSession('exam-1');

      expect(runner.answeredCount, 0);
      expect(runner.unansweredCount, 2);

      // Answer Q1 (MCQ)
      runner.selectOption('q1', 'Flutter');
      expect(runner.isQuestionAnswered('q1'), true);
      expect(runner.answeredCount, 1);
      expect(runner.unansweredCount, 1);

      // Answer Q2 (Essay)
      runner.setAnswerText('q2', 'Widget adalah elemen UI.');
      expect(runner.isQuestionAnswered('q2'), true);
      expect(runner.answeredCount, 2);
      expect(runner.unansweredCount, 0);
    });

    test('toggleDoubt marks question as doubtful', () async {
      await runner.initExamSession('exam-1');

      expect(runner.isQuestionDoubtful('q1'), false);
      runner.toggleDoubt('q1');
      expect(runner.isQuestionDoubtful('q1'), true);
      runner.toggleDoubt('q1');
      expect(runner.isQuestionDoubtful('q1'), false);
    });

    test('navigation nextQuestion and prevQuestion changes currentIndex', () async {
      await runner.initExamSession('exam-1');

      expect(runner.currentIndex, 0);
      runner.nextQuestion();
      expect(runner.currentIndex, 1);
      runner.nextQuestion(); // boundary
      expect(runner.currentIndex, 1);

      runner.prevQuestion();
      expect(runner.currentIndex, 0);
      runner.prevQuestion(); // boundary
      expect(runner.currentIndex, 0);
    });

    test('submitExam successfully finalizes attempt and sets isSubmitted', () async {
      await runner.initExamSession('exam-1');
      runner.selectOption('q1', 'Flutter');

      final success = await runner.submitExam();
      expect(success, true);
      expect(runner.isSubmitted, true);
      expect(runner.submissionResult?['attempt']?['status'], 'graded');
    });

    test('handleViolation warns correctly without terminating', () async {
      await runner.initExamSession('exam-1');

      expect(runner.warnCount, 0);
      expect(runner.criticalCount, 0);
      expect(runner.isTerminated, false);

      await runner.handleViolation(ViolationEvent(
        type: 'device_shake',
        severity: 'warn',
        detail: {'magnitude': 16.5},
      ));

      expect(runner.warnCount, 1);
      expect(runner.criticalCount, 0);
      expect(runner.isTerminated, false);
      expect(runner.latestViolationAlert?.contains('device_shake'), true);
    });

    test('handleViolation critical increments criticalCount and terminates at maxCritical', () async {
      await runner.initExamSession('exam-1');

      await runner.handleViolation(ViolationEvent(
        type: 'mock_location',
        severity: 'critical',
      ));
      expect(runner.criticalCount, 1);
      expect(runner.isTerminated, false);

      await runner.handleViolation(ViolationEvent(
        type: 'geofence_exit',
        severity: 'critical',
      ));
      expect(runner.criticalCount, 2);
      expect(runner.isTerminated, false);

      await runner.handleViolation(ViolationEvent(
        type: 'app_background',
        severity: 'critical',
      ));
      expect(runner.criticalCount, 3);
      expect(runner.isTerminated, true);
    });
  });
}
