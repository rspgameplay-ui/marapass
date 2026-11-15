import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/models.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';
import 'offer_screens.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});
  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  int _tab = 0; // 0 disponíveis, 1 usados, 2 expirados

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cupons')),
        body: MpEmpty(
          icon: Icons.local_activity_outlined,
          title: 'Entre para ver seus cupons',
          message: 'Seus cupons ativos, usados e vencidos ficam guardados na sua conta.',
          actionLabel: 'Entrar',
          onAction: () => requireLogin(
            context,
            ref,
            reason: 'Entre para ver e usar seus cupons.',
          ),
        ),
      );
    }
    final async = ref.watch(myCouponsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cupons')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
            child: SegmentedButton<int>(
              key: const Key('coupon-segments'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Disponíveis')),
                ButtonSegment(value: 1, label: Text('Usados')),
                ButtonSegment(value: 2, label: Text('Expirados')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: MP.green,
                selectedForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(MP.minTap),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const MpLoading(),
              error: (e, _) => MpError(
                message: '$e',
                onRetry: () => ref.invalidate(myCouponsProvider),
              ),
              data: (all) {
                final list = all.where((c) {
                  return switch (_tab) {
                    0 => c.isActive,
                    1 => c.isRedeemed,
                    _ => c.isExpired,
                  };
                }).toList();
                if (list.isEmpty) {
                  return MpEmpty(
                    icon: Icons.local_activity_outlined,
                    title: switch (_tab) {
                      0 => 'Nenhum cupom ativo',
                      1 => 'Nenhum cupom usado',
                      _ => 'Nenhum cupom expirado',
                    },
                    message: _tab == 0
                        ? 'Ative uma oferta na aba Explorar e ela aparece aqui.'
                        : 'Quando isso acontecer, o histórico aparece aqui.',
                    actionLabel: _tab == 0 ? 'Ver ofertas' : null,
                    onAction: _tab == 0
                        ? () => ref.read(shellTabProvider.notifier).go(1)
                        : null,
                  );
                }
                return RefreshIndicator(
                  color: MP.green,
                  onRefresh: () async {
                    ref.invalidate(myCouponsProvider);
                    await ref.read(myCouponsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      MP.pageH,
                      0,
                      MP.pageH,
                      MP.s8,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: MP.s3),
                    itemBuilder: (_, i) => _CouponTile(coupon: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.coupon});
  final CouponInstance coupon;
  @override
  Widget build(BuildContext context) {
    final c = coupon;
    return MpCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CouponActiveScreen(coupon: c)),
      ),
      semanticLabel: '${c.title}, ${c.benefitLabel}',
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (c.isActive ? MP.gold : MP.textMuted).withValues(
                alpha: .15,
              ),
              borderRadius: BorderRadius.circular(MP.rMedium),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              color: c.isActive ? MP.gold : MP.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  c.expiresAt == null
                      ? c.benefitLabel
                      : '${c.benefitLabel} · até ${formatDate(c.expiresAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: MP.textMuted),
        ],
      ),
    );
  }
}
