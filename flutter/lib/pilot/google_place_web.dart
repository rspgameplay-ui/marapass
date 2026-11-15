import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget panel(String recordId, String name, String? placeId) =>
    HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as web.HTMLIFrameElement;
        frame.src = Uri(
          path: '/google_places/',
          queryParameters: {
            'record': recordId,
            'q': name,
            if (placeId != null) 'place': placeId,
          },
        ).toString();
        frame.setAttribute(
          'sandbox',
          'allow-scripts allow-popups allow-popups-to-escape-sandbox',
        );
        frame.title = 'Informações complementares de $name no Google Maps';
        frame.style.width = '100%';
        frame.style.height = '100%';
        frame.style.border = '0';
        frame.referrerPolicy = 'strict-origin-when-cross-origin';
      },
    );
