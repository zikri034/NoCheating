import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'timezone_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    TimezoneService.initialize();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;

      // Request notification permissions for Android 13+
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  /// Schedule exam reminder notifications (H-1 at 09:00 and 15 mins before start)
  Future<void> scheduleExamReminders({
    required String examId,
    required String title,
    required DateTime startAt,
  }) async {
    if (!_initialized || kIsWeb) return;

    final baseId = examId.hashCode.abs() % 100000;
    final now = DateTime.now();

    // 1. 15 minutes before exam starts
    final fifteenMinsBefore = startAt.subtract(const Duration(minutes: 15));
    if (fifteenMinsBefore.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: baseId + 1,
          title: 'Pengingat Ujian: $title',
          body: 'Ujian akan dimulai dalam 15 menit. Pastikan baterai dan koneksi Anda siap!',
          scheduledDate: tz.TZDateTime.from(fifteenMinsBefore, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'exam_reminders',
              'Pengingat Ujian',
              channelDescription: 'Notifikasi jadwal dan pengingat ujian SafeExam',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[NotificationService] Error scheduling 15m reminder: $e');
      }
    }

    // 2. Exam Started Notification
    if (startAt.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: baseId + 2,
          title: 'Ujian Dimulai: $title',
          body: 'Sesi ujian telah aktif! Buka SafeExam sekarang untuk memulai pengerjaan.',
          scheduledDate: tz.TZDateTime.from(startAt, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'exam_starts',
              'Ujian Dimulai',
              channelDescription: 'Notifikasi saat sesi ujian resmi dimulai',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[NotificationService] Error scheduling start reminder: $e');
      }
    }
  }

  /// Display immediate notification when exam score is finalized
  Future<void> showGradeReadyNotification({
    required String examTitle,
    required double finalScore,
  }) async {
    if (!_initialized || kIsWeb) return;

    try {
      await _plugin.show(
        id: DateTime.now().millisecond,
        title: 'Nilai Ujian Siap!',
        body: 'Nilai ujian "$examTitle" telah difinalisasi dosen: Skor Anda $finalScore.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'exam_results',
            'Hasil Ujian',
            channelDescription: 'Notifikasi publikasi dan finalisasi nilai ujian',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing grade notification: $e');
    }
  }

  /// Cancel all reminders for an exam
  Future<void> cancelExamReminders(String examId) async {
    if (!_initialized || kIsWeb) return;
    final baseId = examId.hashCode.abs() % 100000;
    try {
      await _plugin.cancel(id: baseId + 1);
      await _plugin.cancel(id: baseId + 2);
    } catch (_) {}
  }
}
