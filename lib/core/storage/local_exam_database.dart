import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../services/local_encryption_service.dart';

class LocalExamDatabase {
  static Database? _database;
  final LocalEncryptionService _encryptionService;

  // In-memory fallback map for test environments where sqflite ffi is not initialized
  final Map<String, String> _memAttempts = {};
  final Map<String, Map<String, dynamic>> _memDrafts = {};
  final List<Map<String, dynamic>> _memViolations = [];
  final bool _useMemoryFallback;

  LocalExamDatabase({
    LocalEncryptionService? encryptionService,
    this._useMemoryFallback = false,
  }) : _encryptionService = encryptionService ?? LocalEncryptionService();

  Future<Database?> _getDb() async {
    if (_useMemoryFallback || kIsWeb) return null;
    if (_database != null) return _database!;

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'safeexam_local.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS attempt_state (
              attempt_id TEXT PRIMARY KEY,
              exam_id TEXT NOT NULL,
              server_deadline TEXT NOT NULL,
              seed INTEGER NOT NULL,
              questions_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS answer_drafts (
              attempt_id TEXT NOT NULL,
              question_id TEXT NOT NULL,
              encrypted_payload TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_synced INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (attempt_id, question_id)
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS violation_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              attempt_id TEXT NOT NULL,
              type TEXT NOT NULL,
              severity TEXT NOT NULL,
              detail_json TEXT,
              occurred_at TEXT NOT NULL,
              is_synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS feedback_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              impression TEXT NOT NULL,
              suggestion TEXT,
              rating INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              is_synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS fx_cache (
              base TEXT NOT NULL,
              quote TEXT NOT NULL,
              rate REAL NOT NULL,
              updated_at TEXT NOT NULL,
              source TEXT NOT NULL,
              PRIMARY KEY (base, quote)
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS pairs_cache (
              id TEXT PRIMARY KEY,
              course_id TEXT NOT NULL,
              term TEXT NOT NULL,
              definition TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS notif_schedule (
              exam_id TEXT PRIMARY KEY,
              notif_ids TEXT NOT NULL,
              scheduled_at TEXT NOT NULL
            )
          ''');
        },
      );
      return _database;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAttemptState({
    required String attemptId,
    required String examId,
    required DateTime serverDeadline,
    required int seed,
    required List<Map<String, dynamic>> questionsJson,
  }) async {
    final db = await _getDb();
    final jsonStr = jsonEncode(questionsJson);
    final nowIso = DateTime.now().toIso8601String();

    if (db == null) {
      _memAttempts[attemptId] = jsonEncode({
        'attempt_id': attemptId,
        'exam_id': examId,
        'server_deadline': serverDeadline.toIso8601String(),
        'seed': seed,
        'questions_json': jsonStr,
        'created_at': nowIso,
      });
      return;
    }

    await db.insert(
      'attempt_state',
      {
        'attempt_id': attemptId,
        'exam_id': examId,
        'server_deadline': serverDeadline.toIso8601String(),
        'seed': seed,
        'questions_json': jsonStr,
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAttemptState(String attemptId) async {
    final db = await _getDb();
    if (db == null) {
      final raw = _memAttempts[attemptId];
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final rows = await db.query(
      'attempt_state',
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> saveAnswerDraft({
    required String attemptId,
    required String questionId,
    String? selectedOption,
    String? answerText,
    bool isSynced = false,
  }) async {
    final rawPayload = jsonEncode({
      'question_id': questionId,
      'selected_option': selectedOption,
      'answer_text': answerText,
    });

    final encrypted = await _encryptionService.encrypt(rawPayload);
    final nowIso = DateTime.now().toIso8601String();

    final db = await _getDb();
    if (db == null) {
      _memDrafts['$attemptId:$questionId'] = {
        'attempt_id': attemptId,
        'question_id': questionId,
        'encrypted_payload': encrypted,
        'updated_at': nowIso,
        'is_synced': isSynced ? 1 : 0,
      };
      return;
    }

    await db.insert(
      'answer_drafts',
      {
        'attempt_id': attemptId,
        'question_id': questionId,
        'encrypted_payload': encrypted,
        'updated_at': nowIso,
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDecryptedDrafts(String attemptId) async {
    final db = await _getDb();
    List<Map<String, dynamic>> rows = [];

    if (db == null) {
      rows = _memDrafts.entries
          .where((e) => e.key.startsWith('$attemptId:'))
          .map((e) => e.value)
          .toList();
    } else {
      rows = await db.query(
        'answer_drafts',
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
      );
    }

    final decryptedList = <Map<String, dynamic>>[];
    for (final r in rows) {
      try {
        final decryptedJson = await _encryptionService.decrypt(r['encrypted_payload'] as String);
        final map = jsonDecode(decryptedJson) as Map<String, dynamic>;
        map['is_synced'] = r['is_synced'] == 1;
        map['updated_at'] = r['updated_at'];
        decryptedList.add(map);
      } catch (_) {}
    }

    return decryptedList;
  }

  Future<void> markAnswersSynced(String attemptId, List<String> questionIds) async {
    final db = await _getDb();
    if (db == null) {
      for (final qid in questionIds) {
        final key = '$attemptId:$qid';
        if (_memDrafts.containsKey(key)) {
          _memDrafts[key]!['is_synced'] = 1;
        }
      }
      return;
    }

    for (final qid in questionIds) {
      await db.update(
        'answer_drafts',
        {'is_synced': 1},
        where: 'attempt_id = ? AND question_id = ?',
        whereArgs: [attemptId, qid],
      );
    }
  }

  Future<void> clearAttempt(String attemptId) async {
    final db = await _getDb();
    if (db == null) {
      _memAttempts.remove(attemptId);
      _memDrafts.removeWhere((k, _) => k.startsWith('$attemptId:'));
      return;
    }

    await db.delete('attempt_state', where: 'attempt_id = ?', whereArgs: [attemptId]);
    await db.delete('answer_drafts', where: 'attempt_id = ?', whereArgs: [attemptId]);
    await db.delete('violation_queue', where: 'attempt_id = ?', whereArgs: [attemptId]);
  }

  Future<int> queueViolation({
    required String attemptId,
    required String type,
    required String severity,
    Map<String, dynamic>? detail,
    required DateTime occurredAt,
  }) async {
    final db = await _getDb();
    final detailStr = detail != null ? jsonEncode(detail) : null;
    final occurredIso = occurredAt.toIso8601String();

    if (db == null) {
      final id = _memViolations.length + 1;
      _memViolations.add({
        'id': id,
        'attempt_id': attemptId,
        'type': type,
        'severity': severity,
        'detail_json': detailStr,
        'occurred_at': occurredIso,
        'is_synced': 0,
      });
      return id;
    }

    return await db.insert('violation_queue', {
      'attempt_id': attemptId,
      'type': type,
      'severity': severity,
      'detail_json': detailStr,
      'occurred_at': occurredIso,
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingViolations(String attemptId) async {
    final db = await _getDb();
    if (db == null) {
      return _memViolations
          .where((v) => v['attempt_id'] == attemptId && v['is_synced'] == 0)
          .toList();
    }
    return await db.query(
      'violation_queue',
      where: 'attempt_id = ? AND is_synced = 0',
      whereArgs: [attemptId],
      orderBy: 'id ASC',
    );
  }

  Future<void> markViolationsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _getDb();
    if (db == null) {
      for (final v in _memViolations) {
        if (ids.contains(v['id'])) {
          v['is_synced'] = 1;
        }
      }
      return;
    }
    await db.update(
      'violation_queue',
      {'is_synced': 1},
      where: 'id IN (${ids.join(',')})',
    );
  }

  // ---------- F14: FEEDBACK QUEUE (Offline support) ----------
  final List<Map<String, dynamic>> _memFeedbackQueue = [];

  Future<int> enqueueFeedback({
    required String impression,
    String? suggestion,
    required int rating,
    DateTime? createdAt,
  }) async {
    final nowIso = (createdAt ?? DateTime.now()).toIso8601String();
    final db = await _getDb();
    if (db == null) {
      final id = _memFeedbackQueue.length + 1;
      _memFeedbackQueue.add({
        'id': id,
        'impression': impression,
        'suggestion': suggestion,
        'rating': rating,
        'created_at': nowIso,
        'is_synced': 0,
      });
      return id;
    }

    return await db.insert('feedback_queue', {
      'impression': impression,
      'suggestion': suggestion,
      'rating': rating,
      'created_at': nowIso,
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingFeedbacks() async {
    final db = await _getDb();
    if (db == null) {
      return _memFeedbackQueue.where((f) => f['is_synced'] == 0).toList();
    }
    return await db.query(
      'feedback_queue',
      where: 'is_synced = 0',
      orderBy: 'id ASC',
    );
  }

  Future<void> markFeedbacksSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _getDb();
    if (db == null) {
      for (final f in _memFeedbackQueue) {
        if (ids.contains(f['id'])) {
          f['is_synced'] = 1;
        }
      }
      return;
    }
    await db.update(
      'feedback_queue',
      {'is_synced': 1},
      where: 'id IN (${ids.join(',')})',
    );
  }

  // ---------- F09: FX RATES CACHE ----------
  final Map<String, dynamic> _memFxCache = {};

  Future<void> saveFxRates({
    required String base,
    required Map<String, double> rates,
    required String source,
    required DateTime updatedAt,
  }) async {
    final nowIso = updatedAt.toIso8601String();
    final db = await _getDb();
    if (db == null) {
      _memFxCache[base] = {
        'base': base,
        'rates': rates,
        'source': source,
        'updated_at': nowIso,
      };
      return;
    }

    final batch = db.batch();
    rates.forEach((quote, rate) {
      batch.insert(
        'fx_cache',
        {
          'base': base,
          'quote': quote,
          'rate': rate,
          'source': source,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getCachedFxRates({String base = 'IDR'}) async {
    final db = await _getDb();
    if (db == null) {
      return _memFxCache[base];
    }
    final rows = await db.query(
      'fx_cache',
      where: 'base = ?',
      whereArgs: [base],
    );
    if (rows.isEmpty) return null;

    final rates = <String, double>{};
    for (final r in rows) {
      rates[r['quote'] as String] = (r['rate'] as num).toDouble();
    }
    return {
      'base': base,
      'rates': rates,
      'source': rows.first['source'] as String? ?? 'cache',
      'updated_at': rows.first['updated_at'] as String,
    };
  }

  // ---------- F11: STUDY PAIRS CACHE ----------
  final List<Map<String, dynamic>> _memPairsCache = [];

  Future<void> saveStudyPairs(List<Map<String, dynamic>> pairs) async {
    final db = await _getDb();
    if (db == null) {
      _memPairsCache.clear();
      _memPairsCache.addAll(pairs);
      return;
    }

    final batch = db.batch();
    for (final p in pairs) {
      batch.insert(
        'pairs_cache',
        {
          'id': p['id'] as String,
          'course_id': p['course_id'] as String,
          'term': p['term'] as String,
          'definition': p['definition'] as String,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedStudyPairs({String? courseId}) async {
    final db = await _getDb();
    if (db == null) {
      if (courseId == null) return List.from(_memPairsCache);
      return _memPairsCache.where((p) => p['course_id'] == courseId).toList();
    }

    if (courseId != null) {
      return await db.query(
        'pairs_cache',
        where: 'course_id = ?',
        whereArgs: [courseId],
      );
    }
    return await db.query('pairs_cache');
  }
}
