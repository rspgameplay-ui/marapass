import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../domain/tourism.dart';
import 'location_service.dart';

const courseValidity = Duration(seconds: 20);

/// Falls back to movement between accurate fixes when the browser omits course.
double? travelCourse(Position fix, Position? previous) {
  if (!usablePosition(fix, maximumAccuracy: 50)) return null;
  if (fix.speed.isFinite &&
      fix.speed >= 1.5 &&
      fix.heading.isFinite &&
      fix.heading >= 0 &&
      fix.heading < 360) {
    return fix.heading;
  }
  if (previous == null || !usablePosition(previous, maximumAccuracy: 50)) {
    return null;
  }
  final elapsed = fix.timestamp.difference(previous.timestamp);
  if (elapsed <= Duration.zero || elapsed > courseValidity) return null;
  final origin = GeoPoint(previous.latitude, previous.longitude);
  final target = GeoPoint(fix.latitude, fix.longitude);
  final meters = origin.distanceKm(target) * 1000;
  if (meters < math.max(18, previous.accuracy + fix.accuracy) ||
      meters < elapsed.inMilliseconds * .0015) {
    return null;
  }
  return _bearing(origin, target);
}

/// An estimate from GPS course for discovery before a road route is planned.
bool isAhead(GeoPoint origin, GeoPoint target, double heading) {
  final bearing = _bearing(origin, target);
  if (bearing == null) return false;
  final delta = ((bearing - heading + 540) % 360) - 180;
  return delta.abs() < 90;
}

double? _bearing(GeoPoint origin, GeoPoint target) {
  final lat1 = origin.lat * math.pi / 180, lat2 = target.lat * math.pi / 180;
  final dl = (target.lng - origin.lng) * math.pi / 180;
  final y = math.sin(dl) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dl);
  if (x.abs() < 1e-12 && y.abs() < 1e-12) return null;
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
