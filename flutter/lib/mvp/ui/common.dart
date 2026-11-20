import '../../core/config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'catalog.dart';
import 'item_detail.dart';

void openItem(BuildContext context, Item item) =>
    push<void>(context, ItemDetailScreen(item: item));
void openPolo(BuildContext context, Polo polo) =>
    push<void>(context, PoloScreen(polo: polo));

/// Política de privacidade e termos (páginas públicas exigidas pelas lojas).
Future<void> openLegal(BuildContext context, String page) async {
  final base = kIsWeb ? Uri.base.origin : AppConfig.siteUrl;
  final uri = Uri.parse('$base/legal/$page.html');
  if (!await launchUrl(uri) && context.mounted) {
    showMpSnack(context, 'Não foi possível abrir a página agora.');
  }
}

Future<void> openMaps(BuildContext context, String query) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    showMpSnack(context, 'Não foi possível abrir o mapa.');
  }
}

Future<void> callPhone(BuildContext context, String phone) async {
  final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
  if (!await launchUrl(uri) && context.mounted) {
    showMpSnack(context, 'Ligue para $phone');
  }
}

Future<void> openWhatsApp(
  BuildContext context,
  String phone,
  String text,
) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.parse(
    'https://wa.me/55$digits?text=${Uri.encodeComponent(text)}',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    showMpSnack(context, 'Não foi possível abrir o WhatsApp.');
  }
}

String priceLabel(Item i) => i.precoCents == null
    ? i.faixaLabel
    : 'a partir de ${formatBrl(i.precoCents!)}';

