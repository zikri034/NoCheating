import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../../core/services/screen_protector_service.dart';
import '../../../../core/services/sensor_integrity_service.dart';
import '../../../../core/services/geofence_service.dart';
import '../../data/models/attempt_model.dart';
import '../../data/models/question_model.dart';
import '../../data/repositories/attempt_repository.dart';

class ExamRunnerProvider extends ChangeNotifier {
  final AttemptRepository _repository;
  final SensorIntegrityService _sensorService;
  final GeofenceService _geofenceService;

  ExamRunnerProvider({
    AttemptRepository? repository,
    SensorIntegrityService? sensorService,
    GeofenceService? geofenceService,
  })  : _repository = repository ?? AttemptRepository(),
        _sensorService = sensorService ?? SensorIntegrityService(),
        _geofenceService = geofenceService ?? GeofenceService();

  AttemptModel? _attempt;
  Map<String, dynamic>? _examMeta;
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;

  // Answers state: question_id -> {selected_option, answer_text, is_synced}
  final Map<String, Map<String, dynamic>> _answers = {};
  final Set<String> _doubtfulQuestions = {};

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _errorMessage;
  Map<String, dynamic>? _submissionResult;

  // S5 Integrity & Violation fields
  int _criticalCount = 0;
  int _warnCount = 0;
  int _maxCritical = 3;
  bool _isTerminated = false;
  String? _latestViolationAlert;
  final List<ViolationEvent> _violations = [];
  DateTime? _backgroundPausedAt;
  Timer? _geofenceMonitorTimer;
  int _secondsOutsideGeofence = 0;
  bool _isCalibrating = false;
  bool _isCalibrated = false;

  // Timer fields
  Timer? _tickerTimer;
  Timer? _localAutosaveTimer;
  Timer? _serverSyncTimer;
  Duration _serverTimeOffset = Duration.zero;
  int _remainingSeconds = 0;

  // Getters
  AttemptModel? get attempt => _attempt;
  Map<String, dynamic>? get examMeta => _examMeta;
  List<QuestionModel> get questions => _questions;
  int get currentIndex => _currentIndex;
  QuestionModel? get currentQuestion => _questions.isNotEmpty && _currentIndex < _questions.length
      ? _questions[_currentIndex]
      : null;

  Map<String, Map<String, dynamic>> get answers => _answers;
  Set<String> get doubtfulQuestions => _doubtfulQuestions;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isSubmitted => _isSubmitted;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get submissionResult => _submissionResult;
  int get remainingSeconds => _remainingSeconds;

