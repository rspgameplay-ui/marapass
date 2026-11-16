import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/content.dart';
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
  int _tab = 0; // 0 ofertas, 1 meus, 2 usados, 3 expirados
  Cat? _cat;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final mine = store.coupons;
    final activeIds = {for (final c in mine.where((c) => !c.used)) c.cupomId};
    final offers =
        Content.cupons
            .where(
              (c) =>
                  !activeIds.contains(c.id) &&
                  c.validade.isAfter(DateTime.now()) &&
                  (_cat == null || c.cat == _cat),
            )
            .toList()
          ..sort((a, b) => a.validade.compareTo(b.validade));
    final list = switch (_tab) {
      1 => mine.where((c) => c.active),
      2 => mine.where((c) => c.used),
      _ => mine.where((c) => c.expired),
    }.where((c) => _cat == null || c.cupom?.cat == _cat).toList();
    final cats = {for (final c in Content.cupons) c.cat}.toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          const MpHeader(
            'Cupons',
            back: false,
            subtitle: 'Descontos em parceiros MaraPass.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Ativos',
                    value: mine.where((c) => c.active).length,
                    color: MP.green,
                  ),
                ),
                const SizedBox(width: MP.s2),
                Expanded(
                  child: _Stat(
                    label: 'Usados',
                    value: mine.where((c) => c.used).length,
                    color: MP.navy,
                  ),
                ),
                const SizedBox(width: MP.s2),
                Expanded(
                  child: _Stat(
                    label: 'Para ativar',
                    value: offers.length,
                    color: const Color(0xffa87b00),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          FilterChips<int>(
            options: const [0, 1, 2, 3],
            selected: _tab,
            label: (v) =>
                const ['Para ativar', 'Meus cupons', 'Usados', 'Expirados'][v],
            onSelect: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: MP.s2),
          FilterChips<Cat?>(
            options: [null, ...cats],
            selected: _cat,
            label: (v) => v?.label ?? 'Todas as categorias',
            onSelect: (v) => setState(() => _cat = v),
          ),
          const SizedBox(height: MP.s4),
          if (_tab == 0) ...[
            if (offers.isEmpty)
              const MpEmpty(
                icon: Icons.local_activity_outlined,
                title: 'Você já ativou todas',
                message: 'Veja seus cupons em Meus cupons.',
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
                  onTap: () =>
                      push<void>(context, CouponDetailScreen(cupom: c)),
                ),
              ),
          ] else ...[
            if (list.isEmpty)
              MpEmpty(
                icon: Icons.confirmation_number_outlined,
                title: switch (_tab) {
                  1 => 'Nenhum cupom ativo',
                  2 => 'Nenhum cupom usado',
                  _ => 'Nenhum cupom expirado',
                },
                message: _tab == 1
                    ? 'Toque em Para ativar e escolha uma oferta.'
                    : 'Quando isso acontecer, aparece aqui.',
                actionLabel: _tab == 1 ? 'Ver ofertas' : null,
                onAction: _tab == 1 ? () => setState(() => _tab = 0) : null,
              ),
            for (final c in list)
              if (c.cupom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MP.pageH,
                    0,
                    MP.pageH,
                    MP.s3,
                  ),
                  child: TicketCard(
                    cupom: c.cupom!,
                    status: c.used
                        ? 'Usado'
                        : (c.expired ? 'Expirado' : 'Ativo'),
                    statusColor: c.used
                        ? MP.textSecondary
                        : (c.expired ? MP.warning : MP.success),
                    onTap: () =>
                        push<void>(context, CouponActiveScreen(couponId: c.id)),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: MP.s3),
    decoration: BoxDecoration(
      color: MP.soft,
      borderRadius: BorderRadius.circular(MP.rMedium),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MP.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// MP-T10 · Detalhe do cupom.
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
    await Future<void>.delayed(const Duration(milliseconds: 350));
    // Ativação idempotente: tocar duas vezes devolve o mesmo cupom.
    final c = ref.read(appStoreProvider).activateCoupon(widget.cupom.id);
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
        ? ('Usado', MP.textSecondary, MP.soft)
        : c.expired
        ? ('Expirado', MP.warning, MP.warningBg)
        : ('Ativo', MP.success, MP.successBg);
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
