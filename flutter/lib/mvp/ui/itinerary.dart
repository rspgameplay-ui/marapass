import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tourism.dart';
import '../data/content.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'map_tab.dart' show itemPoint;
import 'route_builder.dart' show MyRoutesScreen;
import 'shell.dart' show Tabs;

/// Capa por categoria quando o item não tem foto própria.
const _catCover = <Cat, String>{
  Cat.artesanato: 'ceramica',
  Cat.cultura: 'p2',
  Cat.gastronomia: 'rest',
  Cat.hospedagem: 'p4',
  Cat.passeio: 'sunset',
  Cat.natureza: 'lagoa_boat',
  Cat.evento: 'p2',
  Cat.fotografia: 'sunset',
  Cat.transporte: 'p3',
};

/// Uma parada do roteiro: horário, por que ela está ali e um plano B.
class DayStop {
  const DayStop({
    required this.time,
    required this.slot,
    required this.itemId,
    required this.why,
    this.backupId,
    this.backupNote,
    this.anchor = false,
  });
  final String time, slot, itemId, why;
  final String? backupId, backupNote;
  final bool anchor;
  Item get item => Content.item(itemId)!;
  Item? get backup => backupId == null ? null : Content.item(backupId!);
}

/// Roteiro de um dia numa cidade: uma experiência âncora, ritmo com pausa
/// nas horas mais quentes e plano B para clima, cansaço ou fechamento.
class DayPlan {
  const DayPlan({required this.city, required this.title, required this.lens, required this.stops, required this.rest, required this.tip});
  final String city, title, lens, rest, tip;
  final List<DayStop> stops;
}

