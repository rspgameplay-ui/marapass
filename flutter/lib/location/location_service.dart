import 'dart:async';

import 'gps_diagnostics.dart';

import 'package:geolocator/geolocator.dart';

import 'location_native.dart'
    if (dart.library.js_interop) 'location_web.dart'
    as platform;

enum LocationProblem {
  insecure,
  unsupported,
  policy,
  denied,
  disabled,
  timeout,
  unavailable,
  imprecise,
  cancelled,
}

class LocationFailure implements Exception {
  const LocationFailure(this.problem, this.message);
  final LocationProblem problem;
  final String message;
  @override
  String toString() => message;
}

abstract class NavigationLocationGateway {
  Stream<Position> navigationUpdates();
}

abstract class InitialLocationGateway {
  Stream<Position> initialUpdates();
}

abstract class LocationGateway {
  Future<void> authorize();
  Stream<Position> updates();
}

LocationFailure locationFailure(Object error) {
  if (error is LocationFailure) return error;
  if (error is PermissionDeniedException)
    return const LocationFailure(
      LocationProblem.denied,
      'Localização não autorizada. Permita o acesso para este site no Safari/Chrome e nas configurações do aparelho. Se abriu pelo ChatGPT, abra o link diretamente no navegador.',
    );
  if (error is LocationServiceDisabledException)
    return const LocationFailure(
      LocationProblem.disabled,
      'A localização do aparelho está desligada. Ative os Serviços de Localização e tente novamente.',
    );
  if (error is TimeoutException)
    return const LocationFailure(
      LocationProblem.timeout,
      'O aparelho não forneceu uma posição a tempo. Vá a um local aberto, confira a Localização Precisa e tente novamente.',
    );
  return const LocationFailure(
    LocationProblem.unavailable,
    'O aparelho não conseguiu fornecer a localização. Confira o sinal, os Serviços de Localização e abra o link no Safari/Chrome. Você pode continuar planejando a rota sem GPS.',
  );
}

bool usablePosition(Position p, {double? maximumAccuracy}) =>
    p.latitude.isFinite &&
    p.longitude.isFinite &&
    p.latitude.abs() <= 90 &&
    p.longitude.abs() <= 180 &&
    p.accuracy.isFinite &&
    p.accuracy >= 0 &&
    DateTime.now().difference(p.timestamp).inSeconds.abs() <= 15 &&
    (maximumAccuracy == null || p.accuracy <= maximumAccuracy);

class LocationService {
  LocationService({
    LocationGateway? gateway,
    this.acquisitionTimeout = const Duration(seconds: 30),
  }) : gateway = gateway ?? platform.createGateway();
  final LocationGateway gateway;
  final Duration acquisitionTimeout;
  void Function()? _cancel;
  void cancelPending() => _cancel?.call();

  Future<Position> acquire({bool navigation = false}) async {
    if (_cancel != null)
      throw const LocationFailure(
        LocationProblem.unavailable,
        'Aguarde a busca de posição em andamento.',
      );
    StreamSubscription<Position>? subscription;
    Timer? timer;
    Position? last;
    final result = Completer<Position>();
    result.future.ignore();
    _cancel = () {
      timer?.cancel();
      if (!result.isCompleted)
        result.completeError(
          const LocationFailure(
            LocationProblem.cancelled,
            'Busca de posição cancelada.',
          ),
        );
    };
    try {
      gpsStage(GpsStage.permissionCheck);
      await gateway.authorize().timeout(acquisitionTimeout);
      if (result.isCompleted) return await result.future;
      timer = Timer(acquisitionTimeout, () {
        if (result.isCompleted) return;
        final accuracy = last?.accuracy;
        result.completeError(
          last != null &&
                  usablePosition(last!) &&
                  accuracy != null &&
                  accuracy > 50 &&
                  navigation
              ? LocationFailure(
                  LocationProblem.imprecise,
                  'Precisão insuficiente para navegar (±${accuracy.round()} m). Ative Localização Precisa, aguarde em local aberto e tente novamente. O percurso continua disponível para planejamento.',
                )
              : locationFailure(TimeoutException('location')),
        );
      });
      gpsStage(GpsStage.initialRequest);
      final initial = gateway is InitialLocationGateway
          ? (gateway as InitialLocationGateway).initialUpdates()
          : gateway.updates();
      subscription = initial.listen(
        (p) {
          last = p;
          if (!result.isCompleted &&
              usablePosition(p, maximumAccuracy: navigation ? 50 : null))
            result.complete(p);
        },
        onError: (Object error) {
          if (!result.isCompleted) result.completeError(locationFailure(error));
        },
        onDone: () {
          if (!result.isCompleted)
            result.completeError(
              locationFailure(StateError('location stream ended')),
            );
        },
      );
      return await result.future;
    } catch (error) {
      throw locationFailure(error);
    } finally {
      _cancel = null;
      timer?.cancel();
      await subscription?.cancel();
    }
  }

  Stream<Position> updates() => gateway.updates();
  Stream<Position> navigationUpdates() => gateway is NavigationLocationGateway
      ? (gateway as NavigationLocationGateway).navigationUpdates()
      : gateway.updates();
}
