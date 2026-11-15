import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'traveler_marker.dart';

/// Bounded cache: no bitmap creation on a GPS tick. Draw variable accuracy with
/// a Google Circle in metres, rather than regenerating the bitmap.
class GoogleTravelerIcons {
  static final Map<String, Future<BitmapDescriptor>> _cache = {};
  static Future<BitmapDescriptor> forMode(
    TravelMode mode, {
    bool imprecise = false,
  }) => _cache.putIfAbsent('$mode:$imprecise', () async {
    final r = ui.PictureRecorder();
    final c = Canvas(r);
    c.scale(3);
    TravelerPainter(
      mode: mode,
      heading: 0,
      accuracy: 12,
      imprecise: imprecise,
    ).paint(c, const Size(64, 64));
    final picture = r.endRecording();
    final image = await picture.toImage(192, 192);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 64,
      height: 64,
    );
    image.dispose();
    picture.dispose();
    return descriptor;
  });
  static Marker marker({
    required BitmapDescriptor icon,
    required LatLng position,
    required double heading,
    bool imprecise = false,
    String id = 'traveler',
    bool headingKnown = true,
  }) => Marker(
    markerId: MarkerId(id),
    position: position,
    icon: icon,
    flat: true,
    anchor: const Offset(.5, .5),
    rotation: heading,
    alpha: imprecise ? .55 : 1,
    infoWindow: InfoWindow(
      title: headingKnown
          ? 'Você está aqui, seguindo para ${directionLabel(heading)}'
          : 'Você está aqui, rumo indisponível',
    ),
  );
}
