import 'dart:async';

import 'package:flutter/material.dart';
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
        .where((c) => _cat == null || c.cupom?.cat == _cat)
        .toList();
    final activeIds = {
      for (final c in store.coupons.where((c) => !c.used)) c.cupomId,
    };
    final offers =
        Content.allCupons
            .where(
              (c) =>
                  !activeIds.contains(c.id) &&
                  c.validade.isAfter(DateTime.now()) &&
                  (_cat == null || c.cat == _cat),
            )
            .toList()
          ..sort((a, b) => a.validade.compareTo(b.validade));
    final active = mine.where((c) => c.active).toList();
    final used = mine.where((c) => c.used).toList();
    final expired = mine.where((c) => c.expired).toList();
    final cats = {for (final c in Content.allCupons) c.cat}.toList();

    Widget ticket(LocalCoupon c) => Padding(
      padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
      child: TicketCard(
        cupom: c.cupom!,
        status: c.used ? 'Utilizado' : (c.expired ? 'Expirado' : 'Ativado'),
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
            title: 'Cupons',
            subtitle: 'Descontos em parceiros MaraPass.',
            child: WalletSummary(store: store, flat: true),
            trailing: PopupMenuButton<Object>(
              key: const Key('coupon-menu'),
              tooltip: 'Mais opções',
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 28),
              onSelected: (v) => setState(() {
                if (v == 'expired') {
                  _tab = 2;
                } else if (v == 'all') {
                  _cat = null;
                } else if (v is Cat) {
                  _cat = v;
                }
              }),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'expired',
                  child: Text('Ver expirados (${expired.length})'),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'all',
                  checked: _cat == null,
                  child: const Text('Todas as categorias'),
                ),
                for (final c in cats)
                  CheckedPopupMenuItem(
                    value: c,
                    checked: _cat == c,
                    child: Text(c.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s4, MP.pageH, 0),
            child: SegmentedButton<int>(
              key: const Key('coupon-segments'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text('Disponíveis (${active.length + offers.length})'),
                ),
                ButtonSegment(value: 1, label: Text('Usados (${used.length})')),
              ],
              selected: {_tab == 2 ? 0 : _tab},
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
          if (_tab == 2) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Expirados',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tab = 0),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
            if (expired.isEmpty)
              const MpEmpty(
                icon: Icons.event_busy_rounded,
                title: 'Nenhum cupom expirado',
                message: 'Quando um cupom vencer, ele aparece aqui.',
              ),
            for (final c in expired) ticket(c),
          ] else if (_tab == 1) ...[
            if (used.isEmpty)
              const MpEmpty(
                icon: Icons.confirmation_number_outlined,
                title: 'Nenhum cupom usado',
                message: 'Quando você usar um cupom, ele aparece aqui.',
              ),
            for (final c in used) ticket(c),
          ] else ...[
            if (active.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: MpSectionTitle('Meus cupons ativos'),
              ),
              for (final c in active) ticket(c),
              const SizedBox(height: MP.s3),
            ],
            if (offers.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: MpSectionTitle('Para ativar'),
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
                  status: 'Disponível',
                  statusColor: MP.info,
                  onTap: () =>
                      push<void>(context, CouponDetailScreen(cupom: c)),
                ),
              ),
            if (active.isEmpty && offers.isEmpty)
              const MpEmpty(
                icon: Icons.local_activity_outlined,
                title: 'Nenhum cupom agora',
                message: 'Novas ofertas dos parceiros aparecem aqui.',
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
                  'Válido até ${fmtDate(cupom.validade)}',
                ),
                const MpInfoRow(Icons.person_rounded, 'Um cupom por pessoa'),
                const MpInfoRow(
                  Icons.qr_code_2_rounded,
                  'Mostre o QR ao atendente na hora de pagar',
                ),
                if (item != null)
                  MpInfoRow(
                    Icons.place_rounded,
                    '${item.titulo} · ${item.cidade}',
                    onTap: () => openItem(context, item),
                  ),
                const SizedBox(height: MP.s4),
                const MpNotice.demo(
                  'Oferta de demonstração: não indica parceria comercial nesta versão de teste.',
                ),
                const SizedBox(height: MP.s5),
                if (active != null)
                  FilledButton(
                    key: const Key('coupon-open-active'),
                    onPressed: () => push<void>(
                      context,
                      CouponActiveScreen(couponId: active.id),
                    ),
                    child: const Text('Ver meu cupom ativo'),
                  )
                else
                  MpCtaButton(
                    key: const Key('coupon-activate'),
                    label: 'Ativar cupom',
                    onPressed: () async {
                      final ok = await requireLogin(
                        context,
                        ref,
                        reason: 'Entre para ativar o cupom. Você volta direto para esta oferta.',
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
  bool _accepted = false;
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
            const MpHeader(
              'Revisar ativação',
              subtitle: 'Confira antes de ativar.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TicketCard(cupom: c, onTap: () {}),
                  const SizedBox(height: MP.s4),
                  const MpNotice(
                    'O cupom é pessoal e o QR não pode ser compartilhado. Ele vale uma única vez e o atendente confere na hora.',
                    icon: Icons.lock_outline_rounded,
                    fg: MP.warning,
                    bg: MP.warningBg,
                  ),
                  const SizedBox(height: MP.s3),
                  CheckboxListTile(
                    key: const Key('review-accept'),
                    value: _accepted,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _accepted = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: MP.green,
                    title: const Text(
                      'Li e aceito as condições desta oferta',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  MpPrimaryButton(
                    key: const Key('review-confirm'),
                    label: 'Confirmar ativação',
                    busy: _busy,
                    onPressed: _accepted ? _confirm : null,
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
    final c = store.coupons.firstWhere((e) => e.id == widget.couponId);
    final cupom = c.cupom!;
    final (label, fg, bg) = c.used
        ? ('Utilizado', MP.textSecondary, MP.soft)
        : c.expired
        ? ('Expirado', MP.warning, MP.warningBg)
        : ('Ativado', MP.success, MP.successBg);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(
              'Seu cupom',
              subtitle: widget.justActivated
                  ? 'Cupom ativado com sucesso!'
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
                        label: 'QR Code do cupom',
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
                        'O QR se renova em $_left s',
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
                            _revealed ? c.code : 'Toque para ver o código',
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
                            if (context.mounted)
                              showMpSnack(context, 'Código copiado');
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copiar código'),
                        ),
                    ],
                    const SizedBox(height: MP.s2),
                    Text(
                      'Válido até ${fmtDate(cupom.validade)}',
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
                    ? 'Mostre este QR ao atendente do parceiro. Ele vale uma única vez.'
                    : c.used
                    ? 'Este cupom foi usado em ${fmtDate(c.usedAt!)}.'
                    : 'Este cupom venceu. Procure uma oferta nova em Cupons.',
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
                    'Histórico deste cupom',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MP.s2),
                  MpInfoRow(
                    Icons.bolt_rounded,
                    'Ativado em ${fmtDate(c.issuedAt)} às ${fmtTime(c.issuedAt)}',
                  ),
                  if (c.used)
                    MpInfoRow(
                      Icons.check_circle_rounded,
                      'Usado em ${fmtDate(c.usedAt!)} às ${fmtTime(c.usedAt!)}',
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
    final active = store.coupons.where((c) => c.active && c.cupom != null).toList();
    final saved = used.fold<int>(0, (a, c) => a + couponValueCents(c.cupom!));
    final potential = active.fold<int>(0, (a, c) => a + couponValueCents(c.cupom!));
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
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: MP.yellow, size: 22),
              SizedBox(width: MP.s2),
              Flexible(
                child: Text(
                  'Benefícios MaraPass',
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
          const Text(
            'economia estimada com cupons usados',
            style: TextStyle(color: Color(0xffc9d6e3), fontSize: 14),
          ),
          const SizedBox(height: MP.s4),
          Row(
            children: [
              _WalletMetric(value: '${active.length}', label: 'cupons ativos'),
              _WalletMetric(value: '${used.length}', label: 'usados'),
              _WalletMetric(
                value: '${store.points}',
                label: 'pontos · ${store.stampedPolos.length} carimbos',
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
                      'Ainda pode economizar ${formatBrl(potential)} com os cupons ativos',
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
        Text(label, maxLines: 2, style: const TextStyle(color: Color(0xffc9d6e3), fontSize: 12.5)),
      ],
    ),
  );
}
