import 'dart:async';

import 'package:flutter/material.dart';
import '../i18n.dart';
import '../theme/tokens.dart';


/// Uma época do ano no Maranhão: o que está acontecendo e o que vale a pena.
class Season {
  const Season(this.title, this.subtitle, this.icon, this.colors, this.highlights);
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final List<String> highlights;
}

/// Calendário turístico do Maranhão, mês a mês.
const List<Season> kSeasons = [
  Season('Verão e férias', 'Sol forte e praias cheias', Icons.wb_sunny_rounded,
      [MP.seasonOrange, MP.seasonRed], [
    'Praias de São Luís e Raposa',
    'Passeios de barco no Delta do Parnaíba',
    'Lençóis com dunas firmes e pouca água',
  ]),
  Season('Carnaval e chuvas', 'Folia e início da estação chuvosa', Icons.celebration_rounded,
      [MP.seasonPurple, MP.seasonRed], [
    'Carnaval de rua em São Luís e blocos tradicionais',
    'Tambor de crioula e fofão no Centro Histórico',
    'Chuvas começam a encher as lagoas',
  ]),
  Season('Tempo de chuvas', 'Natureza verde e cachoeiras cheias', Icons.water_drop_rounded,
      [MP.seasonBlue, MP.seasonTeal], [
    'Cachoeiras da Chapada das Mesas no auge',
    'Rios e matas exuberantes',
    'Gastronomia: juçara e peixadas',
  ]),
  Season('Lagoas enchendo', 'Fim das chuvas nos Lençóis', Icons.waves_rounded,
      [MP.seasonBlue, MP.seasonGreen], [
    'Lagoas dos Lençóis começando a encher',
    'Chapada das Mesas com cachoeiras fortes',
    'Semana Santa no interior',
  ]),
  Season('Esquenta junino', 'Lagoas cheias e ensaios do boi', Icons.music_note_rounded,
      [MP.seasonGreen, MP.seasonYellow], [
    'Lagoas dos Lençóis cheias e cristalinas',
    'Ensaios de bumba meu boi pelos bairros',
    'Clima mais ameno para trilhas',
  ]),
  Season('São João do Maranhão', 'A maior festa do estado', Icons.local_fire_department_rounded,
      [MP.seasonOrange, MP.seasonYellow], [
    'Arraiais e Bumba meu boi em São Luís',
    'Sotaques: matraca, zabumba, orquestra',
    'Lençóis no melhor momento',
  ]),
  Season('Alta temporada', 'Férias e lagoas no auge', Icons.beach_access_rounded,
      [MP.seasonBlue, MP.seasonYellow], [
    'Melhor época para os Lençóis Maranhenses',
    'Festas do boi seguem até o fim do mês',
    'Atins e Caburé com ventos para kitesurf',
  ]),
  Season('Lagoas e ventos', 'Céu limpo e lagoas cheias', Icons.air_rounded,
      [MP.seasonTeal, MP.seasonBlue], [
    'Lagoas ainda cheias nos Lençóis',
    'Temporada de kitesurf em Atins',
    'Festa de São Benedito (Alcântara e interior)',
  ]),
  Season('Céu aberto', 'Seco, ventoso e com pôr do sol incrível', Icons.wb_twilight_rounded,
      [MP.seasonOrange, MP.seasonBlue], [
    'Lagoas começam a baixar: ainda vale ir',
    'Kitesurf no auge em Atins',
    'Alcântara e Centro Histórico sem chuva',
  ]),
  Season('Primavera seca', 'Calor e aventura', Icons.hiking_rounded,
      [MP.seasonSand, MP.seasonOrange], [
    'Trilhas e mirantes da Chapada das Mesas',
    'Delta do Parnaíba e revoada dos guarás',
    'Círio e festas religiosas',
  ]),
  Season('Sol e cultura', 'Praias e eventos culturais', Icons.museum_rounded,
      [MP.seasonRed, MP.seasonOrange], [
    'Praias de São José de Ribamar',
    'Feiras e museus do Centro Histórico',
    'Guarás no fim de tarde na Ilha',
  ]),
  Season('Fim de ano', 'Réveillon e férias', Icons.auto_awesome_rounded,
      [MP.seasonNight, MP.seasonYellow], [
    'Réveillon na Litorânea e em Barreirinhas',
    'Natal e luzes no Centro Histórico',
    'Início das férias de verão',
  ]),
];

const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const _weekdays = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