const dayPlans = <DayPlan>[
  DayPlan(
    city: 'Barreirinhas',
    title: 'Lençóis em um dia',
    lens: 'Natureza e sabores locais, sem correria',
    rest: 'Pausa de 1h30 depois do almoço: o sol do meio-dia nas dunas é forte.',
    tip: 'Leve água, protetor solar e uma sacola para o celular: as lagoas molham. Na volta, a Casa do Mangue serve jantar até as 23h.',
    stops: [
      DayStop(
        time: '9h00',
        slot: 'Manhã',
        itemId: 'buriti-bolsa',
        why: 'Começo leve: conhecer o trabalho com a fibra do buriti, perto do centro.',
        backupId: 'rio',
        backupNote: 'Quer mais aventura? O barco pelo Rio Preguiças sai cedo (5 h).',
      ),
      DayStop(
        time: '12h00',
        slot: 'Almoço',
        itemId: 'mangue',
        why: 'Peixe regional no centro, perto da saída dos passeios da tarde.',
        backupNote: 'Indo para Atins? A Casa de Juja serve galinha caipira de sexta a domingo.',
      ),
      DayStop(
        time: '14h30',
        slot: 'Tarde',
        itemId: 'lagoas',
        why: 'A experiência principal do dia: as lagoas ficam mais azuis com a luz da tarde e o passeio termina no pôr do sol.',
        backupId: 'marcelino',
        backupNote: 'Se chover forte, troque pela vivência em Marcelino.',
        anchor: true,
      ),
    ],
  ),
  DayPlan(
    city: 'São Luís',
    title: 'São Luís histórica e cultural',
    lens: 'História, música e culinária maranhense',
    rest: 'Pausa no hotel das 14h às 15h30, quando o calor é maior no Centro.',
    tip: 'Use sapato confortável: as ruas do Centro Histórico são de pedra e têm ladeiras.',
    stops: [
      DayStop(
        time: '8h30',
        slot: 'Manhã',
        itemId: 'centro',
        why: 'Casarões e azulejos com luz suave e menos calor, antes das 11h.',
        backupId: 'quilombo',
        backupNote: 'Se chover, os museus e o quilombo urbano são cobertos.',
        anchor: true,
      ),
      DayStop(
        time: '12h30',
        slot: 'Almoço',
        itemId: 'cozinha',
        why: 'Arroz de cuxá e peixada a poucos passos do Centro; abre das 11h às 16h.',
      ),
      DayStop(
        time: '15h30',
        slot: 'Tarde',
        itemId: 'quilombo',
        why: 'Tambor de crioula e a história do povo negro de São Luís, contada por quem vive lá.',
      ),
      DayStop(
        time: '17h30',
        slot: 'Pôr do sol',
        itemId: 'conchas',
        why: 'Fim de tarde de frente para o mar; abre às 16h.',
      ),
      DayStop(
        time: '20h00',
        slot: 'Noite',
        itemId: 'boi',
        why: 'Fechar o dia com música e dança do Bumba meu boi.',
      ),
    ],
  ),
  DayPlan(
    city: 'Atins',
    title: 'Atins entre o vento e as dunas',
    lens: 'Aventura com calma, na vila mais tranquila dos Lençóis',
    rest: 'Pausa de 1h depois do almoço: a vila é de areia, ande com calma no calor.',
    tip: 'Atins não tem estrada asfaltada: chegue de barco pelo Preguiças ou de 4x4 e leve dinheiro, porque nem todo lugar aceita cartão.',
    stops: [
      DayStop(
        time: '9h00',
        slot: 'Manhã',
        itemId: 'kite',
        why: 'Aula com o vento ainda moderado da manhã, ideal para quem está começando.',
        backupNote: 'Sem vento? Faça uma caminhada até a praia de Atins.',
      ),
      DayStop(
        time: '12h30',
        slot: 'Almoço',
        itemId: 'juja',
        why: 'A galinha caipira mais famosa de Atins, servida em casa de família.',
        backupNote: 'A Casa de Juja abre de sexta a domingo; nos outros dias, almoce num restaurante da vila.',
      ),
      DayStop(
        time: '14h30',
        slot: 'Tarde',
        itemId: '4x4',
        why: 'A experiência principal: dunas, lagoas e o Canto do Atins até o pôr do sol.',
        anchor: true,
      ),
    ],
  ),
  DayPlan(
    city: 'Carolina',
    title: 'Chapada das Mesas',
    lens: 'Cachoeiras, mirantes e artesanato do cerrado',
    rest: 'Pausa no meio da tarde: o sol do cerrado é forte entre 13h e 15h.',
    tip: 'As cachoeiras ficam longe da cidade: saia cedo, abasteça o carro e leve água e lanche.',
    stops: [
      DayStop(
        time: '7h30',
        slot: 'Manhã',
        itemId: 'cach',
        why: 'A experiência principal: banho nas cachoeiras antes do calor e da chegada dos grupos.',
        anchor: true,
      ),
      DayStop(
        time: '16h30',
        slot: 'Pôr do sol',
        itemId: 'mirante',
        why: 'O Portal da Chapada ganha tons de laranja no fim da tarde.',
      ),
      DayStop(
        time: '19h00',
        slot: 'Noite',
        itemId: 'biojoia',
        why: 'Fechar o dia conhecendo as biojoias de sementes e capim dourado da região.',
      ),
    ],
  ),
];

/// Pedido para o mapa traçar um roteiro (lido pela aba Mapa).
final itineraryRequestProvider = StateProvider<DayPlan?>((ref) => null);

String _drive(GeoPoint a, GeoPoint b) {
  final km = a.distanceKm(b) * 1.35;
  final min = (km / 28 * 60).round().clamp(3, 600);
  return '≈ $min min de carro · ${km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1).replaceAll('.', ',')} km'}';
}

/// Atalho da aba Início.
class ItineraryShortcut extends StatelessWidget {
  const ItineraryShortcut({super.key});
  @override
  Widget build(BuildContext context) => MpCard(
    key: const Key('home-itinerary'),
    onTap: () => push<void>(context, const MyRoutesScreen()),
    padding: const EdgeInsets.all(MP.s4),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: MP.tintGreen, borderRadius: BorderRadius.circular(MP.rMedium)),
          child: const Icon(Icons.route_rounded, color: MP.green, size: 30),
        ),
        const SizedBox(width: MP.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Defina sua Rota', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              const Text('Monte seu passeio do seu jeito', style: TextStyle(fontSize: 15, color: MP.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: MP.textSecondary),
      ],
    ),
  );
}

