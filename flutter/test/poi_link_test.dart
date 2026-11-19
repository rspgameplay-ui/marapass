import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/mvp/data/content.dart';
import 'package:marapass_mapa/mvp/ui/map_tab.dart';

Item _item(String id, String titulo, String cidade) => Item(
  id: id,
  cat: Cat.passeio,
  titulo: titulo,
  resumo: 'r',
  descricao: 'd',
  polo: 'p',
  cidade: cidade,
  lat: -2.75,
  lng: -42.82,
);

TourismPlace _place(
  String id,
  String name,
  String city, {
  PlaceCategory category = PlaceCategory.tours,
}) => TourismPlace(
  id: id,
  name: name,
  city: city,
  point: const GeoPoint(-2.75, -42.82),
  category: category,
  description: '',
);

const _cities = {'Barreirinhas', 'Atins'};

void main() {
  test('item e lugar com mesmo nome e cidade viram um só ponto', () {
    final pois = linkPois(
      items: [_item('i1', 'Lençóis Maranhenses', 'Barreirinhas')],
      places: [_place('osm:1', 'Lencois Maranhenses', 'barreirinhas')],
      islandIds: const {},
      cities: _cities,
    );
    expect(pois, hasLength(1));
    expect(pois.single.item?.id, 'i1');
    expect(pois.single.place?.id, 'osm:1');
    expect(pois.single.featured, isTrue);
  });

  test('nomes diferentes ou cidades diferentes continuam separados', () {
    final pois = linkPois(
      items: [_item('i1', 'Passeio A', 'Barreirinhas')],
      places: [
        _place('p1', 'Passeio B', 'Barreirinhas'),
        _place('p2', 'Passeio A', 'Atins'),
      ],
      islandIds: const {},
      cities: _cities,
    );
    expect(pois, hasLength(3));
    expect(pois.first.place, isNull);
    expect(pois.map((p) => p.id), containsAll(['i1', 'p1', 'p2']));
  });

  test('item fora das cidades do mapa e lugar residencial são ignorados', () {
    final pois = linkPois(
      items: [_item('i1', 'Passeio', 'Cidade Desconhecida')],
      places: [
        _place('r1', 'Casa', 'Atins', category: PlaceCategory.residential),
      ],
      islandIds: const {},
      cities: _cities,
    );
    expect(pois, isEmpty);
  });

  test('lugar de ilha sem item ganha o tipo ilhas', () {
    final pois = linkPois(
      items: const [],
      places: [_place('ilha1', 'Ilha X', 'Atins')],
      islandIds: const {'ilha1'},
      cities: _cities,
    );
    expect(pois.single.kind, PoiKind.ilhas);
  });
}
