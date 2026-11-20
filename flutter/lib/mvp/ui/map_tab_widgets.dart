part of 'map_tab.dart';

class _MapButton extends StatelessWidget {
  const _MapButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.label,
    this.active = false,
  });
  final String tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final bool active;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    label: tooltip,
    excludeSemantics: true,
    onTap: onTap,
    child: Tooltip(
    message: tooltip,
    child: Material(
      elevation: 6,
      shadowColor: Colors.black54,
      color: active ? MP.navy : MP.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
        side: BorderSide(color: active ? MP.navy : MP.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(MP.rMedium),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: TextStyle(
                      fontFamily: mpFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: active ? Colors.white : MP.ink,
                    ),
                  )
                : Icon(
                    icon,
                    color: active ? Colors.white : MP.ink,
                    size: 24,
                    semanticLabel: tooltip,
                  ),
          ),
        ),
      ),
    ),
  ));
}

String _km(double m) => m >= 1000
    ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1).replaceAll('.', ',')} km'
    : '${m.round()} m';
String _time(double s) {
  final min = (s / 60).round();
  if (min < 60) return '$min min';
  return '${min ~/ 60} h ${(min % 60).toString().padLeft(2, '0')} min';
}

/// Botão compacto quadrado (ações secundárias como 3D).
class _SquareAction extends StatelessWidget {
  const _SquareAction({super.key, required this.label, required this.tooltip, required this.onTap});
  final String label, tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(MP.buttonHeight, MP.buttonHeight),
        maximumSize: const Size(72, MP.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: MP.s3),
        side: const BorderSide(color: MP.border, width: 1.5),
        foregroundColor: MP.navy,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
    ),
  );
}

/// Cabeçalho comum dos cards do mapa: foto (ou capa da categoria), título e X.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.poi, required this.onX, required this.xTooltip, this.xKey});
  final Poi poi;
  final VoidCallback onX;
  final String xTooltip;
  final Key? xKey;
  @override
  Widget build(BuildContext context) {
    final it = poi.item;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: MpPhoto(
            key: const Key('poi-photo'),
            photo: it?.foto ?? _covers[poi.kind],
            height: 72,
            radius: MP.rMedium,
            icon: poi.kind.icon,
          ),
        ),
        const SizedBox(width: MP.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(poi.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(poi.kind.icon, size: 16, color: poi.kind.color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${poi.kind.label} · ${poi.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (it != null && it.loc != Loc.exato) ...[
                const SizedBox(height: 2),
                Row(
                  key: const Key('poi-precision'),
                  children: [
                    Icon(
                      it.loc == Loc.aproximado ? Icons.blur_circular_rounded : Icons.place_rounded,
                      size: 14,
                      color: MP.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(it.loc.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
                    ),
                  ],
                ),
              ],
              if (it?.nota != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    RatingLine(item: it!, size: 14),
                    const SizedBox(width: MP.s2),
                    Text(it.faixaLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MP.green)),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          key: xKey,
          tooltip: xTooltip,
          onPressed: onX,
          style: IconButton.styleFrom(backgroundColor: MP.soft, minimumSize: const Size(44, 44)),
          icon: const Icon(Icons.close_rounded, color: MP.ink),
        ),
      ],
    );
  }
}

class _PoiCard extends StatelessWidget {
  const _PoiCard({
    required this.poi,
    required this.route,
    required this.routing,
    required this.error,
    required this.originLabel,
    required this.onChangeOrigin,
    required this.onClose,
    required this.onRoute,
    required this.onClearRoute,
    required this.onFollow3d,
    required this.onNavigate,
    required this.onDetails,
    this.extras = const [],
  });
  final Poi poi;
  final RoadRoute? route;
  final bool routing;
  final String? error;
  final String originLabel;
  final VoidCallback onChangeOrigin;
  final VoidCallback onClose, onRoute, onClearRoute, onFollow3d, onNavigate;
  final VoidCallback? onDetails;
  final List<(IconData, String, VoidCallback)> extras;