class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({super.key});
  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  int _i = 0;

  void _trace() {
    ref.read(itineraryRequestProvider.notifier).state = dayPlans[_i];
    ref.read(shellTabProvider.notifier).go(Tabs.mapa);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final plan = dayPlans[_i];
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s3),
          decoration: const BoxDecoration(color: MP.page, border: Border(top: BorderSide(color: MP.border))),
          child: MpPrimaryButton(
            key: const Key('itinerary-trace'),
            label: 'Traçar roteiro no mapa',
            icon: Icons.map_rounded,
            onPressed: _trace,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader('Roteiro do dia', subtitle: 'Um dia bem aproveitado, com pausa e plano B.'),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                itemCount: dayPlans.length,
                separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
                itemBuilder: (_, k) => ChoiceChip(
                  key: Key('itinerary-city-$k'),
                  selected: k == _i,
                  showCheckmark: false,
                  label: Text(dayPlans[k].city),
                  labelStyle: TextStyle(
                    fontFamily: mpFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: k == _i ? Colors.white : MP.ink,
                  ),
                  selectedColor: MP.navy,
                  onSelected: (_) => setState(() => _i = k),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s4, MP.pageH, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: MP.s1),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 18, color: MP.error),
                      const SizedBox(width: MP.s1),
                      Expanded(child: Text(plan.lens, style: const TextStyle(fontSize: 15, color: MP.textSecondary))),
                    ],
                  ),
                  const SizedBox(height: MP.s4),
                  for (var k = 0; k < plan.stops.length; k++) ...[
                    _StopTile(stop: plan.stops[k], index: k + 1),
                    if (k == 1) _RestTile(text: plan.rest),
                    if (k < plan.stops.length - 1)
                      _TransitRow(text: _drive(itemPoint(plan.stops[k].item), itemPoint(plan.stops[k + 1].item))),
                  ],
                  const SizedBox(height: MP.s4),
                  MpNotice(plan.tip, icon: Icons.backpack_rounded, fg: MP.info, bg: MP.infoBg),
                  const SizedBox(height: MP.s3),
                  const MpNotice.demo('Horários sugeridos. Confirme o funcionamento com o parceiro antes de sair.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.index});
  final DayStop stop;
  final int index;
  @override
  Widget build(BuildContext context) {
    final i = stop.item;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(stop.time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: MP.ink)),
                const SizedBox(height: MP.s1),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: stop.anchor ? MP.yellow : MP.navy,
                  child: Text('$index', style: TextStyle(color: stop.anchor ? MP.ink : Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                Expanded(child: Container(width: 2, color: MP.border)),
              ],
            ),
          ),
          const SizedBox(width: MP.s2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: MP.s2),
              child: MpCard(
                onTap: () => openItem(context, i),
                padding: const EdgeInsets.all(MP.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 64, height: 64, child: MpPhoto(photo: i.foto ?? _catCover[i.cat], height: 64, radius: MP.rSmall, icon: i.cat.icon)),
                        const SizedBox(width: MP.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 4,
                                children: [
                                  Text(stop.slot.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .8, color: MP.textSecondary)),
                                  if (stop.anchor) ...[
                                    const SizedBox(width: MP.s2),
                                    const MpBadge('Destaque do dia', fg: MP.goldText, bg: MP.goldBg),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(i.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                              if (i.duracao != null) Text(i.duracao!, style: const TextStyle(fontSize: 14, color: MP.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MP.s2),
                    Text(stop.why, style: const TextStyle(fontSize: 15, color: MP.text, height: 1.4)),
                    if (stop.backupNote != null) ...[
                      const SizedBox(height: MP.s2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.swap_horiz_rounded, size: 18, color: MP.warning),
                          const SizedBox(width: MP.s1),
                          Expanded(
                            child: Text('Plano B: ${stop.backupNote}', style: const TextStyle(fontSize: 14, color: MP.warning, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransitRow extends StatelessWidget {
  const _TransitRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20, bottom: MP.s2),
    child: Row(
      children: [
        const Icon(Icons.directions_car_rounded, size: 18, color: MP.textSecondary),
        const SizedBox(width: MP.s2),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: MP.textSecondary, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

class _RestTile extends StatelessWidget {
  const _RestTile({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 64, bottom: MP.s2),
    child: Container(
      padding: const EdgeInsets.all(MP.s3),
      decoration: BoxDecoration(color: MP.soft, borderRadius: BorderRadius.circular(MP.rMedium)),
      child: Row(
        children: [
          const Icon(Icons.hotel_rounded, size: 20, color: MP.navy),
          const SizedBox(width: MP.s2),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: MP.text))),
        ],
      ),
    ),
  );
}
