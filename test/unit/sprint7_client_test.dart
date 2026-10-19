import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/services/timezone_service.dart';
import 'package:thereisnocheating/core/storage/local_exam_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 7 (F08) — TimezoneService Tests', () {
    setUpAll(() {
      TimezoneService.initialize();
    });

    test('convertToAllZones converts UTC/local time into WIB, WITA, WIT, and London', () {
      // 2026-10-19 12:00:00 WIB (which is 05:00:00 UTC)
      final sourceWib = DateTime.utc(2026, 10, 19, 5, 0, 0);

      final zones = TimezoneService.convertToAllZones(sourceWib);
      expect(zones.length, 4);

      final wib = zones.firstWhere((z) => z.zoneCode == 'WIB');
      final wita = zones.firstWhere((z) => z.zoneCode == 'WITA');
      final wit = zones.firstWhere((z) => z.zoneCode == 'WIT');
      final london = zones.firstWhere((z) => z.zoneCode == 'London');

      expect(wib.dateTime.hour, 12);
      expect(wita.dateTime.hour, 13);
      expect(wit.dateTime.hour, 14);

      // In October (before last Sunday), London is in BST (UTC+1) => 05:00 UTC + 1 = 06:00
      expect(london.dateTime.hour, 6);
    });
  });

  group('Sprint 7 (F09, F11, F14) — LocalExamDatabase Sprint 7 Offline Storage Tests', () {
    late LocalExamDatabase localDb;

    setUp(() {
      localDb = LocalExamDatabase(useMemoryFallback: true);
    });

    test('F14: enqueueFeedback stores offline feedback and marks as synced', () async {
      final id = await localDb.enqueueFeedback(
        impression: 'Materi mobile programming sangat praktis!',
        suggestion: 'Tambahkan studi kasus arsitektur offline-first.',
        rating: 5,
      );

      expect(id, greaterThan(0));

      final pending = await localDb.getPendingFeedbacks();
      expect(pending.length, 1);
      expect(pending.first['rating'], 5);
      expect(pending.first['is_synced'], 0);

      await localDb.markFeedbacksSynced([id]);
      final pendingAfter = await localDb.getPendingFeedbacks();
      expect(pendingAfter.isEmpty, true);
    });

    test('F09: saveFxRates caches currency rates and retrieves correctly', () async {
      final now = DateTime.now();
      await localDb.saveFxRates(
        base: 'IDR',
        rates: {
          'USD': 0.00006154,
          'EUR': 0.00005714,
          'MYR': 0.00027397,
          'JPY': 0.00921659,
        },
        source: 'live',
        updatedAt: now,
      );

      final cached = await localDb.getCachedFxRates(base: 'IDR');
      expect(cached, isNotNull);
      expect(cached!['base'], 'IDR');
      expect((cached['rates'] as Map)['USD'], 0.00006154);
      expect((cached['rates'] as Map)['JPY'], 0.00921659);
    });

    test('F11: saveStudyPairs stores pairs in local memory and filters by course', () async {
      await localDb.saveStudyPairs([
        {
          'id': 'p1',
          'course_id': 'c1',
          'term': 'Widget',
          'definition': 'Komponen dasar UI Flutter',
        },
        {
          'id': 'p2',
          'course_id': 'c2',
          'term': 'SQL',
          'definition': 'Structured Query Language',
        },
      ]);

      final allPairs = await localDb.getCachedStudyPairs();
      expect(allPairs.length, 2);

      final c1Pairs = await localDb.getCachedStudyPairs(courseId: 'c1');
      expect(c1Pairs.length, 1);
      expect(c1Pairs.first['term'], 'Widget');
    });
  });
}
