import 'package:flutter/material.dart';

import 'google_place_stub.dart'
    if (dart.library.js_interop) 'google_place_web.dart'
    as platform;
import '../domain/tourism.dart';

Future<void> showGooglePlace(BuildContext context, TourismPlace place) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: platform.panel(place.id, place.name, place.googlePlaceId),
        ),
      ),
    );
