import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TimezoneConvertedItem {
  final String zoneCode;
  final String zoneName;
  final String locationId;
  final DateTime dateTime;
  final String formattedTime;
  final String dayOffset;

  TimezoneConvertedItem({
    required this.zoneCode,
    required this.zoneName,
    required this.locationId,
    required this.dateTime,
    required this.formattedTime,
    required this.dayOffset,
  });
}

class TimezoneService {
  static bool _initialized = false;

  static void initialize() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      // Set local location to match device timezone (PRD F15)
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      String locationName = 'Asia/Jakarta'; // Default WIB (UTC+7)
      if (offsetHours == 8) {
        locationName = 'Asia/Makassar'; // WITA (UTC+8)
      } else if (offsetHours == 9) {
        locationName = 'Asia/Jayapura'; // WIT (UTC+9)
      } else if (offsetHours == 0) {
        locationName = 'UTC';
      } else if (offsetHours == 1) {
        locationName = 'Europe/London';
      }
      try {
        tz.setLocalLocation(tz.getLocation(locationName));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
        } catch (_) {}
      }
      _initialized = true;
    }
  }

  static const List<Map<String, String>> supportedZones = [
    {'code': 'WIB', 'name': 'Waktu Indonesia Barat', 'location': 'Asia/Jakarta'},
    {'code': 'WITA', 'name': 'Waktu Indonesia Tengah', 'location': 'Asia/Makassar'},
    {'code': 'WIT', 'name': 'Waktu Indonesia Timur', 'location': 'Asia/Jayapura'},
    {'code': 'London', 'name': 'London (GMT / BST)', 'location': 'Europe/London'},
  ];

  /// Convert a given UTC or local DateTime to all 4 target zones
  static List<TimezoneConvertedItem> convertToAllZones(DateTime sourceTime, {String sourceZoneCode = 'WIB'}) {
    initialize();

    // Determine UTC reference
    final DateTime utcTime = sourceTime.isUtc ? sourceTime : sourceTime.toUtc();

    return supportedZones.map((z) {
      final location = tz.getLocation(z['location']!);
      final tzDateTime = tz.TZDateTime.from(utcTime, location);

      // Compute day offset relative to local source date
      final int diffDays = DateTime(tzDateTime.year, tzDateTime.month, tzDateTime.day)
          .difference(DateTime(sourceTime.year, sourceTime.month, sourceTime.day))
          .inDays;

      String dayOffset = '';
      if (diffDays > 0) {
        dayOffset = '+$diffDays hari';
      } else if (diffDays < 0) {
        dayOffset = '$diffDays hari';
      }

      final formatted = DateFormat('dd MMM yyyy, HH:mm').format(tzDateTime);

      return TimezoneConvertedItem(
        zoneCode: z['code']!,
        zoneName: z['name']!,
        locationId: z['location']!,
        dateTime: tzDateTime,
        formattedTime: formatted,
        dayOffset: dayOffset,
      );
    }).toList();
  }
}
