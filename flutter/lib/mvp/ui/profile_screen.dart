import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';

/// MP-T21 · Perfil e configurações, com Minhas reservas e exclusão de conta
/// (exigência das lojas e da LGPD).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: user == null
          ? MpEmpty(
              icon: Icons.person_outline,
              title: 'Você está como visitante',
              message: 'Entre para pedir reservas, ativar cupons e guardar seu passaporte.',
              actionLabel: 'Entrar com e-mail',
              onAction: () => requireLogin(context, ref),
            )
          : _LoggedIn(user: user),
    );
  }
}

class _LoggedIn extends ConsumerStatefulWidget {
  const _LoggedIn({required this.user});
  final AuthUser user;
  @override
  ConsumerState<_LoggedIn> createState() => _LoggedInState();
}

class _LoggedInState extends ConsumerState<_LoggedIn> {
  bool _busy = false;

  Future<void> _editName(String? current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: current ?? ''),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await ref.read(mvpRepositoryProvider).updateDisplayName(name);
      ref.invalidate(profileProvider);
      if (mounted) showMpSnack(context, 'Nome salvo');
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(authGatewayProvider).signOut();
      if (mounted) Navigator.of(context).pop();
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir minha conta?'),
        content: const Text(
          'Seus dados pessoais, cupons e pedidos serão apagados e isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: MP.error,
              minimumSize: const Size(96, 44),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(mvpRepositoryProvider).deleteMyAccount();
      if (mounted) Navigator.of(context).pop();
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).asData?.value;
    final reservations = ref.watch(myReservationsProvider);
    final name = profile?.displayName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s8),
      children: [
        MpCard(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: MP.navy,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: MP.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (name == null || name.isEmpty) ? 'Sem nome' : name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      widget.user.email ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('edit-name'),
                tooltip: 'Editar nome',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editName(name),
              ),
            ],
          ),
        ),
        const SizedBox(height: MP.sectionGap),
        const MpSectionTitle('Minhas reservas'),
        const SizedBox(height: MP.s3),
        reservations.when(
          loading: () => const SizedBox(height: 80, child: MpLoading()),
          error: (e, _) => MpError(
            message: '$e',
            onRetry: () => ref.invalidate(myReservationsProvider),
          ),
          data: (list) => list.isEmpty
              ? const MpCard(
                  color: MP.subtle,
                  child: Text(
                    'Você ainda não pediu nenhuma reserva.',
                    style: TextStyle(color: MP.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (final r in list) ...[
                      _ReservationTile(reservation: r),
                      const SizedBox(height: MP.s3),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: MP.sectionGap),
        OutlinedButton.icon(
          key: const Key('sign-out'),
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
        const SizedBox(height: MP.s3),
        TextButton(
          key: const Key('delete-account'),
          onPressed: _busy ? null : _delete,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(MP.minTap),
          ),
          child: const Text(
            'Excluir minha conta',
            style: TextStyle(color: MP.error, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation});
  final Reservation reservation;
  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final (label, fg, bg) = switch (r.status) {
      'confirmed' => ('Confirmada', MP.success, MP.successBg),
      'declined' ||
      'rejected' ||
      'cancelled' => ('Não confirmada', MP.textSecondary, MP.subtle),
      _ => ('Aguardando', MP.warning, MP.warningBg),
    };
    return MpCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.experienceTitle ?? 'Passeio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDay(r.scheduledAt)} às ${formatTime(r.scheduledAt)} · ${r.participants} ${r.participants == 1 ? 'pessoa' : 'pessoas'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          MpBadge(label, fg: fg, bg: bg),
        ],
      ),
    );
  }
}

/// Diálogo que é dono do próprio controller: o campo continua sendo desenhado
/// durante a animação de fechamento, então o controller só morre com o diálogo.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Como podemos chamar você?'),
    content: TextField(
      key: const Key('name-field'),
      controller: _ctrl,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Nome'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('name-save'),
        onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
        style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
        child: const Text('Salvar'),
      ),
    ],
  );
}
