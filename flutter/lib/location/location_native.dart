import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

LocationGateway createGateway() => _NativeGateway();

class _NativeGateway implements LocationGateway, NavigationLocationGateway {
  @override
  Future<void> authorize() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw const LocationServiceDisabledException();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw const PermissionDeniedException('Localização não autorizada');
  }

  @override
  Stream<Position> updates() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    ),
  );
  @override
  Stream<Position> navigationUpdates() {
    late StreamController<Position> out;
    StreamSubscription<Position>? input;
    bool closed = false;
    int generation = 0, profile = 1, candidate = 1, confirmations = 0;
    DateTime changed = DateTime.now();
    LocationSettings settings() {
      final accuracy = profile == 0
          ? LocationAccuracy.high
          : LocationAccuracy.bestForNavigation;
      if (defaultTargetPlatform == TargetPlatform.android)
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          intervalDuration: Duration(
            seconds: profile == 0
                ? 10
                : profile == 1
                ? 5
                : 2,
          ),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'MaraPass · navegação ativa',
            notificationText: 'Localização em uso durante o trajeto. Pare a navegação no aplicativo para encerrar.',
            enableWakeLock: true,
          ),
        );
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.otherNavigation,
      );
    }

    Future<void> subscribe() async {
      try {
        final ticket = ++generation;
        await input?.cancel();
        if (closed || ticket != generation) return;
        input = Geolocator.getPositionStream(locationSettings: settings())
            .listen(
              (p) {
                if (closed || ticket != generation) return;
                out.add(p);
                final next = !p.speed.isFinite || p.speed < 0
                    ? 1
                    : p.speed < .8
                    ? 0
                    : p.speed < 4
                    ? 1
                    : 2;
                if (candidate == next) {
                  confirmations++;
                } else {
                  candidate = next;
                  confirmations = 1;
                }
                if (next != profile &&
                    confirmations >= 3 &&
                    DateTime.now().difference(changed).inSeconds >= 30) {
                  profile = next;
                  changed = DateTime.now();
                  unawaited(subscribe());
                }
              },
              onError: (Object e) {
                if (!closed) out.addError(e);
              },
              onDone: () {
                if (!closed && ticket == generation) out.close();
              },
            );
      } catch (e, st) {
        if (!closed) out.addError(e, st);
      }
    }

    out = StreamController<Position>(
      onListen: () => unawaited(subscribe()),
      onCancel: () async {
        closed = true;
        ++generation;
        await input?.cancel();
      },
    );
    return out.stream;
  }
}
