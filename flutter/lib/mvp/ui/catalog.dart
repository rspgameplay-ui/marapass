import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'month_calendar.dart';

/// Lista de uma categoria (Passeios, Gastronomia, Hospedagem, Cultura,
/// Natureza, Eventos, Artesanato, Fotografia, Transporte) com os filtros do
/// Design Master: faixa de preço, cidade, tipo e "perto de mim".
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.cat});
  final Cat cat;
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  int _faixa = 0; // 0 = todos
  String _cidade = 'Todas';
  String _tipo = 'Todos';
  DateTime? _evDay;
  bool _perto = false;
  bool _acessivel = false;
  bool _soDestaque = false;

  static const _tipos = <Cat, List<String>>{
    Cat.gastronomia: ['Todos', 'Regional', 'Frutos do mar', 'Bar', 'Com cupom'],
    Cat.hospedagem: ['Todos', 'Pousada', 'Hotel', 'Chalé'],
    Cat.artesanato: ['Todos', 'Babaçu', 'Biojoias', 'Buriti', 'Cerâmica'],
  };

  static const _subtitles = <Cat, String>{
    Cat.passeio: 'Passeios com guias locais.',
    Cat.gastronomia: 'Sabores do Maranhão por cidade, preço e proximidade.',
    Cat.hospedagem: 'Pousadas e hotéis para descansar bem.',
    Cat.cultura: 'Festas, comunidades e vivências autênticas.',
    Cat.natureza: 'Cachoeiras, mangues, mirantes e aves.',
    Cat.evento: 'Festas e eventos com benefícios MaraPass.',
    Cat.artesanato: 'Peças feitas à mão, direto com quem produz.',
    Cat.fotografia: 'Fotógrafos locais para registrar a viagem.',
    Cat.transporte: 'Transfers e travessias entre destinos.',
  };

  bool _matchTipo(Item i) {
    if (_tipo == 'Todos') return true;
    if (_tipo == 'Com cupom') return i.cupom != null;
    final t = _tipo.toLowerCase();
    return i.tags.any((x) => x.toLowerCase().contains(t)) ||
        i.titulo.toLowerCase().contains(t);
  }

  int get _extraCount =>
      (_faixa != 0 ? 1 : 0) +
      (_tipo != 'Todos' ? 1 : 0) +
      (_perto ? 1 : 0) +
      (_acessivel ? 1 : 0) +
      (_soDestaque ? 1 : 0);

  void _clearExtra() {
    _faixa = 0;
    _tipo = 'Todos';
    _perto = false;
    _acessivel = false;
    _soDestaque = false;
  }

  void _openFilters(BuildContext context, List<String>? tipos) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          void upd(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          Widget toggle(Key key, IconData icon, String label, bool value, ValueChanged<bool> on) =>
              SwitchListTile(
                key: key,
                secondary: Icon(icon),
                title: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                value: value,
                onChanged: (v) => upd(() => on(v)),
                contentPadding: EdgeInsets.zero,
              );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, MP.s4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                    child: Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: MP.s3),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: MP.pageH),
                    child: Text('Preço', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: MP.s1),
                  FilterChips<int>(
                    options: const [0, 1, 2, 3],
                    selected: _faixa,
                    label: (v) => v == 0 ? 'Todos' : r'$' * v,
                    onSelect: (v) => upd(() => _faixa = v),
                  ),
                  if (tipos != null) ...[
                    const SizedBox(height: MP.s2),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: MP.pageH),
                      child: Text('Tipo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: MP.s1),
                    FilterChips<String>(
                      options: tipos,
                      selected: _tipo,
                      label: (v) => v,
                      onSelect: (v) => upd(() => _tipo = v),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                    child: Column(
                      children: [
                        toggle(const Key('filter-near'), Icons.near_me_rounded, 'Mais perto primeiro', _perto, (v) => _perto = v),
                        toggle(const Key('filter-a11y'), Icons.accessible_rounded, 'Só lugares acessíveis', _acessivel, (v) => _acessivel = v),
                        if (widget.cat == Cat.evento)
                          toggle(const Key('filter-destaque'), Icons.star_rounded, 'Só em destaque', _soDestaque, (v) => _soDestaque = v),
                        const SizedBox(height: MP.s3),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => upd(_clearExtra),
                              child: const Text('Limpar'),
                            ),
                            const SizedBox(width: MP.s2),
                            Expanded(
                              child: FilledButton(
                                key: const Key('filter-apply'),
                                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                child: const Text('Ver resultados'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = Content.byCat(widget.cat);
    final cidades = ['Todas', ...Content.cidades(all)];
    var list = all
        .where(
          (i) =>
              (_faixa == 0 || i.faixa == _faixa) &&
              (_cidade == 'Todas' || i.cidade == _cidade) &&
              _matchTipo(i) &&
              (!_acessivel || i.acessivel) &&
              (!_soDestaque || i.destaque),
        )
        .toList();
    if (_perto) {
      list.sort(
        (a, b) => (a.distanciaKm ?? 9999).compareTo(b.distanciaKm ?? 9999),
      );
    }
    if (widget.cat == Cat.evento && _evDay != null) {
      final d = _evDay!;
      list = list.where((i) => i.data != null && i.data!.year == d.year && i.data!.month == d.month && i.data!.day == d.day).toList();
    }
    if (widget.cat == Cat.evento) {
      // Destaques primeiro; dentro de cada grupo, em ordem de data.
      list.sort((a, b) {
        if (a.destaque != b.destaque) return a.destaque ? -1 : 1;
        return a.data!.compareTo(b.data!);
      });
    }
    final tipos = _tipos[widget.cat];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s10),
          children: [
            MpHeader(widget.cat.label, subtitle: _subtitles[widget.cat]),
            // Só a cidade fica à vista; o resto vai para "Filtros", para a
            // lista aparecer logo (antes eram 4 fileiras de filtros).
            if (cidades.length > 2) ...[
              FilterChips<String>(
                options: cidades,
                selected: _cidade,
                label: (v) => v,
                onSelect: (v) => setState(() => _cidade = v),
              ),
              const SizedBox(height: MP.s2),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('filter-open'),
                    onPressed: () => _openFilters(context, tipos),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(_extraCount == 0 ? 'Filtros' : 'Filtros ($_extraCount)'),
                  ),
                  if (_extraCount > 0) ...[
                    const SizedBox(width: MP.s2),
                    TextButton(
                      key: const Key('filter-clear'),
                      onPressed: () => setState(_clearExtra),
                      child: const Text('Limpar'),
                    ),
                  ],
                ],
              ),
            ),
            if (_perto)
              const Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, 0),
                child: MpNotice(
                  'Distâncias calculadas a partir de Barreirinhas nesta demonstração. A sua localização não é enviada.',
                ),
              ),
            if (widget.cat == Cat.evento)
              Padding(
                key: const Key('events-calendar'),
                padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MpMonthCalendar(
                      start: _evDay,
                      allowToday: true,
                      hasEvent: (d) => all.any((e) => e.data != null && e.data!.year == d.year && e.data!.month == d.month && e.data!.day == d.day),
                      onChanged: (d, _) => setState(() => _evDay = d == null || (_evDay != null && d == _evDay) ? null : d),
                    ),
                    if (_evDay != null) ...[
                      DayAgenda(day: _evDay!),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(key: const Key('events-all'), onPressed: () => setState(() => _evDay = null), child: const Text('Ver todos os eventos')),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: MP.s4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Text(
                '${list.length} ${list.length == 1 ? 'resultado' : 'resultados'}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: MP.s2),
            if (list.isEmpty)
              MpEmpty(
                icon: Icons.search_off_rounded,
                title: 'Nada com esses filtros',
                message: 'Tente outra cidade ou tire alguns filtros.',
                actionLabel: 'Limpar filtros',
                onAction: () => setState(() {
                  _cidade = 'Todas';
                  _clearExtra();
                }),
              ),
            for (final i in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: widget.cat == Cat.evento
                    ? _EventRow(item: i)
                    : ItemRow(item: i, showDistance: _perto),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({required this.item});
  final Item item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = item.data!;
    final saved = ref.watch(appStoreProvider.select((s) => s.isSaved(item.id)));
    const mo = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    return MpCard(
      onTap: () => openItem(context, item),
      child: Row(
        children: [
          Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: MP.s2),
            decoration: BoxDecoration(
              color: MP.tintRed,
              borderRadius: BorderRadius.circular(MP.rMedium),
            ),
            child: Column(
              children: [
                Text(
                  '${d.day}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: MP.error,
                  ),
                ),
                Text(
                  mo[d.month - 1],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MP.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${fmtTime(d)} · ${item.cidade}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.destaque || item.cupom != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: MP.s2,
                    children: [
                      if (item.destaque)
                        const MpBadge('Em destaque', fg: MP.error, bg: MP.tintRed),
                      if (item.cupom != null)
                        const MpBadge('Com benefício', fg: MP.warning, bg: MP.goldBg),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: saved ? MP.green : MP.textMuted,
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// Página do destino/polo: foto, melhor época, cidades e o que fazer.
class PoloScreen extends StatelessWidget {
  const PoloScreen({super.key, required this.polo});
  final Polo polo;

  @override
  Widget build(BuildContext context) {
    final items = Content.byPolo(polo.id);
    final byCat = <Cat, List<Item>>{};
    for (final i in items) {
      byCat.putIfAbsent(i.cat, () => []).add(i);
    }
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          MpPhoto(
            photo: polo.hero ?? polo.foto,
            height: 300,
            radius: 0,
            darken: true,
            seed: polo.id.hashCode,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(MP.pageH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const MpBackPill(onDark: true),
                        const Spacer(),
                        FavButton(polo.id),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      polo.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      polo.resumo,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  polo.descricao,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: MP.s5),
                Text(
                  'Melhor época: ${polo.melhorTexto}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MP.s3),
                MonthStrip(best: polo.melhor),
                const SizedBox(height: MP.s5),
                Text('Cidades', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MP.s2),
                Wrap(
                  spacing: MP.s2,
                  runSpacing: MP.s2,
                  children: [
                    for (final c in polo.cidades)
                      MpBadge(c, fg: MP.navy, icon: Icons.place_rounded),
                  ],
                ),
                const SizedBox(height: MP.s4),
                OutlinedButton.icon(
                  onPressed: () => openMaps(context, '${polo.nome} Maranhão'),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Como chegar'),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: MP.pageH),
              child: MpNotice(
                'Os parceiros deste polo estão sendo cadastrados. Em breve aparecem passeios, restaurantes e hospedagens aqui.',
              ),
            ),
          for (final e in byCat.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MP.pageH,
                MP.s4,
                MP.pageH,
                MP.s3,
              ),
              child: MpSectionTitle(e.key.label),
            ),
            for (final i in e.value)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: ItemRow(item: i),
              ),
          ],
          const SizedBox(height: MP.s8),
        ],
      ),
    );
  }
}

/// Os 11 polos turísticos.
class PolosScreen extends StatelessWidget {
  const PolosScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const MpHeader(
            'Os 11 polos do Maranhão',
            subtitle: 'Escolha uma região para ver o que fazer.',
          ),
          for (final p in Content.polos)
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
              child: PhotoCard(
                title: p.nome,
                subtitle: p.resumo,
                photo: p.foto,
                favId: p.id,
                height: 150,
                seed: p.id.hashCode,
                onTap: () => openPolo(context, p),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Experiências autênticas: vivências conduzidas por comunidades.
class AuthenticScreen extends StatelessWidget {
  const AuthenticScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list = Content.items.where((i) => i.autentica).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader(
              'Experiências autênticas',
              subtitle: 'Vivências conduzidas pelas próprias comunidades. Não são apenas destinos.',
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s4),
              child: MpNotice(
                'Visitas a comunidades tradicionais acontecem só com agendamento e autorização. Respeite as regras de cada lugar.',
                icon: Icons.handshake_rounded,
                fg: MP.green,
                bg: MP.greenBg,
              ),
            ),
            for (final i in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: ItemRow(item: i),
              ),
          ],
        ),
      ),
    );
  }
}
