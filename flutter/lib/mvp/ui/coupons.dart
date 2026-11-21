import 'dart:async';

import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/repository.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'login_screen.dart';
import 'coupon_commerce.dart';
import '../data/coupon_commerce.dart';

/// Carteira de cupons (MP-T09): ofertas para ativar e os seus cupons em
/// Disponíveis, Usados e Expirados, no formato de ingresso.
class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});
  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  // 0 Disponíveis (meus ativos + ofertas para ativar), 1 Usados, 2 Expirados (pelo menu).
  int _tab = 0;
  Cat? _cat;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final mine = store.coupons
        .where((c) => c.cupom != null && (_cat == null || c.cupom?.cat == _cat))
        .toList();
    final activeIds = {
      for (final c in store.coupons.where((c) => c.active)) c.cupomId,
    };
    final offers =
        Content.allCupons
            .where(
              (c) =>
                  (store.remote == null || c.id.startsWith('po:')) &&
                  !activeIds.contains(c.id) &&
                  c.validade.isAfter(DateTime.now()) &&
                  (_cat == null || c.cat == _cat),
            )
            .toList()
          ..sort((a, b) => a.validade.compareTo(b.validade));
    final active = mine.where((c) => c.active).toList();
    final used = mine.where((c) => c.used || c.closed).toList();
    final expired = mine.where((c) => c.expired).toList();
    final cats = {for (final c in Content.allCupons) c.cat}.toList();

    Widget ticket(LocalCoupon c) => Padding(
      padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
      child: TicketCard(
        cupom: c.cupom!,
        status: c.expired
            ? tr('Expirado')
            : c.sale != null
            ? (couponStates[c.stage] ?? tr('Emitido'))
            : c.used
            ? tr('Utilizado')
            : tr('Ativado'),
        statusColor: c.used
            ? MP.textSecondary
            : (c.expired ? MP.warning : MP.success),
        code: c.active ? c.code : null,
        onQr: c.active
            ? () => push<void>(context, CouponActiveScreen(couponId: c.id))
            : null,
        onTap: () => push<void>(context, CouponActiveScreen(couponId: c.id)),
      ),
    );

    return ColoredBox(
      color: MP.soft,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          MpHero(
            title: tr('Cupons'),
            subtitle: tr('Descontos em parceiros MaraPass.'),
            trailing: PopupMenuButton<Object>(
              key: const Key('coupon-menu'),
              tooltip: tr('Filtrar por categoria'),
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 28),
              onSelected: (v) => setState(() {
                if (v == 'all') {
                  _cat = null;
                } else if (v is Cat) {
                  _cat = v;
                }
              }),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'all',
                  checked: _cat == null,
                  child: Text(tr('Todas as categorias')),
                ),
                for (final c in cats)
                  CheckedPopupMenuItem(
                    value: c,
                    checked: _cat == c,
                    child: Text(c.label),
                  ),
              ],
            ),
            child: WalletSummary(store: store, flat: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s4, MP.pageH, 0),
            child: SegmentedButton<int>(
              key: const Key('coupon-segments'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text('${tr('Disponíveis')} (${active.length + offers.length})'),
                ),
                ButtonSegment(value: 1, label: Text('${tr('Histórico')} (${used.length + expired.length})')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
              style: SegmentedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                selectedBackgroundColor: MP.navy,
                selectedForegroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: mpFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (_cat != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(_cat!.label),
                  onDeleted: () => setState(() => _cat = null),
                ),
              ),
            ),
          const SizedBox(height: MP.s4),
          if (store.remote != null)
            for (final c in store.coupons.where(
              (c) =>
                  c.sale == null &&
                  c.cupom == null &&
                  (_tab == 1 ? c.used : !c.used),
            ))
              ListTile(
                title: Text(tr('Cupom anterior')),
                subtitle: Text(c.code),
                onTap: () =>
                    push<void>(context, CouponActiveScreen(couponId: c.id)),
              ),
          if (_tab == 1) ...[
            if (used.isEmpty && expired.isEmpty)
              MpEmpty(
                icon: Icons.confirmation_number_outlined,
                title: tr('Nenhum cupom no histórico'),
                message: tr('Cupons usados ou vencidos aparecem aqui.'),
              ),
            for (final c in used) ticket(c),
            for (final c in expired) ticket(c),
          ] else ...[
            if (active.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: MpSectionTitle(tr('Meus cupons ativos')),
              ),
              for (final c in active) ticket(c),
              const SizedBox(height: MP.s3),
            ],
            if (offers.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: MpSectionTitle(tr('Para ativar')),
              ),
            for (final c in offers)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: TicketCard(
                  cupom: c,
                  status: tr('Disponível'),
                  statusColor: MP.info,
                  onTap: () =>
                      push<void>(context, CouponDetailScreen(cupom: c)),
                ),
              ),
            if (active.isEmpty && offers.isEmpty)
              MpEmpty(
                icon: Icons.local_activity_outlined,
                title: tr('Nenhum cupom agora'),
                message: tr('Novas ofertas dos parceiros aparecem aqui.'),
              ),
          ],
        ],
      ),
    );
  }
}

