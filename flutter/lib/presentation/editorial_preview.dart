import 'package:flutter/material.dart';

import '../application/map_state.dart';
import '../core/preview_bridge.dart';
import '../data/catalog_workspace.dart';
import '../domain/tourism.dart';
import '../maps/road_map.dart';

class EditorialPreview extends StatefulWidget {
  const EditorialPreview({super.key});
  @override
  State<EditorialPreview> createState() => _EditorialPreviewState();
}

class _EditorialPreviewState extends State<EditorialPreview> {
  late final VoidCallback stop;
  TourismPlace? place;
  int serial = 0;
  @override
  void initState() {
    super.initState();
    stop = listenForEditorialPreview((json) {
      final incoming = TourismPlace.fromJson(json);
      validatePlace(incoming);
      if (mounted) {
        setState(() {
          place = incoming;
          serial++;
        });
      }
    });
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = place;
    if (p == null) {
      return const Scaffold(
        body: Center(child: Text('Aguardando a prévia salva no painel.')),
      );
    }
    return Scaffold(
      body: RoadMap(
        state: MapState(
          places: [p],
          zoom: 15,
          request: CameraRequest(p.point, 15, serial),
        ),
        onFeature: (feature) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name} • ${p.city}')),
        ),
        creditTop: 8,
      ),
    );
  }
}