  @override
  Widget build(BuildContext context) {
    final r = route;
    final it = poi.item;
    final stay = it != null && (it.cat == Cat.hospedagem || it.cat == Cat.gastronomia);
    return Material(
      key: const Key('map-poi-card'),
      elevation: 10,
      shadowColor: Colors.black45,
      color: MP.card,
      borderRadius: BorderRadius.circular(MP.rXl),
      child: Padding(
        padding: const EdgeInsets.all(MP.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(
              poi: poi,
              onX: r != null ? onClearRoute : onClose,
              xTooltip: r != null ? 'Limpar rota' : 'Fechar',
              xKey: Key(r != null ? 'route-clear' : 'poi-close'),
            ),
            if (r != null) ...[
              const SizedBox(height: MP.s3),
              // Linha de informações da rota
              Container(
                key: const Key('route-info'),
                padding: const EdgeInsets.fromLTRB(MP.s3, MP.s3, MP.s1, MP.s2),
                decoration: BoxDecoration(color: const Color(0xffeef4fd), borderRadius: BorderRadius.circular(MP.rMedium)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _time(r.duration),
                          key: const Key('route-time'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xff0b57d0)),
                        ),
                        const SizedBox(width: MP.s2),
                        Expanded(
                          child: Text(
                            '${_km(r.distance)}${r.summary.isEmpty ? '' : ' · via ${r.summary}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: MP.text, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.trip_origin_rounded, size: 16, color: MP.routeBlue),
                        const SizedBox(width: MP.s1),
                        Expanded(
                          child: Text(
                            'Partida: $originLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: MP.textSecondary),
                          ),
                        ),
                        IconButton(
                          key: const Key('route-origin'),
                          tooltip: 'Alterar partida',
                          onPressed: onChangeOrigin,
                          icon: const Icon(Icons.edit_location_alt_rounded, color: MP.navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MP.s3),
              // Linha de ações: 1 primária + 1 compacta
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('route-go'),
                      onPressed: onNavigate,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Iniciar navegação'),
                    ),
                  ),
                  const SizedBox(width: MP.s2),
                  _SquareAction(key: const Key('route-3d'), label: '3D', tooltip: 'Ver a partida em 3D', onTap: onFollow3d),
                ],
              ),
            ] else ...[
              if (stay) ...[
                const SizedBox(height: MP.s3),
                StayFacts(item: it, compact: true),
              ],
              if (extras.isNotEmpty) ...[
                const SizedBox(height: MP.s3),
                Wrap(
                  spacing: MP.s2,
                  runSpacing: MP.s2,
                  children: [
                    for (final e in extras)
                      ActionChip(
                        key: Key('poi-extra-${e.$2}'),
                        avatar: Icon(e.$1, size: 18, color: MP.navy),
                        label: Text(e.$2),
                        onPressed: e.$3,
                      ),
                  ],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: MP.s3),
                MpNotice(error!, icon: Icons.wifi_off_rounded, fg: MP.error, bg: MP.errorBg),
              ],
              const SizedBox(height: MP.s3),
              Row(
                children: [
                  if (onDetails != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('poi-details'),
                        onPressed: onDetails,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                        child: Text(it?.cat == Cat.hospedagem ? 'Disponibilidade' : 'Ver detalhes'),
                      ),
                    ),
                    const SizedBox(width: MP.s2),
                  ],
                  Expanded(
                    child: MpPrimaryButton(
                      key: const Key('route-trace'),
                      label: 'Traçar rota',
                      icon: Icons.directions_rounded,
                      busy: routing,
                      onPressed: onRoute,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card do roteiro do dia no mapa: paradas numeradas, tempo total e navegação.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.route,
    required this.busy,
    required this.error,
    required this.onClose,
    required this.onStop,
    required this.onFollow3d,
    required this.onNavigate,
  });
  final DayPlan plan;
  final RoadRoute? route;
  final bool busy;
  final String? error;
  final VoidCallback onClose, onFollow3d, onNavigate;
  final ValueChanged<int> onStop;

  @override
  Widget build(BuildContext context) {
    final r = route;
    return Material(
      key: const Key('map-plan-card'),
      elevation: 10,
      shadowColor: Colors.black45,
      color: MP.card,
      borderRadius: BorderRadius.circular(MP.rXl),
      child: Padding(
        padding: const EdgeInsets.all(MP.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: MP.tintGreen, borderRadius: BorderRadius.circular(MP.rMedium)),
                  child: const Icon(Icons.route_rounded, color: MP.green),
                ),
                const SizedBox(width: MP.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roteiro do dia · ${plan.city}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        busy
                            ? 'Traçando o percurso…'
                            : r == null
                            ? '${plan.stops.length} paradas'
                            : '${_time(r.duration)} de carro · ${_km(r.distance)} · ${plan.stops.length} paradas',
                        key: const Key('plan-summary'),
                        style: const TextStyle(fontSize: 14, color: MP.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('plan-close'),
                  tooltip: 'Fechar roteiro',
                  onPressed: onClose,
                  style: IconButton.styleFrom(backgroundColor: MP.soft, minimumSize: const Size(44, 44)),
                  icon: const Icon(Icons.close_rounded, color: MP.ink),
                ),
              ],
            ),
            const SizedBox(height: MP.s3),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plan.stops.length,
                separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
                itemBuilder: (_, k) {
                  final st = plan.stops[k];
                  return ActionChip(
                    key: Key('plan-stop-$k'),
                    avatar: CircleAvatar(
                      backgroundColor: st.anchor ? MP.yellow : MP.navy,
                      child: Text('${k + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: st.anchor ? MP.ink : Colors.white)),
                    ),
                    label: Text('${st.time} · ${st.item.titulo}'),
                    onPressed: () => onStop(k),
                  );
                },
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: MP.s3),
              MpNotice(error!, icon: Icons.wifi_off_rounded, fg: MP.warning, bg: MP.warningBg),
            ],
            const SizedBox(height: MP.s3),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('plan-go'),
                    onPressed: r == null ? null : onNavigate,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Iniciar navegação'),
                  ),
                ),
                const SizedBox(width: MP.s2),
                _SquareAction(key: const Key('plan-3d'), label: '3D', tooltip: 'Ver a partida em 3D', onTap: onFollow3d),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de resultados da busca unificada, em grupos, com selo de cupom.
class _SearchResults extends StatelessWidget {
  const _SearchResults({super.key, required this.groups, required this.maxHeight, required this.onPick});
  final List<(String, List<Poi>)> groups;
  final double maxHeight;
  final ValueChanged<Poi> onPick;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(MP.rMedium),
    color: MP.card,
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(MP.s5),
              child: Text('Nada encontrado. Tente o nome do lugar, da empresa ou da cidade.'),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: MP.s2),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(MP.s4, MP.s3, MP.s4, MP.s1),
                    child: Text(
                      g.$1.toUpperCase(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .8, color: MP.textSecondary),
                    ),
                  ),
                  for (final p in g.$2)
                    ListTile(
                      key: Key('result-${p.id}'),
                      minTileHeight: 60,
                      leading: CircleAvatar(
                        backgroundColor: p.kind.color.withValues(alpha: .14),
                        child: Icon(p.kind.icon, color: p.kind.color),
                      ),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      subtitle: Text('${p.kind.label} · ${p.city}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: p.hasCoupon
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: MP.s2, vertical: 4),
                              decoration: BoxDecoration(color: MP.green, borderRadius: BorderRadius.circular(MP.rPill)),
                              child: const Text('CUPOM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
                            )
                          : null,
                      onTap: () => onPick(p),
                    ),
                ],
              ],
            ),
    ),
  );
}

