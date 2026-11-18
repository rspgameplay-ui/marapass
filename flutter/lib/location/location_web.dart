import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

@JS()
extension type _PermissionsPolicy(JSObject _) implements JSObject {
  external bool allowsFeature(String feature);
}

LocationGateway createGateway() => _WebGateway();

class _WebGateway implements LocationGateway, InitialLocationGateway {
  @override
  Future<void> authorize() async {
    if (!web.window.isSecureContext) {
      throw const LocationFailure(
        LocationProblem.insecure,
        'O GPS precisa de uma conexão segura HTTPS. Abra o endereço publicado diretamente no Safari ou Chrome.',
      );
    }
    if (!(web.window.navigator as JSObject)
        .hasProperty('geolocation'.toJS)
        .toDart) {
      throw const LocationFailure(
        LocationProblem.unsupported,
        'Este navegador não oferece localização. Abra o mapa no Safari ou Chrome atualizado.',
      );
    }
    bool? allowed;
    try {
      final document = web.document as JSObject;
      final policy =
          document.getProperty<JSObject?>('permissionsPolicy'.toJS) ??
          document.getProperty<JSObject?>('featurePolicy'.toJS);
      if (policy != null) {
        allowed = _PermissionsPolicy(policy).allowsFeature('geolocation');
      }
    } catch (_) {
      /* The policy introspection API is optional, including on Safari. */
    }
    if (allowed == false) {
      throw const LocationFailure(
        LocationProblem.policy,
        'A janela que abriu o mapa bloqueia a localização. Copie o link e abra diretamente no Safari ou Chrome; depois permita o acesso à sua posição.',
      );
    }
  }

  @override
  Stream<Position> initialUpdates() => _positions(single: true);

  @override
  Stream<Position> updates() => _positions(single: false);

  Stream<Position> _positions({required bool single}) {
    int? watch;
    Timer? retry;
    var stopped = false;
    late StreamController<Position> controller;
    void request() {
      if (stopped) return;
      try {
        final geolocation = web.window.navigator.geolocation;
        final success = (web.GeolocationPosition p) {
          if (stopped) return;
          final c = p.coords;
          controller.add(
            Position(
              latitude: c.latitude,
              longitude: c.longitude,
              timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
              accuracy: c.accuracy,
              altitude: c.altitude ?? 0,
              altitudeAccuracy: c.altitudeAccuracy ?? 0,
              heading: c.heading ?? -1,
              headingAccuracy: 0,
              speed: c.speed ?? 0,
              speedAccuracy: 0,
            ),
          );
          if (single && !stopped) {
            retry = Timer(const Duration(seconds: 1), request);
          }
        }.toJS;
        final failure = (web.GeolocationPositionError error) {
          if (stopped) return;
          // Safari may report a temporary failure before its first fix.
          // The acquisition service bounds the total time for these retries.
          if (single && error.code != 1) {
            retry = Timer(const Duration(seconds: 1), request);
            return;
          }
          controller.addError(switch (error.code) {
            1 => const PermissionDeniedException(
              'Permissão de localização negada',
            ),
            3 => TimeoutException('position timeout'),
            _ => const PositionUpdateException('Posição indisponível'),
          });
        }.toJS;
        final options = web.PositionOptions(
          enableHighAccuracy: true,
          maximumAge: 0,
          timeout: single ? 8000 : 30000,
        );
        if (single) {
          geolocation.getCurrentPosition(success, failure, options);
        } else {
          watch = geolocation.watchPosition(success, failure, options);
        }
      } catch (error) {
        if (!stopped) controller.addError(locationFailure(error));
      }
    }

    controller = StreamController<Position>(
      onListen: request,
      onCancel: () {
        stopped = true;
        retry?.cancel();
        if (watch != null) web.window.navigator.geolocation.clearWatch(watch!);
      },
    );
    return controller.stream;
  }
}