class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.cupom});
  final Cupom cupom;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final active = store.activeCouponFor(cupom.id);
    final item = Content.item(cupom.itemId);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          MpPhoto(
            photo: cupom.foto,
            height: 240,
            radius: 0,
            darken: true,
            icon: cupom.cat.icon,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(MP.pageH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MpBackPill(onDark: true),
                    const Spacer(),
                    MpBadge(cupom.cat.label, fg: MP.ink, bg: Colors.white),
                    const SizedBox(height: 6),
                    Text(
                      cupom.beneficio,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  cupom.parceiro,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MP.s2),
                Text(
                  cupom.detalhe,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: MP.s3),
                MpInfoRow(
                  Icons.event_busy_rounded,
                  '${tr('Válido até')} ${fmtDate(cupom.validade)}',
                ),
                if (!cupom.id.startsWith('po:'))
                  MpInfoRow(Icons.person_rounded, tr('Um cupom por pessoa')),
                MpInfoRow(
                  Icons.qr_code_2_rounded,
                  tr('Mostre o QR ao atendente na hora de pagar'),
                ),
                if (item != null)
                  MpInfoRow(
                    Icons.place_rounded,
                    '${item.titulo} · ${item.cidade}',
                    onTap: () => openItem(context, item),
                  ),
                const SizedBox(height: MP.s4),
                if (!cupom.id.startsWith('po:'))
                  MpNotice.demo(
                    tr('Oferta de demonstração: não indica parceria comercial nesta versão de teste.'),
                  ),
                const SizedBox(height: MP.s5),
                if (active != null)
                  FilledButton(
                    key: const Key('coupon-open-active'),
                    onPressed: () => push<void>(
                      context,
                      CouponActiveScreen(couponId: active.id),
                    ),
                    child: Text(tr('Ver meu cupom ativo')),
                  )
                else if (store.remote == null || cupom.id.startsWith('po:'))
                  MpCtaButton(
                    key: const Key('coupon-activate'),
                    label: tr('Ativar cupom'),
                    onPressed: () async {
                      final ok = await requireLogin(
                        context,
                        ref,
                        reason: tr('Entre para ativar o cupom. Você volta direto para esta oferta.'),
                      );
                      if (!ok || !context.mounted) return;
                      await push<void>(
                        context,
                        CouponReviewScreen(cupom: cupom),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// MP-COUPON-002 · Revisar ativação.
class CouponReviewScreen extends ConsumerStatefulWidget {
  const CouponReviewScreen({super.key, required this.cupom});
  final Cupom cupom;
  @override
  ConsumerState<CouponReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<CouponReviewScreen> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    // Ativação idempotente: tocar de novo devolve o mesmo cupom (garantido no banco).
    final LocalCoupon c;
    try {
      c = await ref.read(appStoreProvider).activateCouponAsync(widget.cupom.id);
    } on MvpException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMpSnack(context, e.message);
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CouponActiveScreen(couponId: c.id, justActivated: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cupom;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(
              tr('Revisar ativação'),
              subtitle: tr('Confira antes de ativar.'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TicketCard(cupom: c, onTap: () {}),
                  const SizedBox(height: MP.s4),
                  MpNotice(
                    tr('O cupom é pessoal e o QR não pode ser compartilhado. Ele vale uma única vez e o atendente confere na hora.'),
                    icon: Icons.lock_outline_rounded,
                    fg: MP.warning,
                    bg: MP.warningBg,
                  ),
                  const SizedBox(height: MP.s3),
                  Text(
                    tr('Ao ativar, você aceita as condições desta oferta.'),
                    key: Key('review-terms'),
                    style: TextStyle(fontSize: 15, color: MP.textSecondary),
                  ),
                  const SizedBox(height: MP.s4),
                  MpPrimaryButton(
                    key: const Key('review-confirm'),
                    label: tr('Confirmar ativação'),
                    busy: _busy,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MP-T12 · Cupom ativo com QR que se renova a cada 30 segundos.
class CouponActiveScreen extends ConsumerStatefulWidget {
  const CouponActiveScreen({
    super.key,
    required this.couponId,
    this.justActivated = false,
  });
  final String couponId;
  final bool justActivated;
  @override
  ConsumerState<CouponActiveScreen> createState() => _ActiveState();
}

class _ActiveState extends ConsumerState<CouponActiveScreen> {
  bool _revealed = false;
  int _left = 30;
  int _round = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _left--;
        if (_left <= 0) {
          _left = 30;
          _round++;
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final c = store.coupons.where((e) => e.id == widget.couponId).firstOrNull;
    if (c != null && store.remote != null && c.sale == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Cupom anterior'))),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '${tr('Cupom')} ${c.code} ${tr('emitido em')} ${fmtDate(c.issuedAt)}. ${tr('Para conferir as condições originais, procure o atendimento MaraPass')}.',
          ),
        ),
      );
    }
    if (c == null || c.cupom == null) {
      return Scaffold(
        body: Center(child: Text(tr('Cupom indisponível nesta conta.'))),
      );
    }
    if (c.sale != null) return CouponReceipt(code: c.code, scope: 'tourist');
    final cupom = c.cupom!;
    final (label, fg, bg) = c.used
        ? (tr('Utilizado'), MP.textSecondary, MP.soft)
        : c.expired
        ? (tr('Expirado'), MP.warning, MP.warningBg)
        : (tr('Ativado'), MP.success, MP.successBg);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(
              tr('Seu cupom'),
              subtitle: widget.justActivated
                  ? tr('Cupom ativado com sucesso!')
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: MpCard(
                padding: const EdgeInsets.all(MP.s5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cupom.parceiro,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        MpBadge(label, fg: fg, bg: bg),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cupom.beneficio,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MP.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: MP.s4),
                    Opacity(
                      opacity: c.active ? 1 : .2,
                      child: Semantics(
                        label: tr('QR Code do cupom'),
                        child: QrImageView(
                          data: 'marapass:coupon:${c.code}:$_round',
                          size: 240,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: MP.ink,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: MP.ink,
                          ),
                        ),
                      ),
                    ),
                    if (c.active) ...[
                      const SizedBox(height: MP.s2),
                      Text(
                        '${tr('O QR se renova em')} $_left s',
                        style: const TextStyle(
                          fontSize: 15,
                          color: MP.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MP.s4),
                      InkWell(
                        key: const Key('coupon-reveal'),
                        onTap: () => setState(() => _revealed = !_revealed),
                        borderRadius: BorderRadius.circular(MP.rMedium),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: MP.s4),
                          decoration: BoxDecoration(
                            color: MP.soft,
                            borderRadius: BorderRadius.circular(MP.rMedium),
                          ),
                          child: Text(
                            _revealed ? c.code : tr('Toque para ver o código'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _revealed ? 30 : 17,
                              letterSpacing: _revealed ? 4 : 0,
                              fontWeight: FontWeight.w800,
                              color: MP.ink,
                            ),
                          ),
                        ),
                      ),
                      if (_revealed)
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: c.code),
                            );
                            if (context.mounted) {
                              showMpSnack(context, tr('Código copiado'));
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(tr('Copiar código')),
                        ),
                    ],
                    const SizedBox(height: MP.s2),
                    Text(
                      '${tr('Válido até')} ${fmtDate(cupom.validade)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MP.s4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Text(
                c.active
                    ? tr('Mostre este QR ao atendente do parceiro. Ele vale uma única vez.')
                    : c.used
                    ? '${tr('Este cupom foi usado em')} ${fmtDate(c.usedAt!)}.'
                    : tr('Este cupom venceu. Procure uma oferta nova em Cupons.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: MP.s4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Histórico deste cupom'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MP.s2),
                  MpInfoRow(
                    Icons.bolt_rounded,
                    '${tr('Ativado em')} ${fmtDate(c.issuedAt)} ${tr('às')} ${fmtTime(c.issuedAt)}',
                  ),
                  if (c.used)
                    MpInfoRow(
                      Icons.check_circle_rounded,
                      '${tr('Usado em')} ${fmtDate(c.usedAt!)} ${tr('às')} ${fmtTime(c.usedAt!)}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Valor estimado de um cupom: valor fixo, ou percentual sobre o preço do
/// item, ou um valor médio de referência quando não há preço.
int couponValueCents(Cupom c) {
  if (c.valorCents != null) return c.valorCents!;
  final pct = RegExp(r'(\d+)\s*%').firstMatch(c.beneficio);
  final price = Content.item(c.itemId)?.precoCents;
  if (pct != null && price != null) {
    return price * int.parse(pct.group(1)!) ~/ 100;
  }
  final brl = RegExp(r'R\$\s*(\d+)').firstMatch(c.beneficio);
  if (brl != null) return int.parse(brl.group(1)!) * 100;
  return 1500;
}

/// Resumo da carteira de benefícios: economia acumulada, cupons ativos e
/// pontos do Passaporte, no formato de saldo de carteira digital.
class WalletSummary extends StatelessWidget {
  const WalletSummary({super.key, required this.store, this.flat = false});
  final AppStore store;

  /// Sem cartão próprio: para ficar dentro do topo colorido da tela.
  final bool flat;
  @override
  Widget build(BuildContext context) {
    final used = store.coupons.where((c) => c.used && c.cupom != null).toList();
    final active = store.coupons
        .where((c) => c.active && c.cupom != null)
        .toList();
    final saved = store.remote == null
        ? used.fold<int>(0, (a, c) => a + couponValueCents(c.cupom!))
        : store.commercialPoints.fold<int>(
            0,
            (sum, e) => sum + (e['paid_cents'] as int),
          );
    final potential = active.fold<int>(
      0,
      (a, c) => a + couponValueCents(c.cupom!),
    );
    return Container(
      key: const Key('wallet-summary'),
      padding: EdgeInsets.all(flat ? MP.s4 : MP.s5),
      decoration: flat
          ? BoxDecoration(
              color: const Color(0x1fffffff),
              borderRadius: BorderRadius.circular(MP.rXl),
              border: Border.all(color: const Color(0x33ffffff)),
            )
          : BoxDecoration(
              gradient: const LinearGradient(
                colors: [MP.navy, Color(0xff0f5a6e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(MP.rXl),
              boxShadow: MP.shadowFloat,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: MP.yellow, size: 22),
              SizedBox(width: MP.s2),
              Flexible(
                child: Text(
                  tr('Benefícios MaraPass'),
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: MP.s3),
          Text(
            formatBrl(saved),
            key: const Key('wallet-saved'),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1),
          ),
          Text(
            store.remote == null
                ? tr('economia estimada com cupons usados')
                : tr('valor pago com cupons, após estornos'),
            style: const TextStyle(color: MP.onDarkMuted, fontSize: 14),
          ),
          const SizedBox(height: MP.s4),
          Row(
            children: [
              _WalletMetric(value: '${active.length}', label: tr('cupons ativos')),
              _WalletMetric(value: '${used.length}', label: tr('usados')),
              _WalletMetric(
                value: '${store.points}',
                label: '${tr('pontos')} · ${store.stampedPolos.length} ${tr('carimbos')}',
              ),
            ],
          ),
          if (potential > 0) ...[
            const SizedBox(height: MP.s3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: MP.s3, vertical: MP.s2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(MP.rMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: MP.yellow, size: 18),
                  const SizedBox(width: MP.s2),
                  Expanded(
                    child: Text(
                      '${tr('Ainda pode economizar')} ${formatBrl(potential)} ${tr('com os cupons ativos')}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, maxLines: 2, style: const TextStyle(color: MP.onDarkMuted, fontSize: 13)),
      ],
    ),
  );
}