/// Folha de ponto de partida: GPS de novo, uma cidade ou um toque no mapa.
class _OriginSheet extends StatelessWidget {
  const _OriginSheet({required this.gpsFailed});
  final bool gpsFailed;
  @override
  Widget build(BuildContext context) {
    final cities = _cityCenters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          key: const Key('origin-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s5),
          children: [
            Text(
              'De onde você sai?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (gpsFailed) ...[
              const SizedBox(height: MP.s2),
              const MpNotice(
                'Não conseguimos sua localização. Verifique se o navegador tem permissão de localização, ou escolha o ponto de partida.',
                icon: Icons.location_off_rounded,
                fg: MP.warning,
                bg: MP.warningBg,
              ),
            ],
            const SizedBox(height: MP.s3),
            ListTile(
              key: const Key('origin-gps'),
              minTileHeight: 60,
              leading: const CircleAvatar(
                backgroundColor: Color(0xffe8f0fe),
                child: Icon(
                  Icons.my_location_rounded,
                  color: MP.routeBlue,
                ),
              ),
              title: const Text(
                'Usar minha localização',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: const Text('Tentar o GPS de novo'),
              onTap: () => Navigator.of(context).pop('gps'),
            ),
            ListTile(
              key: const Key('origin-map'),
              minTileHeight: 60,
              leading: const CircleAvatar(
                backgroundColor: MP.soft,
                child: Icon(Icons.touch_app_rounded, color: MP.navy),
              ),
              title: const Text(
                'Tocar no mapa',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: const Text('Escolha o ponto exato'),
              onTap: () => Navigator.of(context).pop('map'),
            ),
            const Divider(height: MP.s5),
            const Text(
              'Ou saia de uma cidade',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: MP.textSecondary,
              ),
            ),
            for (final c in cities)
              ListTile(
                key: Key('origin-city-${c.key}'),
                minTileHeight: 56,
                leading: const Icon(
                  Icons.location_city_rounded,
                  color: MP.navy,
                ),
                title: Text(
                  c.key,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
  }
}

/// Página no padrão do app para fichas reaproveitadas do mapa antigo.
class _LegacyPage extends StatelessWidget {
  const _LegacyPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          MpHeader(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Theme(data: legacyMapTheme(), child: child),
          ),
        ],
      ),
    ),
  );
}

/// Navegador sem WebGL: o mapa interativo não abre; oferece o mapa do aparelho.
class _MapUnsupported extends StatelessWidget {
  const _MapUnsupported();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(MP.pageH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: MP.textSecondary),
            const SizedBox(height: MP.s4),
            Text(
              'Mapa indisponível neste navegador',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: MP.s2),
            const Text(
              'O mapa interativo precisa de WebGL. Abra o MaraPass em outro navegador ou instale o app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: MP.textSecondary),
            ),
            const SizedBox(height: MP.s4),
            MpPrimaryButton(
              key: const Key('map-open-external'),
              label: 'Abrir no mapa do aparelho',
              icon: Icons.open_in_new_rounded,
              onPressed: () => openMaps(context, 'Maranhão turismo'),
            ),
          ],
        ),
      ),
    ),
  );
}
