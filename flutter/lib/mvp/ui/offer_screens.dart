import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';

/// Ficha da oferta (MP-T10). Visitante lê tudo; a conta só é pedida ao ativar.
class OfferDetailScreen extends ConsumerWidget {
  const OfferDetailScreen({super.key, required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = offer;
    final rules = <(IconData, String)>[
      if (o.minimumPurchaseCents != null && o.minimumPurchaseCents! > 0)
        (
          Icons.shopping_bag_outlined,
          'Compra mínima de ${formatBrl(o.minimumPurchaseCents!)}',
        ),
      if (o.maximumDiscountCents != null && o.maximumDiscountCents! > 0)
        (
          Icons.vertical_align_top_rounded,
          'Desconto máximo de ${formatBrl(o.maximumDiscountCents!)}',
        ),
      if (o.perUserLimit != null)
        (Icons.person_outline, 'Limite de ${o.perUserLimit} por pessoa'),
      if (o.endsAt != null)
        (Icons.event_outlined, 'Oferta até ${formatDate(o.endsAt!)}'),
      if (o.useUntil != null)
        (Icons.timer_outlined, 'Usar até ${formatDate(o.useUntil!)}'),
      if (o.advanceBookingRequired)
        (Icons.calendar_month_outlined, 'Exige reserva antecipada'),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s8),
        children: [
          Container(
            padding: const EdgeInsets.all(MP.s5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [MP.navy, MP.green]),
              borderRadius: BorderRadius.circular(MP.rXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.local_activity_rounded,
                  color: MP.gold,
                  size: 36,
                ),
                const SizedBox(height: MP.s3),
                Text(
                  o.benefitLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: MP.s1),
                Text(
                  o.establishment?.name ?? 'Parceiro MaraPass',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          Text(o.title, style: Theme.of(context).textTheme.headlineSmall),
          if ((o.description ?? '').isNotEmpty) ...[
            const SizedBox(height: MP.s2),
            Text(o.description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: MP.sectionGap),
          const MpSectionTitle('Condições'),
          const SizedBox(height: MP.s3),
          MpCard(
            child: rules.isEmpty
                ? Text(
                    'Sem condições adicionais informadas pelo parceiro.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final r in rules)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(r.$1, size: 20, color: MP.navy),
                              const SizedBox(width: MP.s3),
                              Expanded(child: Text(r.$2)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if ((o.disclosureExtra ?? '').isNotEmpty) ...[
            const SizedBox(height: MP.s3),
            Text(
              o.disclosureExtra!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: MP.s5),
          FilledButton(
            key: const Key('offer-activate'),
            onPressed: () async {
              final ok = await requireLogin(
                context,
                ref,
                reason: 'Entre para ativar o cupom. Você volta direto para esta oferta.',
              );
              if (!ok || !context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReviewActivationScreen(offer: o),
                ),
              );
            },
            child: const Text('Ativar cupom'),
          ),
        ],
      ),
    );
  }
}

/// MP-COUPON-002 · Revisar ativação. A chave de idempotência nasce uma vez
/// por tela: tocar de novo ou repetir depois de falha de rede reutiliza a mesma.
class ReviewActivationScreen extends ConsumerStatefulWidget {
  const ReviewActivationScreen({super.key, required this.offer});
  final Offer offer;
  @override
  ConsumerState<ReviewActivationScreen> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<ReviewActivationScreen> {
  final String _key = const Uuid().v4();
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(mvpRepositoryProvider)
          .issueCoupon(offerId: widget.offer.id, idempotencyKey: _key);
      ref.invalidate(myCouponsProvider);
      final list = await ref.read(myCouponsProvider.future);
      CouponInstance? coupon;
      for (final c in list) {
        if (c.id == id) coupon = c;
      }
      coupon ??= CouponInstance(
        id: id,
        offerId: widget.offer.id,
        status: 'issued',
        title: widget.offer.title,
        discountType: widget.offer.discountType,
        discountValue: widget.offer.discountValue,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CouponActiveScreen(coupon: coupon!),
        ),
      );
    } on MvpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar ativação')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s2, MP.pageH, MP.s8),
        children: [
          MpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MP.s1),
                Text(
                  o.establishment?.name ?? 'Parceiro MaraPass',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: MP.s3),
                MpBadge(o.benefitLabel, fg: MP.gold),
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          MpCard(
            color: MP.warningBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: MP.warning, size: 20),
                const SizedBox(width: MP.s2),
                Expanded(
                  child: Text(
                    'O cupom é pessoal e o QR não pode ser compartilhado. O parceiro confere os limites e a validade na hora do uso.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: MP.warning),
                  ),
                ),
              ],
            ),
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
            title: const Text('Li e aceito as condições desta oferta'),
          ),
          if (_error != null) ...[
            const SizedBox(height: MP.s2),
            Container(
              padding: const EdgeInsets.all(MP.s3),
              decoration: BoxDecoration(
                color: MP.errorBg,
                borderRadius: BorderRadius.circular(MP.rMedium),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: MP.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: MP.s4),
          MpPrimaryButton(
            key: const Key('review-confirm'),
            label: _error == null ? 'Confirmar ativação' : 'Tentar de novo',
            busy: _busy,
            onPressed: _accepted ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

/// MP-T12 · Cupom ativo. O QR carrega só o identificador da emissão; quem valida
/// é o servidor (uso único, atômico).
class CouponActiveScreen extends StatefulWidget {
  const CouponActiveScreen({super.key, required this.coupon});
  final CouponInstance coupon;
  @override
  State<CouponActiveScreen> createState() => _CouponActiveState();
}

class _CouponActiveState extends State<CouponActiveScreen> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    final code =
        c.displayCode ??
        c.id.substring(0, c.id.length.clamp(0, 8)).toUpperCase();
    final (label, fg, bg) = c.isRedeemed
        ? ('Usado', MP.textSecondary, MP.subtle)
        : c.isExpired
        ? ('Expirado', MP.warning, MP.warningBg)
        : ('Ativo', MP.success, MP.successBg);
    return Scaffold(
      appBar: AppBar(title: const Text('Seu cupom')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s2, MP.pageH, MP.s8),
        children: [
          MpCard(
            padding: const EdgeInsets.all(MP.s5),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    MpBadge(label, fg: fg, bg: bg),
                  ],
                ),
                const SizedBox(height: MP.s1),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    c.benefitLabel,
                    style: const TextStyle(
                      color: MP.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: MP.s5),
                Opacity(
                  opacity: c.isActive ? 1 : .25,
                  child: Semantics(
                    label: 'QR Code do cupom',
                    child: QrImageView(
                      data: 'marapass:coupon:${c.id}',
                      size: 220,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: MP.navy,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: MP.navy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MP.s4),
                if (c.isActive)
                  InkWell(
                    key: const Key('coupon-reveal'),
                    onTap: () => setState(() => _revealed = !_revealed),
                    borderRadius: BorderRadius.circular(MP.rMedium),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: MP.s3),
                      decoration: BoxDecoration(
                        color: MP.subtle,
                        borderRadius: BorderRadius.circular(MP.rMedium),
                      ),
                      child: Text(
                        _revealed ? code : 'Toque para ver o código',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _revealed ? 22 : 14,
                          letterSpacing: _revealed ? 3 : 0,
                          fontWeight: FontWeight.w800,
                          color: MP.navy,
                        ),
                      ),
                    ),
                  ),
                if (c.isActive && _revealed)
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        showMpSnack(context, 'Código copiado');
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar código'),
                  ),
                if (c.expiresAt != null) ...[
                  const SizedBox(height: MP.s2),
                  Text(
                    'Válido até ${formatDate(c.expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          Text(
            c.isActive
                ? 'Mostre este QR ao atendente do parceiro. Ele é válido uma única vez.'
                : c.isRedeemed
                ? 'Este cupom já foi usado${c.redeemedAt == null ? '' : ' em ${formatDate(c.redeemedAt!)}'}.'
                : 'Este cupom expirou. Procure uma oferta nova na aba Explorar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