// Uma foto por mês, das que já estão no app.
const _photos = [
  'sunset', 'cultura', 'chapada', 'w_chapada', 'lagoas', 'cultura',
  'w_lencois', 'kite', 'hero_dunas', 'w_guaras', 'w_saoluis', 'saoluis',
];
const _wd = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const _ink = MP.seasonNight;
const _muted = Color(0xff8a94a3);

String _cap(String s) => s[0].toUpperCase() + s.substring(1);
String _photo(int month) => 'assets/photos/${_photos[month - 1]}.jpg';
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Dicas marcadas como "já fiz", compartilhadas entre o cartão e a tela.
final ValueNotifier<Set<String>> _doneTips = ValueNotifier(<String>{});

/// Cartão compacto do início: foto com o dia, época e a semana atual.
/// Atualiza sozinho na virada do dia; o toque abre o calendário completo.
class SeasonCalendarCard extends StatefulWidget {
  const SeasonCalendarCard({super.key, this.now});
  final DateTime Function()? now;
  @override
  State<SeasonCalendarCard> createState() => _SeasonCalendarCardState();
}

class _SeasonCalendarCardState extends State<SeasonCalendarCard> {
  late DateTime _today = _now();
  Timer? _timer;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final n = _now();
    final next = DateTime(n.year, n.month, n.day + 1, 0, 0, 5);
    _timer = Timer(next.difference(n), () {
      if (!mounted) return;
      setState(() => _today = _now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open([DateTime? day]) => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => SeasonCalendarScreen(today: _today, initial: day ?? _today)),
      );

  @override
  Widget build(BuildContext context) {
    final d = _today;
    final s = kSeasons[d.month - 1];
    final accent = s.colors.first;
    final sunday = d.subtract(Duration(days: d.weekday % 7));
    return Semantics(
      button: true,
      label: 'Calendário: ${d.day} de ${_months[d.month - 1]}, ${s.title}. Toque para abrir.',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('home-calendar'),
          onTap: _open,
          child: Container(
            height: 128,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xffe6e9ee)),
            ),
            child: Row(
              children: [
                // Foto da época com o dia.
                Hero(
                  tag: 'season-photo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 96,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset(_photo(d.month), fit: BoxFit.cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x000e1b2a), Color(0xcc0e1b2a)],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(_months[d.month - 1].substring(0, 3).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                              Text('${d.day}',
                                  style: const TextStyle(color: Colors.white, fontSize: 34, height: 1, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(s.icon, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.open_in_full_rounded, size: 16, color: _muted),
                      ]),
                      const SizedBox(height: 2),
                      Text(s.highlights.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      // Semana atual: cada dia abre o calendário nele.
                      Row(children: [
                        for (var k = 0; k < 7; k++)
                          Expanded(
                            child: Builder(builder: (_) {
                              final day = sunday.add(Duration(days: k));
                              final today = _sameDay(day, d);
                              return GestureDetector(
                                onTap: () => _open(day),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    color: today ? accent : const Color(0xfff3f5f8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(children: [
                                    Text(_wd[k],
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: today ? Colors.white70 : _muted)),
                                    Text('${day.day}',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: today ? Colors.white : _ink)),
                                  ]),
                                ),
                              );
                            }),
                          ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calendário completo: arraste para trocar de mês, toque num dia para ver
/// a época e marque as dicas que já fez.
class SeasonCalendarScreen extends StatefulWidget {
  const SeasonCalendarScreen({super.key, required this.today, required this.initial});
  final DateTime today, initial;
  @override
  State<SeasonCalendarScreen> createState() => _SeasonCalendarScreenState();
}

class _SeasonCalendarScreenState extends State<SeasonCalendarScreen> {
  static const _span = 24; // meses navegáveis (12 para trás, 12 para frente)
  late final DateTime _base = DateTime(widget.today.year, widget.today.month - 12);
  late DateTime _sel = widget.initial;
  late final PageController _pc = PageController(initialPage: _indexOf(widget.initial));

  int _indexOf(DateTime d) => (d.year - _base.year) * 12 + d.month - _base.month;
  DateTime _monthAt(int i) => DateTime(_base.year, _base.month + i);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int delta) => _pc.animateToPage(
        (_pc.page!.round() + delta).clamp(0, _span - 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

  @override
  Widget build(BuildContext context) {
    final s = kSeasons[_sel.month - 1];
    final accent = s.colors.first;
    final today = widget.today;
    return Scaffold(
      backgroundColor: const Color(0xfff5f6f8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            actions: [
              if (!_sameDay(_sel, today))
                TextButton(
                  onPressed: () {
                    setState(() => _sel = today);
                    _pc.animateToPage(_indexOf(today), duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(tr('Hoje'), style: TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 16),
              title: Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)])),
              background: Hero(
                tag: 'season-photo',
                child: Stack(fit: StackFit.expand, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Image.asset(_photo(_sel.month), key: ValueKey(_sel.month), fit: BoxFit.cover, width: double.infinity),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x660e1b2a), Color(0x000e1b2a), Color(0xcc0e1b2a)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 52,
                    child: Text(
                      '${_cap(_weekdays[_sel.weekday - 1])}, ${_sel.day} de ${_months[_sel.month - 1]}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                AnimatedBuilder(
                  animation: _pc,
                  builder: (_, _) {
                    final i = _pc.hasClients && _pc.page != null ? _pc.page!.round() : _indexOf(widget.initial);
                    final m = _monthAt(i);
                    return Row(children: [
                      IconButton(onPressed: i > 0 ? () => _go(-1) : null, icon: const Icon(Icons.chevron_left_rounded)),
                      Expanded(
                        child: Text('${_cap(_months[m.month - 1])} ${m.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(onPressed: i < _span - 1 ? () => _go(1) : null, icon: const Icon(Icons.chevron_right_rounded)),
                    ]);
                  },
                ),
                Row(children: [
                  for (final w in _wd)
                    Expanded(
                      child: Center(child: Text(w, style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w700))),
                    ),
                ]),
                const SizedBox(height: 6),
                SizedBox(
                  height: 6 * 44,
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: _span,
                    onPageChanged: (i) {
                      final m = _monthAt(i);
                      if (m.year == _sel.year && m.month == _sel.month) return;
                      final t = widget.today;
                      setState(() => _sel = m.year == t.year && m.month == t.month ? t : m);
                    },
                    itemBuilder: (_, i) => _MonthGrid(
                      month: _monthAt(i),
                      today: today,
                      selected: _sel,
                      onPick: (d) => setState(() => _sel = d),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: _doneTips,
                builder: (_, done, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(s.icon, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Bom para turistar em ${_months[_sel.month - 1]}',
                            style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                      Text('${s.highlights.where(done.contains).length}/${s.highlights.length}',
                          style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                    ]),
                    const SizedBox(height: 2),
                    Text(s.subtitle, style: const TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 4),
                    for (final h in s.highlights)
                      CheckboxListTile(
                        value: done.contains(h),
                        onChanged: (v) => _doneTips.value = {...done}..toggle(h, v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: accent,
                        checkboxShape: const CircleBorder(),
                        title: Text(h,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: done.contains(h) ? TextDecoration.lineThrough : null,
                            )),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Linha do ano: toque num mês para ir até ele.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(tr('O ano no Maranhão'), style: TextStyle(color: _ink.withValues(alpha: .9), fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: 12,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, k) {
                  final m = k + 1;
                  final on = m == _sel.month;
                  return GestureDetector(
                    onTap: () {
                      final target = DateTime(_sel.year, m, 1);
                      setState(() => _sel = target);
                      _pc.animateToPage(_indexOf(target).clamp(0, _span - 1),
                          duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: on ? kSeasons[k].colors.first : Colors.transparent, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(fit: StackFit.expand, children: [
                          Image.asset(_photo(m), fit: BoxFit.cover),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x000e1b2a), Color(0xd90e1b2a)],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(_cap(_months[k]).substring(0, 3),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800)),
                                Text(kSeasons[k].title,
                                    maxLines: 2,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.15, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.today, required this.selected, required this.onPick});
  final DateTime month, today, selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final accent = kSeasons[month.month - 1].colors.first;
    return Column(children: [
      for (var r = 0; r < 6; r++)
        SizedBox(
          height: 44,
          child: Row(children: [
            for (var k = 0; k < 7; k++)
              Expanded(
                child: Builder(builder: (_) {
                  final n = r * 7 + k - lead + 1;
                  if (n < 1 || n > days) return const SizedBox();
                  final d = DateTime(month.year, month.month, n);
                  final isSel = _sameDay(d, selected);
                  final isToday = _sameDay(d, today);
                  final past = d.isBefore(DateTime(today.year, today.month, today.day));
                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPick(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? accent : null,
                          border: isToday && !isSel ? Border.all(color: accent, width: 2) : null,
                        ),
                        child: Text('$n',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isSel || isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? Colors.white : (past ? const Color(0xffb3bac4) : _ink),
                            )),
                      ),
                    ),
                  );
                }),
              ),
          ]),
        ),
    ]);
  }
}

extension on Set<String> {
  void toggle(String v, bool on) => on ? add(v) : remove(v);
}
