/**
 * Violation & Integrity Logic Service (Pure Functions)
 */

export interface ViolationEvaluation {
  newCriticalCount: number;
  isTerminated: boolean;
}

/**
 * Evaluate a violation event against the current attempt's critical violations counter.
 * Rule: 'warn' signals NEVER increment critical count and NEVER trigger auto-termination.
 * Rule: 'critical' signals increment critical count, and if critical count >= maxCritical,
 *       the attempt is marked for termination ('terminated').
 */
export function evaluateViolation(
  currentCriticalCount: number,
  severity: 'warn' | 'critical',
  maxCritical: number = 3
): ViolationEvaluation {
  if (severity === 'warn') {
    return {
      newCriticalCount: currentCriticalCount,
      isTerminated: false,
    };
  }

  const newCriticalCount = currentCriticalCount + 1;
  const isTerminated = newCriticalCount >= maxCritical;

  return {
    newCriticalCount,
    isTerminated,
  };
}

/**
 * Calculate distance in meters between two geographical coordinates using the Haversine formula.
 */
export function calculateDistanceMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371000; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Check whether a user coordinate is within the geofence radius.
 */
export function isInsideGeofence(
  userLat: number,
  userLon: number,
  targetLat: number,
  targetLon: number,
  radiusMeters: number
): boolean {
  const distance = calculateDistanceMeters(userLat, userLon, targetLat, targetLon);
  return distance <= radiusMeters;
}
