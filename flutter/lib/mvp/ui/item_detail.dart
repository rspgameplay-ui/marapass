import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart';
import 'checkin.dart';
import 'common.dart';
import 'coupons.dart';
import 'services.dart';
import 'stay.dart';

/// Ficha única para todas as categorias. A ação principal muda conforme o tipo:
/// reservar (passeio, natureza, cultura), cupom e contato (gastronomia,
/// hospedagem), salvar (evento), comprar (artesanato), contratar (fotografia)
/// e cotar (transporte).
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.item});
  final Item item;

  void _share(BuildContext context) {
    final link = 'https://teste.marapass.com/#${item.id}';
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compartilhar experiência',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: MP.s2),
            Text(item.titulo, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: MP.s4),
            FilledButton.icon(
              key: const Key('share-copy'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${item.titulo} no MaraPass: $link'),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showMpSnack(
                    context,
                    'Link copiado. Cole na conversa que quiser.',
                  );
                }
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('Copiar link'),
            ),
            const SizedBox(height: MP.s3),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                openWhatsApp(context, '', '${item.titulo} no MaraPass: $link');
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Enviar pelo WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final i = item;
    final polo = Content.polo(i.polo);
    final cupom = Content.cupom(i.cupom);
    final meta = [
      i.cidade,
      if (i.duracao != null) i.duracao!,
      i.faixaLabel,
    ].join(' · ');

    // Ação principal fixa embaixo (padrão do protótipo); as demais ficam na página.
    final acts = _actions(context, ref, store);
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s3),
          decoration: const BoxDecoration(
            color: MP.page,
            border: Border(top: BorderSide(color: MP.border)),
          ),
          child: acts.first,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          MpPhoto(
            photo: i.hero ?? i.foto,
            height: 300,
            radius: 0,
            icon: i.cat.icon,
            seed: i.id.hashCode,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(MP.s4),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      const MpBackPill(onDark: true),
                      const Spacer(),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: const Key('item-share'),
                          tooltip: 'Compartilhar',
                          onPressed: () => _share(context),
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: MP.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: MP.s2),
                      FavButton(i.id),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MpBadge(
                  i.cat.label,
                  fg: i.cat.tint.fg,
                  bg: i.cat.tint.bg,
                  icon: i.cat.icon,
                ),
                const SizedBox(height: MP.s2),
                Text(
                  i.titulo,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: MP.textSecondary),
                ),
                if (i.cat == Cat.hospedagem || i.cat == Cat.gastronomia) ...[
                  const SizedBox(height: MP.s3),
                  StayFacts(item: i),
                ],
                const SizedBox(height: MP.s3),
                Wrap(
                  spacing: MP.s2,
                  runSpacing: MP.s2,
                  children: [
                    if (i.acessivel)
                      const MpBadge(
                        'Acessível',
                        fg: MP.info,
                        icon: Icons.accessible_rounded,
                      ),
                    if (i.autentica)
                      const MpBadge(
                        'Experiência autêntica',
                        fg: MP.green,
                        icon: Icons.handshake_rounded,
                      ),
                    if (store.alreadyCheckedIn(i.id))
                      const MpBadge(
                        'Você fez check-in hoje',
                        fg: MP.success,
                        icon: Icons.verified_rounded,
                      ),
                  ],
                ),
                if (i.precoCents != null) ...[
                  const SizedBox(height: MP.s4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: i.cat == Cat.artesanato ? '' : 'a partir de ',
                          style: const TextStyle(
                            fontSize: 16,
                            color: MP.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: formatBrl(i.precoCents!),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: MP.green,
                          ),
                        ),
                        TextSpan(
                          text: i.cat.reservavel
                              ? ' por pessoa'
                              : (i.cat == Cat.hospedagem ? ' por noite' : ''),
                          style: const TextStyle(
                            fontSize: 16,
                            color: MP.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: MP.s4),
                Text(i.descricao, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: MP.s3),
                if (i.data != null)
                  MpInfoRow(
                    Icons.event_rounded,
                    '${fmtLong(i.data!)} às ${fmtTime(i.data!)}',
                  ),
                if (i.horario != null)
                  MpInfoRow(Icons.schedule_rounded, i.horario!),
                if (i.saida != null)
                  MpInfoRow(Icons.flag_rounded, 'Saída: ${i.saida}'),
                if (i.endereco != null)
                  MpInfoRow(
                    Icons.place_rounded,
                    i.endereco!,
                    onTap: () => openMaps(context, i.mapsQuery),
                  ),
                if (i.telefone != null)
                  MpInfoRow(
                    Icons.call_rounded,
                    i.telefone!,
                    onTap: () => callPhone(context, i.telefone!),
                  ),
                if (i.artesao != null)
                  MpInfoRow(Icons.person_rounded, 'Feito por ${i.artesao}'),
                MpInfoRow(
                  Icons.landscape_rounded,
                  'Destino: ${polo.nome}',
                  onTap: () => openPolo(context, polo),
                ),
                if (cupom != null) ...[
                  const SizedBox(height: MP.s4),
                  Text(
                    'Cupom disponível',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MP.s2),
                  TicketCard(
                    cupom: cupom,
                    onTap: () =>
                        push<void>(context, CouponDetailScreen(cupom: cupom)),
                  ),
                ],
                if (i.cat == Cat.passeio || i.cat == Cat.natureza) ...[
                  const SizedBox(height: MP.sectionGap),
                  _PackList(itemId: i.id),
                ],
                const SizedBox(height: MP.sectionGap),
                ...acts.skip(1),
                const SizedBox(height: MP.s3),
                if (i.cat != Cat.transporte &&
                    i.cat != Cat.fotografia &&
                    i.cat != Cat.artesanato)
                  TextButton.icon(
                    key: const Key('item-checkin'),
                    onPressed: () =>
                        push<void>(context, CheckinFlowScreen(item: i)),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Estou aqui: fazer check-in'),
                  ),
                const SizedBox(height: MP.s6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, AppStore store) {
    final i = item;
    final cupom = Content.cupom(i.cupom);
    switch (i.cat) {
      case Cat.passeio || Cat.natureza || Cat.cultura:
        return [
          MpCtaButton(
            key: const Key('item-reserve'),
            label: 'Reservar',
            onPressed: () => push<void>(context, BookingScreen(item: i)),
          ),
        ];
      case Cat.hospedagem:
        return [
          MpCtaButton(
            key: const Key('item-availability'),
            label: 'Ver disponibilidade',
            icon: Icons.calendar_month_rounded,
            onPressed: () =>
                push<void>(context, StayAvailabilityScreen(item: i)),
          ),
          if (cupom != null) ...[
            const SizedBox(height: MP.s3),
            OutlinedButton.icon(
              key: const Key('item-coupon'),
              onPressed: () =>
                  push<void>(context, CouponDetailScreen(cupom: cupom)),
              icon: const Icon(Icons.local_activity_rounded),
              label: const Text('Ativar cupom'),
            ),
          ],
          const SizedBox(height: MP.s3),
          OutlinedButton.icon(
            onPressed: () => openMaps(context, i.mapsQuery),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Como chegar'),
          ),
          if (i.telefone != null) ...[
            const SizedBox(height: MP.s3),
            OutlinedButton.icon(
              onPressed: () => callPhone(context, i.telefone!),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Ligar'),
            ),
          ],
        ];
      case Cat.gastronomia:
        return [
          if (cupom != null) ...[
            MpCtaButton(
              key: const Key('item-coupon'),
              label: 'Ativar cupom',
              icon: Icons.local_activity_rounded,
              onPressed: () =>
                  push<void>(context, CouponDetailScreen(cupom: cupom)),
            ),
            const SizedBox(height: MP.s3),
          ],
          if (cupom == null)
            FilledButton.icon(
              onPressed: () => openMaps(context, i.mapsQuery),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Como chegar'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => openMaps(context, i.mapsQuery),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Como chegar'),
            ),
          if (i.telefone != null) ...[
            const SizedBox(height: MP.s3),
            OutlinedButton.icon(
              onPressed: () => callPhone(context, i.telefone!),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Ligar'),
            ),
          ],
        ];
      case Cat.evento:
        final saved = store.isSaved(i.id);
        return [
          MpCtaButton(
            key: const Key('item-save-event'),
            label: saved ? 'Evento salvo' : 'Salvar evento',
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_add_rounded,
            onPressed: () {
              store.toggleSaved(i.id);
              showMpSnack(
                context,
                saved
                    ? 'Evento removido da sua agenda'
                    : 'Evento salvo. Avisaremos perto do dia.',
              );
            },
          ),
          const SizedBox(height: MP.s3),
          OutlinedButton.icon(
            onPressed: () =>
                openMaps(context, '${i.endereco ?? i.titulo} ${i.cidade}'),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Como chegar'),
          ),
        ];
      case Cat.artesanato:
        return [
          MpCtaButton(
            key: const Key('item-buy'),
            label: 'Quero comprar',
            icon: Icons.shopping_bag_rounded,
            onPressed: () => push<void>(context, CraftPurchaseScreen(item: i)),
          ),
        ];
      case Cat.fotografia:
        return [
          MpCtaButton(
            key: const Key('item-hire'),
            label: 'Contratar fotógrafo',
            icon: Icons.photo_camera_rounded,
            onPressed: () => push<void>(context, PhotoHireScreen(item: i)),
          ),
        ];
      case Cat.transporte:
        return [
          MpCtaButton(
            key: const Key('item-quote'),
            label: 'Pedir cotação',
            icon: Icons.request_quote_rounded,
            onPressed: () => push<void>(context, TransferQuoteScreen(item: i)),
          ),
        ];
    }
  }
}

class _PackList extends ConsumerWidget {
  const _PackList({required this.itemId});
  final String itemId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final got = store.pack(itemId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('O que levar', style: Theme.of(context).textTheme.titleLarge),
        Text(
          'Toque para marcar · ${got.length}/${Content.oQueLevar.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: MP.s2),
        for (var k = 0; k < Content.oQueLevar.length; k++)
          CheckboxListTile(
            key: Key('pack-$k'),
            value: got.contains(k),
            onChanged: (_) => store.togglePack(itemId, k),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: MP.green,
            title: Text(
              Content.oQueLevar[k],
              style: const TextStyle(fontSize: 17),
            ),
          ),
        if (got.length == Content.oQueLevar.length)
          const MpBadge(
            'Tudo pronto para o passeio!',
            fg: MP.success,
            icon: Icons.celebration_rounded,
          ),
      ],
    );
  }
}