  String get formattedRemainingTime {
    if (_remainingSeconds <= 0) return '00:00';
    final hours = _remainingSeconds ~/ 3600;
    final mins = (_remainingSeconds % 3600) ~/ 60;
    final secs = _remainingSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  bool get isTimeCritical => _remainingSeconds > 0 && _remainingSeconds < 300; // < 5 mins

  int get answeredCount {
    int count = 0;
    for (final q in _questions) {
      final ans = _answers[q.id];
      if (ans != null) {
        if (q.type == 'mcq' && ans['selected_option'] != null && (ans['selected_option'] as String).isNotEmpty) {
          count++;
        } else if (q.type == 'essay' && ans['answer_text'] != null && (ans['answer_text'] as String).trim().isNotEmpty) {
          count++;
        }
      }
    }
    return count;
  }

  int get unansweredCount => _questions.length - answeredCount;

  bool isQuestionAnswered(String questionId) {
    final ans = _answers[questionId];
    if (ans == null) return false;
    final opt = ans['selected_option'];
    final text = ans['answer_text'];
    return (opt != null && opt.toString().isNotEmpty) || (text != null && text.toString().trim().isNotEmpty);
  }

  bool isQuestionDoubtful(String questionId) => _doubtfulQuestions.contains(questionId);

  // S5 Getters
  int get criticalCount => _criticalCount;
  int get warnCount => _warnCount;
  int get maxCritical => _maxCritical;
  bool get isTerminated => _isTerminated;
  String? get latestViolationAlert => _latestViolationAlert;
  List<ViolationEvent> get violations => List.unmodifiable(_violations);
  bool get isCalibrating => _isCalibrating;
  bool get isCalibrated => _isCalibrated;
  SensorIntegrityService get sensorService => _sensorService;
  GeofenceService get geofenceService => _geofenceService;

  void clearViolationAlert() {
    _latestViolationAlert = null;
    notifyListeners();
  }

  /// 3-Second calibration before exam starts (PRD F05)
  Future<void> calibrateSensors() async {
    _isCalibrating = true;
    notifyListeners();
    try {
      await _sensorService.calibrate(duration: const Duration(seconds: 3));
      _isCalibrated = true;
    } catch (_) {
      _sensorService.setBaseline(9.8);
      _isCalibrated = true;
    } finally {
      _isCalibrating = false;
      notifyListeners();
    }
  }

  // Initialize and load exam session
  Future<void> initExamSession(
    String examId, {
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.startOrResumeAttempt(
        examId,
        latitude: latitude,
        longitude: longitude,
      );
      _attempt = data['attempt'] as AttemptModel;
      _examMeta = data['exam'] as Map<String, dynamic>?;
      _questions = data['questions'] as List<QuestionModel>;

      _maxCritical = (_examMeta?['max_critical'] as num?)?.toInt() ?? 3;
      _criticalCount = _attempt!.criticalCount;

      // Load existing answers from server & local cache
      final List answersList = data['answers'] as List? ?? [];
      for (final a in answersList) {
        final qid = a['question_id'] as String;
        _answers[qid] = {
          'selected_option': a['selected_option'],
          'answer_text': a['answer_text'],
          'is_synced': true,
        };
      }

      // Check local decrypted drafts in SQLite to restore any unsynced offline answers
      final localDrafts = await _repository.localDb.getDecryptedDrafts(_attempt!.id);
      for (final d in localDrafts) {
        final qid = d['question_id'] as String;
        if (!_answers.containsKey(qid) || d['is_synced'] == false) {
          _answers[qid] = {
            'selected_option': d['selected_option'],
            'answer_text': d['answer_text'],
            'is_synced': d['is_synced'] ?? false,
          };
        }
      }

      // Clock synchronization
      final serverTime = data['server_time'] as DateTime;
      _serverTimeOffset = serverTime.difference(DateTime.now());
      _updateRemainingSeconds();

      // Start sensor monitoring
      _sensorService.startMonitoring();

      // Start anti-screenshot protection
      try {
        await ScreenProtector.preventScreenshotOn().catchError((_) {});
      } catch (_) {}

      // Start geofence monitoring if required
      if (_examMeta?['require_geofence'] == true) {
        _startGeofenceMonitor();
      }

      // Start timers
      _startTimers();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  void _startTimers() {
    _tickerTimer?.cancel();
    _localAutosaveTimer?.cancel();
    _serverSyncTimer?.cancel();

    // 1-second countdown ticker
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingSeconds();
      if (_remainingSeconds <= 0 && !_isSubmitted && !_isSubmitting) {
        // Auto-submit when time expires (PRD F04.5)
        submitExam(isAutoSubmit: true);
      }
      notifyListeners();
    });

    // Local autosave every 5 seconds (PRD F04.4)
    _localAutosaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _performLocalAutosave();
    });

