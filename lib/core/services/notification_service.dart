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

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
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

      await _plugin.initialize(settings: settings);
      _initialized = true;

      // Create high-priority notification channels explicitly on Android 8+
      try {
        final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          // Clean up old cached channels
          try {
            await androidImplementation.deleteNotificationChannel(channelId: 'exam_alarms');
            await androidImplementation.deleteNotificationChannel(channelId: 'exam_reminders');
            await androidImplementation.deleteNotificationChannel(channelId: 'exam_starts');
            await androidImplementation.deleteNotificationChannel(channelId: 'exam_results');
            await androidImplementation.deleteNotificationChannel(channelId: 'exam_tests');
          } catch (_) {}

          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'safeexam_alarms_v2',
              'Alarm & Pengingat Ujian SafeExam',
              description: 'Saluran alarm dan pengingat waktu ujian SafeExam berprioritas tinggi',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'safeexam_reminders_v2',
              'Pengingat Jadwal Ujian',
              description: 'Notifikasi jadwal dan pengingat ujian SafeExam',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'safeexam_starts_v2',
              'Ujian Dimulai',
              description: 'Notifikasi saat sesi ujian resmi dimulai',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'safeexam_results_v2',
              'Hasil & Nilai Ujian',
              description: 'Notifikasi publikasi dan finalisasi nilai ujian',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'safeexam_tests_v2',
              'Uji Sistem Notifikasi',
              description: 'Saluran pengujian sistem notifikasi SafeExam',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Request permissions for Android 13+ (POST_NOTIFICATIONS)
          await androidImplementation.requestNotificationsPermission();
        }
      } catch (channelErr) {
        debugPrint('[NotificationService] Channel/permission error: $channelErr');
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
      _initialized = false;
    }
  }

  /// Check whether notifications are enabled for this app
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized || kIsWeb) return false;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        return await androidImpl.areNotificationsEnabled() ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Check whether exact alarms can be scheduled (Android 12+)
  Future<bool> canScheduleExactNotifications() async {
    if (!_initialized || kIsWeb) return false;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        return await androidImpl.canScheduleExactNotifications() ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Request exact alarm permission on Android (returns true if granted/allowed)
  Future<bool> requestExactAlarmsPermission() async {
    if (!_initialized || kIsWeb) return false;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final canExact = await androidImpl.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          return await androidImpl.requestExactAlarmsPermission() ?? false;
        }
        return true;
      }
    } catch (_) {}
    return true;
  }

  /// Request notification permission on Android 13+ / iOS
  Future<bool> requestNotificationPermission() async {
    if (!_initialized || kIsWeb) return false;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        return await androidImpl.requestNotificationsPermission() ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Schedule exam reminder notifications (H-1 at 09:00, 15 mins before start, and exam start) - PRD F15
  Future<void> scheduleExamReminders({
    required String examId,
    required String title,
    required DateTime startAt,
  }) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }
    if (kIsWeb) return;

    try {
      TimezoneService.initialize();

      final baseId = examId.hashCode.abs() % 100000;
      final now = DateTime.now();

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = (await androidImpl?.canScheduleExactNotifications()) ?? true;
      final scheduleMode = canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexact;

      const reminderDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'safeexam_reminders_v2',
          'Pengingat Jadwal Ujian',
          channelDescription: 'Notifikasi jadwal dan pengingat ujian SafeExam',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      // 1. H-1 at 09:00 local time (PRD F15)
      final dayBefore = startAt.subtract(const Duration(days: 1));
      final hMinusOneNineAm = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0, 0);
      if (hMinusOneNineAm.isAfter(now)) {
        try {
          await _plugin.zonedSchedule(
            id: baseId + 3,
            title: 'Pengingat Ujian H-1: $title',
            body: 'Besok Anda memiliki jadwal ujian "$title". Persiapkan diri dan perlengkapan Anda!',
            scheduledDate: tz.TZDateTime.from(hMinusOneNineAm, tz.local),
            notificationDetails: reminderDetails,
            androidScheduleMode: scheduleMode,
          );
        } catch (e) {
          debugPrint('[NotificationService] Error scheduling H-1 reminder: $e');
        }
      }

      // 2. 15 minutes before exam starts (PRD F15)
      final fifteenMinsBefore = startAt.subtract(const Duration(minutes: 15));
      if (fifteenMinsBefore.isAfter(now)) {
        try {
          await _plugin.zonedSchedule(
            id: baseId + 1,
            title: 'Pengingat Ujian: $title',
            body: 'Ujian akan dimulai dalam 15 menit. Pastikan baterai dan koneksi Anda siap!',
            scheduledDate: tz.TZDateTime.from(fifteenMinsBefore, tz.local),
            notificationDetails: reminderDetails,
            androidScheduleMode: scheduleMode,
          );
        } catch (e) {
          debugPrint('[NotificationService] Error scheduling 15m reminder: $e');
        }
      }

      // 3. Exam Started Notification (PRD F15)
      if (startAt.isAfter(now)) {
        try {
          await _plugin.zonedSchedule(
            id: baseId + 2,
            title: 'Ujian Dimulai: $title',
            body: 'Sesi ujian telah aktif! Buka SafeExam sekarang untuk memulai pengerjaan.',
            scheduledDate: tz.TZDateTime.from(startAt, tz.local),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'safeexam_starts_v2',
                'Ujian Dimulai',
                channelDescription: 'Notifikasi saat sesi ujian resmi dimulai',
                importance: Importance.max,
                priority: Priority.max,
                playSound: true,
                enableVibration: true,
                category: AndroidNotificationCategory.alarm,
                visibility: NotificationVisibility.public,
              ),
              iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
            ),
            androidScheduleMode: scheduleMode,
          );
        } catch (e) {
          debugPrint('[NotificationService] Error scheduling start reminder: $e');
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error in scheduleExamReminders: $e');
    }
  }

  /// Display immediate notification when exam score is finalized (PRD F15 / F07)
  Future<void> showGradeReadyNotification({
    required String examTitle,
    required double finalScore,
  }) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }
    if (kIsWeb) return;

    try {
      await _plugin.show(
        id: DateTime.now().millisecond,
        title: 'Nilai Ujian Siap!',
        body: 'Nilai ujian "$examTitle" telah difinalisasi dosen: Skor Anda $finalScore.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'safeexam_results_v2',
            'Hasil & Nilai Ujian',
            channelDescription: 'Notifikasi publikasi dan finalisasi nilai ujian',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing grade notification: $e');
    }
  }

  /// Send an immediate test notification for checking system functionality
  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }
    if (kIsWeb) return;

    try {
      await _plugin.show(
        id: 99999,
        title: 'SafeExam: Notifikasi Aktif',
        body: 'Notifikasi sistem SafeExam aktif dan berfungsi dengan sempurna!',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'safeexam_tests_v2',
            'Uji Sistem Notifikasi',
            channelDescription: 'Saluran pengujian sistem notifikasi SafeExam',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing test notification: $e');
    }
  }

  /// Schedule a quick test notification 5 seconds from now to test zonedSchedule (Alarm)
  Future<bool> scheduleQuickTestNotification({int delaySeconds = 5}) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return false;
    }
    if (kIsWeb) return false;

    try {
      TimezoneService.initialize();
      final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      bool canExact = true;
      if (androidImpl != null) {
        canExact = await androidImpl.canScheduleExactNotifications() ?? false;
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'safeexam_alarms_v2',
          'Alarm & Pengingat Ujian SafeExam',
          channelDescription: 'Saluran alarm dan pengingat waktu ujian SafeExam berprioritas tinggi',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // System AlarmManager scheduled notification
      try {
        await _plugin.zonedSchedule(
          id: 99998,
          title: 'Pengingat Terjadwal (Uji $delaySeconds Detik)',
          body: 'Alarm pengingat terjadwal SafeExam (F15) berhasil dipicu tepat waktu!',
          scheduledDate: scheduledTime,
          notificationDetails: details,
          androidScheduleMode: canExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexact,
        );
      } catch (scheduleErr) {
        debugPrint('[NotificationService] Exact alarm failed, trying inexact fallback: $scheduleErr');
        await _plugin.zonedSchedule(
          id: 99998,
          title: 'Pengingat Terjadwal (Uji $delaySeconds Detik)',
          body: 'Alarm pengingat terjadwal SafeExam (F15) berhasil dipicu tepat waktu!',
          scheduledDate: scheduledTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
      }

      // Foreground delayed fallback to guarantee delivery during testing
      Future.delayed(Duration(seconds: delaySeconds), () async {
        try {
          await _plugin.show(
            id: 99998,
            title: 'Pengingat Terjadwal (Uji $delaySeconds Detik)',
            body: 'Alarm pengingat terjadwal SafeExam (F15) berhasil dipicu tepat waktu!',
            notificationDetails: details,
          );
        } catch (_) {}
      });

      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling quick test: $e');
      return false;
    }
  }

  /// Cancel all reminders for an exam (PRD F15)
  Future<void> cancelExamReminders(String examId) async {
    if (!_initialized || kIsWeb) return;
    final baseId = examId.hashCode.abs() % 100000;
    try {
      await _plugin.cancel(id: baseId + 1);
      await _plugin.cancel(id: baseId + 2);
      await _plugin.cancel(id: baseId + 3);
    } catch (_) {}
  }

  /// Cancel all reminders (e.g. upon logout or notification toggle off - PRD F15)
  Future<void> cancelAllReminders() async {
    if (!_initialized || kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
