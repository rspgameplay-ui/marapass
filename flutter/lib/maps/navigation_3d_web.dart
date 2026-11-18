import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../core/vector_support_web.dart' as vector;
import '../location/gps_diagnostics.dart';

bool get navigation3dSupported => vector.supportsVectorMaps();

class Navigation3DCanvas extends StatefulWidget {
  const Navigation3DCanvas({
    super.key,
    required this.frame,
    required this.onGesture,
    required this.onPlace,
    required this.onUnavailable,
  });

  final Map<String, dynamic> frame;
  final VoidCallback onGesture, onUnavailable;
  final ValueChanged<String> onPlace;

  @override
  State<Navigation3DCanvas> createState() => _Navigation3DCanvasState();
}

class _Navigation3DCanvasState extends State<Navigation3DCanvas> {
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;
  Timer? _timeout;
  bool _ready = false;
  Object? _lastRoute;

  @override
  void initState() {
    super.initState();
    _listener = ((web.Event event) {
      final message = event as web.MessageEvent;
      final origin = web.window.location.origin;
      if (message.origin != origin ||
          message.source != _frame?.contentWindow ||
          !mounted) {
        return;
      }
      final data = message.data.dartify();
      if (data is! String) return;
      Object? decoded;
      try {
        decoded = jsonDecode(data);
      } on FormatException {
        return;
      }
      if (decoded is! Map) return;
      switch (decoded['type']) {
        case 'marapass.3d.ready':
          gpsStage(GpsStage.mapReady);
          _timeout?.cancel();
          _ready = true;
          _lastRoute = null;
          _send();
        case 'marapass.3d.gesture':
          widget.onGesture();
        case 'marapass.3d.place':
          if (decoded['id'] case final String id) widget.onPlace(id);
        case 'marapass.3d.unavailable':
          gpsStage(GpsStage.mapFailed);
          _timeout?.cancel();
          widget.onUnavailable();
        case 'marapass.3d.diagnostic':
          final stage = switch (decoded['stage']) {
            'frame' => GpsStage.mapFrame,
            'camera' => GpsStage.mapCamera,
            'render' => GpsStage.mapRender,
            'contextLost' => GpsStage.contextLost,
            'error' => GpsStage.mapError,
            _ => null,
          };
          if (stage != null) gpsStage(stage);
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted) widget.onUnavailable();
    });
  }

  @override
  void didUpdateWidget(Navigation3DCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _send();
  }

  void _send() {
    if (!_ready) return;
    final data = {...widget.frame, 'type': 'marapass.3d.frame'};
    final route = data['route'];
    if (identical(route, _lastRoute)) data.remove('route');
    _lastRoute = route;
    _frame?.contentWindow?.postMessage(
      jsonEncode(data).toJS,
      web.window.location.origin.toJS,
    );
  }

  @override
  void dispose() {
    _timeout?.cancel();
    web.window.removeEventListener('message', _listener);
    _ready = false;
    _lastRoute = null;
    _frame?.src = 'about:blank';
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      gpsStage(GpsStage.mapLoading);
      _frame = element as web.HTMLIFrameElement
        ..title = 'Mapa de navegação em perspectiva'
        ..src = 'navigation-3d/index.html';
      _frame!.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0';
    },
  );
}
