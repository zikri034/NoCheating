import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_exam_database.dart';
import '../models/attempt_model.dart';
import '../models/question_model.dart';

class AttemptRepository {
  final Dio _dio;
  final LocalExamDatabase _localDb;

  AttemptRepository({Dio? dio, LocalExamDatabase? localDb})
      : _dio = dio ?? DioClient.create(),
        _localDb = localDb ?? LocalExamDatabase();

  LocalExamDatabase get localDb => _localDb;

  Future<DateTime> fetchServerTime() async {
    try {
      final res = await _dio.get('/time');
      final timeStr = res.data['time'] as String;
      return DateTime.parse(timeStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<Map<String, dynamic>> startOrResumeAttempt(
    String examId, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _dio.post(
        '/exams/$examId/attempts',
        data: payload.isNotEmpty ? payload : null,
      );
      final data = response.data as Map<String, dynamic>;

      final attempt = AttemptModel.fromJson(data['attempt'] as Map<String, dynamic>);
      final List rawQuestions = data['questions'] as List? ?? [];
      final questions = rawQuestions.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();
      final List rawAnswers = data['answers'] as List? ?? [];

      // Cache attempt state locally in SQLite
      await _localDb.saveAttemptState(
        attemptId: attempt.id,
        examId: examId,
        serverDeadline: attempt.serverDeadline,
        seed: attempt.seed,
        questionsJson: questions.map((q) => q.toJson()).toList(),
      );

      // Cache existing answers locally
      for (final a in rawAnswers) {
        await _localDb.saveAnswerDraft(
          attemptId: attempt.id,
          questionId: a['question_id'] as String,
          selectedOption: a['selected_option'] as String?,
          answerText: a['answer_text'] as String?,
          isSynced: true,
        );
      }

      final serverTime = DateTime.tryParse(data['server_time']?.toString() ?? '') ?? DateTime.now();

      return {
        'attempt': attempt,
        'exam': data['exam'],
        'questions': questions,
        'answers': rawAnswers,
        'server_time': serverTime,
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memulai ujian';
      throw Exception(msg);
    }
  }

  Future<void> syncAnswers(String attemptId, List<Map<String, dynamic>> answers) async {
    if (answers.isEmpty) return;
    try {
      await _dio.put('/attempts/$attemptId/answers', data: {
        'answers': answers,
      });

      // Mark local answers as synced
      final questionIds = answers.map((a) => a['question_id'] as String).toList();
      await _localDb.markAnswersSynced(attemptId, questionIds);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal mensinkronkan jawaban';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> submitAttempt(String attemptId) async {
    try {
      final response = await _dio.post('/attempts/$attemptId/submit');
      final data = response.data as Map<String, dynamic>;

      // Clear local attempt drafts upon successful verified submission
      await _localDb.clearAttempt(attemptId);

      return data;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal mengumpulkan ujian';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> fetchAttemptResult(String attemptId) async {
    try {
      final response = await _dio.get('/attempts/$attemptId/result');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat hasil ujian';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> fetchExamResultByExamId(String examId) async {
    try {
      final response = await _dio.get('/exams/$examId/my-result');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat hasil ujian';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> recordViolation(
    String attemptId, {
    required String type,
    required String severity,
    Map<String, dynamic>? detail,
    DateTime? occurredAt,
  }) async {
    final timestamp = occurredAt ?? DateTime.now();

    // 1. Queue locally in SQLite
    final localId = await _localDb.queueViolation(
      attemptId: attemptId,
      type: type,
      severity: severity,
      detail: detail,
      occurredAt: timestamp,
    );

    // 2. Attempt sending immediately to server
    try {
      final response = await _dio.post(
        '/attempts/$attemptId/violations',
        data: {
          'type': type,
          'severity': severity,
          'detail': ?detail,
          'occurred_at': timestamp.toIso8601String(),
        },
      );

      // 3. Mark as synced on success
      await _localDb.markViolationsSynced([localId]);
      return response.data as Map<String, dynamic>;
    } catch (_) {
      // Offline: will be synced when connectivity restores
      return {
        'offline_queued': true,
        'local_id': localId,
        'type': type,
        'severity': severity,
      };
    }
  }

  Future<void> syncPendingViolations(String attemptId) async {
    final pending = await _localDb.getPendingViolations(attemptId);
    if (pending.isEmpty) return;

    final syncedIds = <int>[];
    for (final v in pending) {
      try {
        final id = v['id'] as int;
        await _dio.post(
          '/attempts/$attemptId/violations',
          data: {
            'type': v['type'],
            'severity': v['severity'],
            if (v['detail_json'] != null)
              'detail': v['detail_json'],
            'occurred_at': v['occurred_at'],
          },
        );
        syncedIds.add(id);
      } catch (_) {
        break; // Stop if offline
      }
    }

    if (syncedIds.isNotEmpty) {
      await _localDb.markViolationsSynced(syncedIds);
    }
  }
}
