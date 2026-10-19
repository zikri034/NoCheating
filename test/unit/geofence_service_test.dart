import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/core/services/geofence_service.dart';

void main() {
  group('GeofenceService (F06 Logic & Distance Calculation)', () {
    test('calculateDistanceMeters calculates accurate distance between two points', () {
      // Monas Jakarta (-6.175392, 106.827153)
      const lat1 = -6.175392;
      const lon1 = 106.827153;

      // Same coordinate -> distance is 0
      expect(GeofenceService.calculateDistanceMeters(lat1, lon1, lat1, lon1), closeTo(0, 0.1));

      // Coordinate ~38 meters away
      const lat2 = -6.17505;
      const lon2 = 106.827153;
      final dist = GeofenceService.calculateDistanceMeters(lat1, lon1, lat2, lon2);
      expect(dist, greaterThan(35));
      expect(dist, lessThan(45));

      // Bandung (~120 km away)
      const latBdg = -6.917464;
      const lonBdg = 107.619123;
      final distBdg = GeofenceService.calculateDistanceMeters(lat1, lon1, latBdg, lonBdg);
      expect(distBdg, greaterThan(110000)); // > 110 km
      expect(distBdg, lessThan(135000)); // < 135 km
    });

    test('isInside evaluates points inside and outside radius', () {
      const venueLat = -6.175392;
      const venueLon = 106.827153;
      const radiusMeters = 100.0;

      // Inside radius (~38m)
      expect(GeofenceService.isInside(-6.17505, venueLon, venueLat, venueLon, radiusMeters), isTrue);

      // Outside radius (~380m)
      expect(GeofenceService.isInside(-6.172, venueLon, venueLat, venueLon, radiusMeters), isFalse);
    });
  });
}