    // Server batch sync every 15 seconds (PRD F04.4)
    _serverSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _performServerSync();
    });
  }

  void _updateRemainingSeconds() {
    if (_attempt == null) return;
    final nowEffective = DateTime.now().add(_serverTimeOffset);
    final diff = _attempt!.serverDeadline.difference(nowEffective).inSeconds;
    _remainingSeconds = diff > 0 ? diff : 0;
  }

  // Answer management
  void selectOption(String questionId, String option) {
    final existing = _answers[questionId] ?? {};
    _answers[questionId] = {
      ...existing,
      'selected_option': option,
      'is_synced': false,
    };
    notifyListeners();
  }

  void setAnswerText(String questionId, String text) {
    final existing = _answers[questionId] ?? {};
    _answers[questionId] = {
      ...existing,
      'answer_text': text,
      'is_synced': false,
    };
    notifyListeners();
  }

  void toggleDoubt(String questionId) {
    if (_doubtfulQuestions.contains(questionId)) {
      _doubtfulQuestions.remove(questionId);
    } else {
      _doubtfulQuestions.add(questionId);
    }
    notifyListeners();
  }

  // Question navigation
  void selectQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      // Trigger sync on question change (PRD F04.4)
      _performLocalAutosave();
      _performServerSync();
      _currentIndex = index;
      notifyListeners();
    }
  }

  void nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      selectQuestion(_currentIndex + 1);
    }
  }

  void prevQuestion() {
    if (_currentIndex > 0) {
      selectQuestion(_currentIndex - 1);
    }
  }

  // Local Autosave (encrypted AES-GCM to SQLite)
  Future<void> _performLocalAutosave() async {
    if (_attempt == null) return;
    for (final entry in _answers.entries) {
      final qid = entry.key;
      final val = entry.value;
      if (val['is_synced'] == false) {
        await _repository.localDb.saveAnswerDraft(
          attemptId: _attempt!.id,
          questionId: qid,
          selectedOption: val['selected_option'] as String?,
          answerText: val['answer_text'] as String?,
          isSynced: false,
        );
      }
    }
  }

  // Server Sync
  Future<void> _performServerSync() async {
    if (_attempt == null) return;
    final unsynced = <Map<String, dynamic>>[];
    for (final entry in _answers.entries) {
      if (entry.value['is_synced'] == false) {
        unsynced.add({
          'question_id': entry.key,
          'selected_option': entry.value['selected_option'],
          'answer_text': entry.value['answer_text'],
        });
      }
    }

    if (unsynced.isEmpty) return;

    try {
      await _repository.syncAnswers(_attempt!.id, unsynced);
      for (final item in unsynced) {
        final qid = item['question_id'] as String;
        if (_answers.containsKey(qid)) {
          _answers[qid]!['is_synced'] = true;
        }
      }
      notifyListeners();
    } catch (_) {
      // Offline: answers remain safe in encrypted local SQLite
    }
  }

  // Submit attempt
  Future<bool> submitExam({bool isAutoSubmit = false}) async {
    if (_attempt == null || _isSubmitting || _isSubmitted) return false;
    _isSubmitting = true;
    notifyListeners();

    try {
      // 1. Flush any pending unsynced answers
      await _performServerSync();

      // 2. Submit to server
      final res = await _repository.submitAttempt(_attempt!.id);
      _submissionResult = res;
      _isSubmitted = true;
      _isSubmitting = false;

      // Stop timers & monitors
      _tickerTimer?.cancel();
      _localAutosaveTimer?.cancel();
      _serverSyncTimer?.cancel();
      _geofenceMonitorTimer?.cancel();
      _sensorService.stopMonitoring();
      try {
        await ScreenProtector.preventScreenshotOff().catchError((_) {});
      } catch (_) {}

      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Handle detected sensor or integrity violation
  Future<void> handleViolation(ViolationEvent event) async {
    _violations.add(event);
    _latestViolationAlert = event.severity == 'critical'
        ? 'PELANGGARAN KRITIS: ${event.type}'
        : 'PERINGATAN INTEGRITAS: ${event.type}';

    if (event.severity == 'critical') {
      _criticalCount++;
    } else {
      _warnCount++;
    }
    notifyListeners();

    if (_attempt != null) {
      try {
        final res = await _repository.recordViolation(
          _attempt!.id,
          type: event.type,
          severity: event.severity,
          detail: event.detail,
          occurredAt: event.occurredAt,
        );

        if (res['is_terminated'] == true || _criticalCount >= _maxCritical) {
          _isTerminated = true;
          _errorMessage = 'Ujian dihentikan karena mencapai batas maksimal pelanggaran kritis.';
          // Auto-submit attempt with terminated status
          await submitExam(isAutoSubmit: true);
        }
      } catch (_) {}
    }
  }

  // Handle app lifecycle changes (Background detection - PRD F05)
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (_isSubmitted || _isTerminated) return;

    if (state == AppLifecycleState.paused) {
      _backgroundPausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundPausedAt != null) {
      final pausedSeconds = DateTime.now().difference(_backgroundPausedAt!).inSeconds;
      _backgroundPausedAt = null;

      if (SensorIntegrityService.isBackgroundCritical(pausedSeconds)) {
        handleViolation(ViolationEvent(
          type: 'app_background',
          severity: 'critical',
          detail: {'paused_seconds': pausedSeconds},
        ));
      }
    }
  }

  // Geofence periodic monitor (PRD F05 & F06)
  void _startGeofenceMonitor() {
    _geofenceMonitorTimer?.cancel();
    _geofenceMonitorTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isSubmitted || _isTerminated || _examMeta == null) return;
      if (_examMeta!['venue_lat'] == null || _examMeta!['venue_lng'] == null) return;

      final lat = (_examMeta!['venue_lat'] as num).toDouble();
      final lng = (_examMeta!['venue_lng'] as num).toDouble();
      final radius = (_examMeta!['venue_radius_m'] as num?)?.toDouble() ?? 100.0;

      final status = await _geofenceService.checkGeofence(
        venueLat: lat,
        venueLng: lng,
        radiusMeters: radius,
      );

      if (status != null) {
        if (status.isMocked) {
          handleViolation(ViolationEvent(
            type: 'mock_location',
            severity: 'critical',
          ));
        } else if (!status.isInside) {
          _secondsOutsideGeofence += 10;
          if (_secondsOutsideGeofence >= 30) {
            handleViolation(ViolationEvent(
              type: 'geofence_exit',
              severity: 'critical',
              detail: {
                'out_seconds': _secondsOutsideGeofence,
                'distance_meters': status.distanceMeters.round(),
              },
            ));
          }
        } else {
          _secondsOutsideGeofence = 0;
        }
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _localAutosaveTimer?.cancel();
    _serverSyncTimer?.cancel();
    _geofenceMonitorTimer?.cancel();
    _sensorService.dispose();
    try {
      ScreenProtector.preventScreenshotOff().catchError((_) {});
    } catch (_) {}
    super.dispose();
  }
}
