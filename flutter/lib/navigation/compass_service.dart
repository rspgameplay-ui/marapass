import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Channel is implemented by MainActivity / AppDelegate; absent on web.
Stream<double> compassUpdates() =>
    kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)
    ? const Stream<double>.empty()
    : const EventChannel('marapass/compass')
          .receiveBroadcastStream()
          .where((v) => v is num && v.isFinite && v >= 0)
          .map((v) => (v as num).toDouble());
