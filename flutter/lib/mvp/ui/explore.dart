import 'dart:async';

import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'catalog.dart';
import 'common.dart';
import 'home.dart' show openMap;

/// Explorar: busca universal + categorias + polos + experiências autênticas.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  static const _sugestoes = [
    'lagoas',
    'arroz de cuxá',
    'pousada',
    'cachoeira',
    'boi',
    'artesanato',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _set(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _q = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: _body(context));

  Widget _body(BuildContext context) {
    final results = Content.search(_q);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          MpHeader(
            tr('Explorar'),
            back: true,
            subtitle: tr('Busque por lugar, passeio, comida ou cidade.'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: TextField(
              key: const Key('explore-search'),
              controller: _ctrl,
              onChanged: _set,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: tr('Digite um lugar ou passeio'),
                prefixIcon: const Icon(Icons.search_rounded, size: 26),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('Limpar busca'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _q = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: MP.s3),
          if (_q.isEmpty) ...[
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                itemCount: _sugestoes.length,
                separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_sugestoes[i]),
                  avatar: const Icon(Icons.trending_up_rounded, size: 18),
                  onPressed: () {
                    _ctrl.text = _sugestoes[i];
                    setState(() => _q = _sugestoes[i]);
                  },
                ),
              ),
            ),
            const SizedBox(height: MP.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                children: [
                  MpListTile(
                    key: const Key('explore-map'),
                    icon: Icons.map_rounded,
                    title: tr('Mapa turístico'),
                    subtitle: tr('217 municípios, rotas e navegação com voz'),
                    tint: MP.tintBlue,
                    onTap: () => openMap(context),
                  ),
                  const SizedBox(height: MP.s3),
                  MpListTile(
                    key: const Key('explore-authentic'),
                    icon: Icons.handshake_rounded,
                    title: tr('Experiências autênticas'),
                    subtitle: tr('Vivências com comunidades locais'),
                    tint: MP.tintGreen,
                    color: MP.green,
                    onTap: () => push<void>(context, const AuthenticScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MP.sectionGap),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MP.pageH),
              child: MpSectionTitle(tr('Categorias')),
            ),
            const SizedBox(height: MP.s3),
            for (final c in Cat.values)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s2,
                ),
                child: MpListTile(
                  key: Key('explore-cat-${c.name}'),
                  icon: c.icon,
                  title: c.label,
                  subtitle: '${Content.byCat(c).length} ${tr('opções')}',
                  tint: c.tint.bg,
                  color: c.tint.fg,
                  onTap: () => push<void>(context, CategoryScreen(cat: c)),
                ),
              ),
            const SizedBox(height: MP.sectionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: MpSectionTitle(
                tr('Polos turísticos'),
                action: tr('Ver os 11'),
                onAction: () => push<void>(context, const PolosScreen()),
              ),
            ),
            const SizedBox(height: MP.s3),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                itemCount: Content.polos.length,
                separatorBuilder: (_, _) => const SizedBox(width: MP.s3),
                itemBuilder: (_, i) {
                  final p = Content.polos[i];
                  return SizedBox(
                    width: 220,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(MP.rLarge),
                      onTap: () => openPolo(context, p),
                      child: MpPhoto(
                        photo: p.foto,
                        height: 200,
                        darken: true,
                        seed: p.id.hashCode,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(MP.s3),
                            child: Text(
                              p.nome,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MP.pageH,
                MP.s2,
                MP.pageH,
                MP.s2,
              ),
              child: Text(
                '${results.length} ${results.length == 1 ? tr('resultado') : tr('resultados')} ${tr('para')} "$_q"',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            if (results.isEmpty)
              MpEmpty(
                icon: Icons.search_off_rounded,
                title: '${tr('Nada encontrado para')} "$_q"',
                message:
                    tr('Tente outra palavra, como o nome da cidade ou do prato.'),
                actionLabel: tr('Limpar busca'),
                onAction: () {
                  _ctrl.clear();
                  setState(() => _q = '');
                },
              ),
            for (final i in results)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: ItemRow(item: i),
              ),
            for (final p in Content.polos.where(
              (p) => p.nome.toLowerCase().contains(_q.toLowerCase()),
            ))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: MpListTile(
                  icon: Icons.place_rounded,
                  title: p.nome,
                  subtitle: tr('Polo turístico'),
                  onTap: () => openPolo(context, p),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
