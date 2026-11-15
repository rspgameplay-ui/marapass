import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';

/// Detalhe do passeio + solicitação de reserva (no MVP, reserva é pedido de
/// disponibilidade: o parceiro confirma depois).
class ExperienceDetailScreen extends ConsumerStatefulWidget {
  const ExperienceDetailScreen({super.key, required this.experience});
  final Experience experience;
  @override
  ConsumerState<ExperienceDetailScreen> createState() =>
      _ExperienceDetailState();
}

class _ExperienceDetailState extends ConsumerState<ExperienceDetailScreen> {
  Slot? _slot;
  int _people = 2;
  bool _busy = false;
  String? _error;

  /// Uma chave por tentativa de reserva: se a rede cair e o turista tocar de
  /// novo, o servidor reconhece o mesmo pedido e não duplica a reserva.
  late String _requestKey = const Uuid().v4();

  Future<void> _submit() async {
    final slot = _slot;
    if (slot == null) return;
    final ok = await requireLogin(
      context,
      ref,
      reason:
          'Entre para pedir a reserva. Você volta direto para este passeio.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(mvpRepositoryProvider)
          .requestReservation(
            slotId: slot.id,
            participants: _people,
            requestKey: _requestKey,
          );
      ref.invalidate(myReservationsProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReservationSentScreen(
            experience: widget.experience,
            slot: slot,
            people: _people,
          ),
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
    final x = widget.experience;
    final slots = ref.watch(slotsProvider(x.id));
    final meta = <String>[
      if (x.establishment?.name != null) x.establishment!.name,
      if (x.establishment?.city != null) x.establishment!.city!,
    ].join(' · ');
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
          MpPhoto(height: 200, seed: x.id.hashCode),
          const SizedBox(height: MP.s4),
          Text(x.title, style: Theme.of(context).textTheme.headlineSmall),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: MP.s1),
            Text(meta, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: MP.s3),
          Wrap(
            spacing: MP.s2,
            runSpacing: MP.s2,
            children: [
              if (x.durationMinutes != null)
                MpBadge(formatDuration(x.durationMinutes!), fg: MP.navy),
              if (x.priceFromCents != null)
                MpBadge(
                  'a partir de ${formatBrl(x.priceFromCents!)}',
                  fg: MP.green,
                ),
              if (x.capacity != null)
                MpBadge('até ${x.capacity} pessoas', fg: MP.textSecondary),
            ],
          ),
          if ((x.description ?? '').isNotEmpty) ...[
            const SizedBox(height: MP.s4),
            Text(x.description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: MP.sectionGap),
          const MpSectionTitle('Escolha o horário'),
          const SizedBox(height: MP.s3),
          slots.when(
            loading: () => const SizedBox(height: 80, child: MpLoading()),
            error: (e, _) => MpError(
              message: '$e',
              onRetry: () => ref.invalidate(slotsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const MpCard(
                  color: MP.subtle,
                  child: Text(
                    'Este passeio ainda não tem horários abertos. Volte em breve.',
                    style: TextStyle(color: MP.textSecondary),
                  ),
                );
              }
              return Wrap(
                spacing: MP.s2,
                runSpacing: MP.s2,
                children: [
                  for (final s in list)
                    ChoiceChip(
                      key: Key('slot-${s.id}'),
                      label: Text(
                        '${formatDay(s.startsAt)} · ${formatTime(s.startsAt)}',
                      ),
                      selected: _slot?.id == s.id,
                      selectedColor: MP.green,
                      labelStyle: TextStyle(
                        color: _slot?.id == s.id ? Colors.white : MP.navy,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() {
                        _slot = s;
                        _error = null;
                        // Horário novo = pedido novo.
                        _requestKey = const Uuid().v4();
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: MP.sectionGap),
          const MpSectionTitle('Quantas pessoas?'),
          const SizedBox(height: MP.s3),
          Row(
            children: [
              IconButton.outlined(
                key: const Key('people-minus'),
                tooltip: 'Menos uma pessoa',
                onPressed: _people > 1 ? () => setState(() => _people--) : null,
                icon: const Icon(Icons.remove),
                constraints: const BoxConstraints(
                  minWidth: MP.minTap,
                  minHeight: MP.minTap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MP.s5),
                child: Text(
                  '$_people',
                  key: const Key('people-count'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.outlined(
                key: const Key('people-plus'),
                tooltip: 'Mais uma pessoa',
                onPressed: _people < (x.capacity ?? 20)
                    ? () => setState(() => _people++)
                    : null,
                icon: const Icon(Icons.add),
                constraints: const BoxConstraints(
                  minWidth: MP.minTap,
                  minHeight: MP.minTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: MP.s5),
          MpCard(
            color: MP.infoBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: MP.info, size: 20),
                const SizedBox(width: MP.s2),
                Expanded(
                  child: Text(
                    'Você envia um pedido de disponibilidade. O parceiro confirma e avisa você. Nenhum pagamento é feito agora.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: MP.info),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: MP.s3),
            Text(
              _error!,
              style: const TextStyle(
                color: MP.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: MP.s4),
          MpPrimaryButton(
            key: const Key('reserve-submit'),
            label: _slot == null ? 'Escolha um horário' : 'Solicitar reserva',
            busy: _busy,
            onPressed: _slot == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// MP-T18.1 · Solicitação enviada.
class ReservationSentScreen extends ConsumerWidget {
  const ReservationSentScreen({
    super.key,
    required this.experience,
    required this.slot,
    required this.people,
  });
  final Experience experience;
  final Slot slot;
  final int people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MP.pageH),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: MP.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: MP.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: MP.s5),
              Text(
                'Solicitação enviada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: MP.s2),
              Text(
                'O parceiro vai confirmar a sua reserva. Você acompanha o andamento em Perfil, Minhas reservas.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: MP.textSecondary),
              ),
              const SizedBox(height: MP.s5),
              MpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MP.s2),
                    Text(
                      '${formatDay(slot.startsAt)} às ${formatTime(slot.startsAt)} · $people ${people == 1 ? 'pessoa' : 'pessoas'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: MP.s2),
                    const MpBadge('Aguardando confirmação', fg: MP.warning),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('sent-home'),
                onPressed: () {
                  ref.read(shellTabProvider.notifier).go(0);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
