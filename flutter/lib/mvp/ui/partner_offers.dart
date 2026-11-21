part of 'partner.dart';

class _OffersTab extends ConsumerWidget {
  const _OffersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.only(bottom: MP.s8),
        children: [
          _PartnerHeader(
            tr('Gestão de cupons'),
            subtitle: tr('Crie, pause e acompanhe suas ofertas.'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: Key('p-create-offer'),
                  onPressed: () =>
                      push<void>(context, CreateOfferScreen()),
                  icon: Icon(Icons.add_rounded),
                  label: Text(tr('Criar nova oferta')),
                ),
                SizedBox(height: MP.s4),
                if (CatalogCache.servingStale) ...[
                  MpNotice(
                    CatalogCache.lastSync == null
                        ? tr('Sem conexão: mostrando as ofertas salvas neste aparelho.')
                        : '${tr('Sem conexão: ofertas salvas em')} ${fmtDate(CatalogCache.lastSync!)}.',
                    icon: Icons.cloud_off_rounded,
                    fg: MP.warning,
                    bg: MP.warningBg,
                  ),
                  SizedBox(height: MP.s3),
                ],
                for (final o in s.partnerOffers) ...[
                  MpCard(
                    onTap: () =>
                        push<void>(context, OfferManageScreen(id: o.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _OfferStatus(o.status),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          o.benefit,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MP.green,
                          ),
                        ),
                        SizedBox(height: MP.s2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(MP.rPill),
                          child: LinearProgressIndicator(
                            value: o.limit == 0
                                ? 0
                                : (o.issued / o.limit).clamp(0, 1),
                            minHeight: 8,
                            color: MP.green,
                            backgroundColor: MP.soft,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${o.issued} ${tr('emitidos')} · ${o.used} ${tr('usados · limite')} ${o.limit} · ${tr('até')} ${fmtDate(o.until)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MP.s3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferStatus extends StatelessWidget {
  const _OfferStatus(this.s);
  final String s;
  @override
  Widget build(BuildContext context) => switch (s) {
    'Ativa' => MpBadge(tr('Ativa'), fg: MP.success),
    'Pausada' => MpBadge(tr('Pausada'), fg: MP.warning, bg: MP.warningBg),
    'Em análise' => MpBadge(tr('Em análise'), fg: MP.info),
    _ => MpBadge(s, fg: MP.textSecondary),
  };
}

/// MP-P02.1 · Gestão da oferta: pausar com motivo, retomar, histórico.
class OfferManageScreen extends ConsumerWidget {
  const OfferManageScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final o = s.partnerOffers.firstWhere((e) => e.id == id);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(o.title, subtitle: o.benefit),
            if (s.online)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SaleOfferForm(offerId: o.id, existing: o.saleTerms),
                  ),
                ),
                child: Text(tr('Configurar preço, desconto e pagamento')),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _OfferStatus(o.status),
                  ),
                  SizedBox(height: MP.s3),
                  MpInfoRow(Icons.rule_rounded, o.rules),
                  MpInfoRow(
                    Icons.confirmation_number_rounded,
                    '${tr('Limite total')}: ${o.limit}',
                  ),
                  MpInfoRow(
                    Icons.event_busy_rounded,
                    '${tr('Válida até')} ${fmtDate(o.until)}',
                  ),
                  if (o.pauseReason != null)
                    MpInfoRow(
                      Icons.pause_circle_rounded,
                      '${tr('Pausada')}: ${o.pauseReason}',
                    ),
                  SizedBox(height: MP.s4),
                  _OfferPhoto(offerId: o.id, imageUrl: o.imageUrl),
                  if (o.status == 'Ativa') ...[
                    SizedBox(height: MP.s4),
                    OfferQrCard(cupomId: 'po:${o.id}', title: o.title),
                  ],
                  SizedBox(height: MP.s4),
                  Row(
                    children: [
                      Expanded(child: _Kpi(tr('Emitidos'), '${o.issued}')),
                      SizedBox(width: MP.s3),
                      Expanded(
                        child: _Kpi(tr('Usados'), '${o.used}', color: MP.navy),
                      ),
                    ],
                  ),
                  SizedBox(height: MP.s5),
                  if (o.status == 'Ativa')
                    OutlinedButton.icon(
                      key: Key('offer-pause'),
                      onPressed: () async {
                        const reasons = [
                          'Sem disponibilidade',
                          'Mudança de preço',
                          'Clima ou temporada',
                          'Reforma ou manutenção',
                          'Outro motivo',
                        ];
                        final r = await showModalBottomSheet<String>(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    MP.pageH,
                                    0,
                                    MP.pageH,
                                    MP.s2,
                                  ),
                                  child: Text(
                                    tr('Por que pausar?'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                for (final x in reasons)
                                  ListTile(
                                    minTileHeight: 60,
                                    title: Text(
                                      tr(x),
                                      style: const TextStyle(fontSize: 17),
                                    ),
                                    onTap: () => Navigator.of(context).pop(x),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (r != null) {
                          try {
                            await s.setOfferStatusAsync(
                              o.id,
                              tr('Pausada'),
                              reason: r,
                            );
                            if (context.mounted) {
                              showMpSnack(
                                context,
                                tr('Oferta pausada. Turistas não veem mais o cupom.'),
                              );
                            }
                          } on MvpException catch (e) {
                            if (context.mounted) {
                              showMpSnack(context, e.message);
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.pause_rounded),
                      label: Text(tr('Pausar oferta')),
                    ),
                  if (o.status == 'Pausada')
                    FilledButton.icon(
                      key: const Key('offer-resume'),
                      onPressed: () async {
                        try {
                          await s.setOfferStatusAsync(o.id, tr('Ativa'));
                          if (context.mounted) {
                            showMpSnack(context, tr('Oferta ativa de novo.'));
                          }
                        } on MvpException catch (e) {
                          if (context.mounted) showMpSnack(context, e.message);
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(tr('Retomar oferta')),
                    ),
                  if (o.status == 'Em análise') ...[
                    MpNotice(
                      tr('A equipe MaraPass confere a oferta antes de publicar. Você recebe um aviso.'),
                    ),
                    if (s.online) ...[
                      const SizedBox(height: MP.s3),
                      FilledButton.icon(
                        key: const Key('offer-approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MP.green,
                        ),
                        onPressed: () async {
                          try {
                            await s.setOfferStatusAsync(o.id, tr('Ativa'));
                            if (context.mounted) {
                              showMpSnack(
                                context,
                                tr('Oferta publicada. Os turistas já podem ativar.'),
                              );
                            }
                          } on MvpException catch (e) {
                            if (context.mounted) {
                              showMpSnack(context, e.message);
                            }
                          }
                        },
                        icon: const Icon(Icons.verified_rounded),
                        label: Text(tr('Aprovar (demonstração)')),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
