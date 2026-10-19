import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class GeofenceStatus {
  final bool isInside;
  final double distanceMeters;
  final double radiusMeters;
  final Position? currentPosition;
  final bool isMocked;

  GeofenceStatus({
    required this.isInside,
    required this.distanceMeters,
    required this.radiusMeters,
    this.currentPosition,
    this.isMocked = false,
  });
}

class GeofenceService {
  // Pure logic distance calculation (Haversine formula)
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // in meters
    final double dLat = (lat2 - lat1) * (pi / 180.0);
    final double dLon = (lon2 - lon1) * (pi / 180.0);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Pure logic check if inside geofence
  static bool isInside(
    double userLat,
    double userLon,
    double venueLat,
    double venueLon,
    double radiusMeters,
  ) {
    final dist = calculateDistanceMeters(userLat, userLon, venueLat, venueLon);
    return dist <= radiusMeters;
  }

  /// Check permission and service status
  Future<bool> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current user location with mock detection
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Evaluate user's current position against exam venue
  Future<GeofenceStatus?> checkGeofence({
    required double venueLat,
    required double venueLng,
    required double radiusMeters,
  }) async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final distance = calculateDistanceMeters(
      position.latitude,
      position.longitude,
      venueLat,
      venueLng,
    );

    return GeofenceStatus(
      isInside: distance <= radiusMeters,
      distanceMeters: distance,
      radiusMeters: radiusMeters,
      currentPosition: position,
      isMocked: position.isMocked,
    );
  }

  /// Open device app/location settings
  Future<void> openSettings() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
