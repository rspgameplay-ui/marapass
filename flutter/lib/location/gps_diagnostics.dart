import 'gps_diagnostics_stub.dart'
    if (dart.library.js_interop) 'gps_diagnostics_web.dart'
    as platform;

// Fixed vocabulary only: never pass a position, route, identifier or exception.
enum GpsStage {
  start,
  permissionCheck,
  initialRequest,
  initialFix,
  routeStart,
  routeReady,
  navigationReady,
  watchStart,
  watchFix,
  cameraReady,
  signalLost,
  denied,
  timeout,
  unavailable,
  cancelled,
  stopped,
  mapLoading,
  mapReady,
  mapFrame,
  mapCamera,
  mapRender,
  mapFailed,
  mapError,
  contextLost,
}

void gpsStage(GpsStage stage) =>
    platform.record(stage.name, GpsStage.values.map((e) => e.name).toSet());
