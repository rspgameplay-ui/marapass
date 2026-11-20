import 'dart:convert';
import 'dart:io';

import 'package:marapass_mapa/domain/navigation.dart';
import 'package:marapass_mapa/domain/tourism.dart';

Map<String, dynamic> fixture() => jsonDecode(
  File('test/fixtures/route_sao_luis_barreirinhas.json').readAsStringSync(),
) as Map<String, dynamic>;
RoadRoute road() => RoadRoute(
  points: const [
    GeoPoint(-2.53, -44.30),
    GeoPoint(-2.53, -44.29),
    GeoPoint(-2.52, -44.29),
  ],
  steps: const [
    RoadStep(
      instruction: 'Siga',
      road: 'A',
      type: 'depart',
      modifier: 'straight',
      startMeters: 0,
      distance: 1112,
      duration: 100,
      point: GeoPoint(-2.53, -44.30),
    ),
    RoadStep(
      instruction: 'Vire à esquerda',
      road: 'B',
      type: 'turn',
      modifier: 'left',
      startMeters: 1110,
      distance: 1112,
      duration: 100,
      point: GeoPoint(-2.53, -44.29),
    ),
    RoadStep(
      instruction: 'Chegue ao destino',
      road: 'B',
      type: 'arrive',
      modifier: '',
      startMeters: 2220,
      distance: 0,
      duration: 0,
      point: GeoPoint(-2.52, -44.29),
    ),
  ],
  distance: 2224,
  duration: 200,
  summary: 'A, B',
  originSnap: 0,
  destinationSnap: 0,
);

TourismPlace poi(
  String id, {
  double lng = -44.295,
  double lat = -2.53,
  PlaceCategory category = PlaceCategory.culture,
  bool coupon = false,
  DateTime? checked,
}) => TourismPlace(
  id: id,
  name: id,
  city: 'São Luís',
  description: 'Informação pública',
  point: GeoPoint(lat, lng),
  category: category,
  isPartner: coupon,
  offersFresh: coupon,
  offerId: coupon ? 'offer-$id' : null,
  offerTitle: coupon ? 'Benefício de teste' : null,
  offerCheckedAt: checked ?? DateTime.now(),
);

