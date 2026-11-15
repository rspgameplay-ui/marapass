import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';

/// MP-T16 · Passaporte. No MVP o pedido é registrado e a confirmação do
/// pagamento é feita pelo servidor (gateway ainda não ligado); o app não finge cobrança.
class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});
  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen> {
  /// Uma chave por produto: repetir o toque reaproveita o mesmo pedido.
  final Map<String, String> _keys = {};
  String? _busyId;

  Future<void> _buy(PassportProduct p) async {
    final ok = await requireLogin(
      context,
      ref,
      reason: 'Entre para pedir o seu passaporte.',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = p.id);
    try {
      final key = _keys.putIfAbsent(p.id, () => const Uuid().v4());
      await ref
          .read(mvpRepositoryProvider)
          .prepareOrder(productId: p.id, requestKey: key);
      ref.invalidate(myEntitlementsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pedido registrado'),
          content: const Text(
            'Seu pedido do passaporte foi registrado. A confirmação do pagamento ainda não está disponível no aplicativo: assim que for liberada, você recebe o aviso e o passaporte aparece aqui.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _activate(PassportEntitlement e) async {
    setState(() => _busyId = e.id);
    try {
      await ref.read(mvpRepositoryProvider).activatePassport(e.id);
      ref.invalidate(myEntitlementsProvider);
      if (mounted) showMpSnack(context, 'Passaporte ativado');
    } on MvpException catch (err) {
      if (mounted) showMpSnack(context, err.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final products = ref.watch(passportProductsProvider);
    final mine = ref.watch(myEntitlementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Passaporte')),
      body: RefreshIndicator(
        color: MP.green,
        onRefresh: () async {
          ref.invalidate(passportProductsProvider);
          ref.invalidate(myEntitlementsProvider);
          await ref.read(passportProductsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s8),
          children: [
            if (user != null)
              mine.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MpSectionTitle('Meus passaportes'),
                          const SizedBox(height: MP.s3),
                          for (final e in list) ...[
                            _EntitlementCard(
                              entitlement: e,
                              busy: _busyId == e.id,
                              onActivate: () => _activate(e),
                            ),
                            const SizedBox(height: MP.s3),
                          ],
                          const SizedBox(height: MP.s3),
                        ],
                      ),
              ),
            const MpSectionTitle('Passaportes disponíveis'),
            const SizedBox(height: MP.s3),
            products.when(
              loading: () => const SizedBox(height: 120, child: MpLoading()),
              error: (e, _) => MpError(
                message: '$e',
                onRetry: () => ref.invalidate(passportProductsProvider),
              ),
              data: (list) => list.isEmpty
                  ? const MpEmpty(
                      icon: Icons.verified_outlined,
                      title: 'Passaporte em preparação',
                      message: 'Assim que o primeiro passaporte for publicado, ele aparece aqui.',
                    )
                  : Column(
                      children: [
                        for (final p in list) ...[
                          _ProductCard(
                            product: p,
                            busy: _busyId == p.id,
                            onBuy: () => _buy(p),
                          ),
                          const SizedBox(height: MP.s3),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.busy,
    required this.onBuy,
  });
  final PassportProduct product;
  final bool busy;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    final p = product;
    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: MP.gold),
              const SizedBox(width: MP.s2),
              Expanded(
                child: Text(
                  p.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if ((p.description ?? '').isNotEmpty) ...[
            const SizedBox(height: MP.s2),
            Text(p.description!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if ((p.benefitsExplanation ?? '').isNotEmpty) ...[
            const SizedBox(height: MP.s2),
            Text(
              p.benefitsExplanation!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: MP.s3),
          Wrap(
            spacing: MP.s2,
            children: [
              MpBadge(formatBrl(p.priceCents), fg: MP.green),
              if (p.durationDays != null)
                MpBadge('${p.durationDays} dias', fg: MP.navy),
            ],
          ),
          const SizedBox(height: MP.s4),
          MpPrimaryButton(
            key: Key('buy-${p.id}'),
            label: 'Quero este passaporte',
            busy: busy,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({
    required this.entitlement,
    required this.busy,
    required this.onActivate,
  });
  final PassportEntitlement entitlement;
  final bool busy;
  final VoidCallback onActivate;
  @override
  Widget build(BuildContext context) {
    final e = entitlement;
    return MpCard(
      color: MP.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: MP.gold),
              const SizedBox(width: MP.s2),
              const Expanded(
                child: Text(
                  'Passaporte MaraPass',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              MpBadge(
                e.isActivated ? 'Ativo' : 'Aguardando ativação',
                fg: e.isActivated ? MP.success : MP.gold,
                bg: Colors.white,
              ),
            ],
          ),
          if (e.validUntil != null) ...[
            const SizedBox(height: MP.s2),
            Text(
              'Válido até ${formatDate(e.validUntil!)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (!e.isActivated) ...[
            const SizedBox(height: MP.s3),
            FilledButton(
              onPressed: busy ? null : onActivate,
              style: FilledButton.styleFrom(
                backgroundColor: MP.gold,
                foregroundColor: MP.navy,
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Ativar agora'),
            ),
          ],
        ],
      ),
    );
  }
}