/// Coração de favorito sobre foto.
class FavButton extends ConsumerWidget {
  const FavButton(this.id, {super.key, this.size = 44});
  final String id;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(appStoreProvider.select((s) => s.isFav(id)));
    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          key: Key('fav-$id'),
          customBorder: const CircleBorder(),
          onTap: () => ref.read(appStoreProvider).toggleFav(id),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: on ? MP.error : MP.ink,
              size: size * .52,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão grande com foto (Destinos / passeios do protótipo).
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.photo,
    this.favId,
    this.height = 180,
    this.icon = Icons.landscape_rounded,
    this.badge,
    this.seed = 0,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? photo;
  final String? favId;
  final double height;
  final IconData icon;
  final String? badge;
  final int seed;
  @override
  Widget build(BuildContext context) => MpCard(
    onTap: onTap,
    padding: EdgeInsets.zero,
    semanticLabel: '$title. $subtitle',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            MpPhoto(
              photo: photo,
              height: height,
              icon: icon,
              seed: seed,
              radius: MP.rLarge,
            ),
            if (favId != null)
              Positioned(top: 10, right: 10, child: FavButton(favId!)),
            if (badge != null)
              Positioned(
                top: 12,
                left: 12,
                child: MpBadge(badge!, fg: MP.ink, bg: Colors.white),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(MP.s4, MP.s3, MP.s3, MP.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: MP.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: MP.soft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded, color: MP.ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Cartão compacto de item para carrossel horizontal.
class ItemMiniCard extends StatelessWidget {
  const ItemMiniCard({super.key, required this.item, this.width = 230});
  final Item item;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: MpCard(
      onTap: () => openItem(context, item),
      padding: EdgeInsets.zero,
      semanticLabel: item.titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpPhoto(
            photo: item.foto,
            height: 130,
            icon: item.cat.icon,
            seed: item.id.hashCode,
          ),
          Padding(
            padding: const EdgeInsets.all(MP.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (item.duracao != null)
                  Text(
                    item.duracao!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                Text(
                  item.precoCents == null
                      ? item.cidade
                      : formatBrl(item.precoCents!),
                  style: const TextStyle(
                    color: MP.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Linha de item em lista (resultados, categorias).
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.item, this.showDistance = false});
  final Item item;
  final bool showDistance;
  @override
  Widget build(BuildContext context) {
    final cupom = Content.cupom(item.cupom);
    return MpCard(
      onTap: () => openItem(context, item),
      padding: const EdgeInsets.all(MP.s3),
      semanticLabel: '${item.titulo}, ${item.cidade}',
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: MpPhoto(
              photo: item.foto,
              height: 96,
              radius: MP.rMedium,
              icon: item.cat.icon,
              seed: item.id.hashCode,
            ),
          ),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    item.cidade,
                    if (showDistance && item.distanciaKm != null)
                      '${item.distanciaKm!.round()} km',
                    item.faixaLabel,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (cupom != null)
                      MpBadge(
                        cupom.beneficio,
                        fg: MP.warning,
                        bg: MP.goldBg,
                        icon: Icons.local_activity_rounded,
                      ),
                    if (item.acessivel)
                      const MpBadge(
                        'Acessível',
                        fg: MP.info,
                        icon: Icons.accessible_rounded,
                      ),
                    if (item.autentica)
                      const MpBadge('Autêntica', fg: MP.green),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: MP.textMuted,
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// Chips de filtro em linha horizontal rolável.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelect,
  });
  final List<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
      itemBuilder: (_, i) {
        final o = options[i];
        final on = o == selected;
        return ChoiceChip(
          key: Key('chip-${label(o)}'),
          label: Text(label(o)),
          selected: on,
          labelStyle: TextStyle(
            fontFamily: mpFont,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: on ? Colors.white : MP.ink,
          ),
          onSelected: (_) => onSelect(o),
        );
      },
    ),
  );
}

/// Cupom em formato de ingresso (protótipo aprovado).
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.cupom,
    required this.onTap,
    this.status,
    this.statusColor = MP.green,
    this.code,
    this.onQr,
  });
  final Cupom cupom;
  final VoidCallback onTap;
  final String? status;
  final Color statusColor;

  /// Código de verificação do cupom ativado (exibido parcialmente).
  final String? code;

  /// Atalho para abrir o QR de resgate.
  final VoidCallback? onQr;
  @override
  Widget build(BuildContext context) {
    final days = cupom.validade.difference(DateTime.now()).inDays;
    return Semantics(
      button: true,
      label: '${cupom.parceiro}, ${cupom.beneficio}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MP.rLarge),
        child: Container(
          decoration: BoxDecoration(
            color: MP.card,
            borderRadius: BorderRadius.circular(MP.rLarge),
            border: Border.all(color: MP.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: MpPhoto(
                    photo: cupom.foto,
                    height: null,
                    radius: MP.rLarge,
                    icon: cupom.cat.icon,
                  ),
                ),
                CustomPaint(
                  size: const Size(14, double.infinity),
                  painter: _Perforation(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MP.s2,
                      MP.s3,
                      MP.s3,
                      MP.s3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cupom.cat.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: MP.textSecondary,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cupom.beneficio,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MP.green,
                          ),
                        ),
                        Text(
                          cupom.parceiro,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                days < 0
                                    ? 'Venceu'
                                    : (days <= 7
                                          ? 'Vence em $days ${days == 1 ? 'dia' : 'dias'}'
                                          : 'Até ${_d(cupom.validade)}'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: days <= 7
                                      ? MP.warning
                                      : MP.textSecondary,
                                ),
                              ),
                            ),
                            if (status != null)
                              MpBadge(status!, fg: statusColor),
                          ],
                        ),
                        if (code != null || onQr != null) ...[
                          const SizedBox(height: MP.s2),
                          Row(
                            children: [
                              if (code != null)
                                Expanded(
                                  child: Text(
                                    'Cód. ••••${code!.length > 4 ? code!.substring(code!.length - 4) : code}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: MP.textSecondary,
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),
                              if (onQr != null)
                                FilledButton.tonalIcon(
                                  key: Key('ticket-qr-${cupom.id}'),
                                  onPressed: onQr,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 40),
                                    padding: const EdgeInsets.symmetric(horizontal: MP.s3),
                                    backgroundColor: MP.tintGreen,
                                    foregroundColor: MP.green,
                                  ),
                                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                  label: const Text('Resgatar'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Perforation extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = MP.border;
    for (double y = 6; y < size.height - 4; y += 10) {
      canvas.drawCircle(Offset(size.width / 2, y), 2, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
const _wd = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];
const _mo = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
String fmtLong(DateTime d) =>
    '${_wd[d.weekday - 1]}, ${d.day} de ${_mo[d.month - 1]}';
String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}h${d.minute == 0 ? '' : d.minute.toString().padLeft(2, '0')}';
