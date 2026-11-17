import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/content.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart';
import 'common.dart';
import 'login_screen.dart';
import 'partner.dart';
import 'partner_request.dart';
import 'services.dart';
import 'shell.dart' show Tabs;
import 'support.dart';

/// MP-T21 · Perfil e configurações.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context, AppStore store) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: store.name ?? ''),
    );
    if (name != null) store.setName(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final user = ref.watch(authProvider);
    final display = store.name ?? user?.email?.split('@').first ?? 'Visitante';
    final lv = store.level;
    final progress = lv.$4 == null
        ? 1.0
        : ((store.points - lv.$2) / (lv.$4! - lv.$2)).clamp(0.0, 1.0);
    final visited = {for (final c in store.checkins) c.itemId}.length;

    return Scaffold(
      backgroundColor: MP.soft,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Cabeçalho
          Container(
            padding: EdgeInsets.fromLTRB(
              MP.pageH,
              MediaQuery.paddingOf(context).top + MP.s3,
              MP.pageH,
              72,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [MP.navy, Color(0xff14507f)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MpBackPill(onDark: true),
                    const Spacer(),
                    IconButton(
                      key: const Key('edit-name'),
                      tooltip: 'Editar nome',
                      onPressed: () => _editName(context, store),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                        minimumSize: const Size(MP.minTap, MP.minTap),
                      ),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: MP.iconMd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MP.s5),
                Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: MP.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: MP.shadowFloat,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        display.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: MP.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: MP.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ??
                                'Visitante · entre para salvar sua viagem',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: MP.s2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MP.yellow,
                              borderRadius: BorderRadius.circular(MP.rPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: MP.ink,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${lv.$1} · ${store.points} pts',
                                  style: const TextStyle(
                                    color: MP.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Resumo do passaporte e métricas
          Transform.translate(
            offset: const Offset(0, -52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpCard(
                    onTap: () {
                      ref.read(shellTabProvider.notifier).go(Tabs.passaporte);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              color: MP.navy,
                              size: MP.iconMd,
                            ),
                            const SizedBox(width: MP.s2),
                            const Expanded(
                              child: Text(
                                'Meu passaporte',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: MP.ink,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                lv.$4 == null
                                    ? 'Nível máximo'
                                    : 'Próximo: ${lv.$3}',
                                style: const TextStyle(
                                  color: MP.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MP.s3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(MP.rPill),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            color: MP.green,
                            backgroundColor: MP.soft,
                          ),
                        ),
                        const SizedBox(height: MP.s2),
                        Text(
                          lv.$4 == null
                              ? 'Você completou todos os níveis.'
                              : 'Faltam ${lv.$4! - store.points} pontos',
                          style: const TextStyle(
                            color: MP.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          key: const Key('metric-visited'),
                          icon: Icons.place_rounded,
                          color: MP.green,
                          value: '$visited',
                          label: 'Lugares\nvisitados',
                        ),
                      ),
                      const SizedBox(width: MP.s2),
                      Expanded(
                        child: _Metric(
                          key: const Key('metric-routes'),
                          icon: Icons.route_rounded,
                          color: const Color(0xff1a73e8),
                          value: '${store.routesDone}',
                          label: 'Rotas\ntraçadas',
                        ),
                      ),
                      const SizedBox(width: MP.s2),
                      Expanded(
                        child: _Metric(
                          key: const Key('metric-stamps'),
                          icon: Icons.verified_rounded,
                          color: const Color(0xffa87800),
                          value:
                              '${store.stampedPolos.length}/${Content.polos.length}',
                          label: 'Carimbos\ndos polos',
                        ),
                      ),
                    ],
                  ),
                  if (user == null) ...[
                    const SizedBox(height: MP.s4),
                    MpCtaButton(
                      key: const Key('profile-login'),
                      label: 'Entrar com e-mail',
                      onPressed: () => requireLogin(context, ref),
                    ),
                  ],
                  const SizedBox(height: MP.s5),
                  _Group(
                    title: 'Minha viagem',
                    children: [
                      _Row(
                        icon: Icons.event_note_rounded,
                        color: const Color(0xff6a4fb3),
                        title: 'Minhas reservas',
                        subtitle: '${store.myReservations.length} reservas',
                        onTap: () =>
                            push<void>(context, const ReservationsScreen()),
                      ),
                      _Row(
                        icon: Icons.local_activity_rounded,
                        color: const Color(0xffa87800),
                        title: 'Meus cupons',
                        subtitle:
                            '${store.coupons.where((c) => c.active).length} ativos',
                        onTap: () {
                          ref.read(shellTabProvider.notifier).go(Tabs.cupons);
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                      _Row(
                        icon: Icons.photo_library_rounded,
                        color: const Color(0xffb0407e),
                        title: 'Minhas galerias',
                        subtitle: 'Fotos e álbum da viagem',
                        onTap: () =>
                            push<void>(context, const GalleriesScreen()),
                      ),
                      _Row(
                        icon: Icons.group_add_rounded,
                        color: MP.green,
                        title: 'Conexões MaraPass',
                        subtitle: 'Convide amigos e família',
                        onTap: () =>
                            push<void>(context, const ConnectionsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s4),
                  _Group(
                    title: 'Preferências',
                    children: [
                      _SwitchRow(
                        key: const Key('big-text'),
                        icon: Icons.text_increase_rounded,
                        title: 'Letra grande',
                        subtitle: 'Aumenta o texto do app inteiro',
                        value: store.bigText,
                        onChanged: store.setBigText,
                      ),
                      _SwitchRow(
                        key: const Key('offer-alerts'),
                        icon: Icons.notifications_active_rounded,
                        title: 'Avisos de ofertas',
                        subtitle: store.offerAlerts
                            ? 'Cupons novos e lembretes'
                            : 'Só lembretes de reserva',
                        value: store.offerAlerts,
                        onChanged: store.setOfferAlerts,
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s4),
                  _Group(
                    title: 'Ajuda',
                    children: [
                      _Row(
                        icon: Icons.support_agent_rounded,
                        color: MP.navy,
                        title: 'Atendimento',
                        subtitle: 'Conversas, suporte e sugestões',
                        onTap: () =>
                            push<void>(context, const SupportCenterScreen()),
                      ),
                      _Row(
                        icon: Icons.help_rounded,
                        color: MP.navy,
                        title: 'Perguntas frequentes',
                        onTap: () => push<void>(context, const HelpScreen()),
                      ),
                      _Row(
                        key: const Key('privacy'),
                        icon: Icons.privacy_tip_rounded,
                        color: MP.navy,
                        title: 'Política de privacidade',
                        onTap: () => openLegal(context, 'privacidade'),
                      ),
                      _Row(
                        key: const Key('terms'),
                        icon: Icons.gavel_rounded,
                        color: MP.navy,
                        title: 'Termos de uso',
                        onTap: () => openLegal(context, 'termos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s4),
                  _Group(
                    title: 'Para empresas',
                    children: [
                      _Row(
                        key: const Key('partner-area'),
                        icon: Icons.storefront_rounded,
                        color: MP.navy,
                        title: 'Área do parceiro',
                        subtitle: 'Cupons, validação e reservas',
                        onTap: () async {
                          final ok = await store.enterPartnerArea();
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ok
                                  ? const PartnerShell()
                                  : const PartnerRequestScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (user != null) ...[
                    const SizedBox(height: MP.s4),
                    _Group(
                      title: 'Conta',
                      children: [
                        _Row(
                          key: const Key('sign-out'),
                          icon: Icons.logout_rounded,
                          color: MP.textSecondary,
                          title: 'Sair da conta',
                          onTap: () async {
                            try {
                              await ref.read(authGatewayProvider).signOut();
                            } on MvpException catch (e) {
                              if (context.mounted)
                                showMpSnack(context, e.message);
                            }
                          },
                        ),
                        _Row(
                          key: const Key('delete-account'),
                          icon: Icons.delete_forever_rounded,
                          color: MP.error,
                          title: 'Excluir minha conta',
                          danger: true,
                          onTap: () => _delete(context, ref),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: MP.s5),
                  const Text(
                    'Versão de teste: parceiros, ofertas e preços são de demonstração.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MP.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir minha conta?'),
        content: const Text(
          'Seus dados pessoais, cupons e pedidos serão apagados. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: MP.error,
              minimumSize: const Size(120, 52),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(mvpRepositoryProvider).deleteMyAccount();
      await ref.read(authGatewayProvider).signOut();
      if (context.mounted) showMpSnack(context, 'Conta excluída.');
    } on MvpException catch (e) {
      if (context.mounted) showMpSnack(context, e.message);
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${label.replaceAll('\n', ' ')}: $value',
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: MP.s4, horizontal: MP.s3),
      decoration: BoxDecoration(
        color: MP.card,
        borderRadius: BorderRadius.circular(MP.rLarge),
        boxShadow: MP.shadowCard,
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: MP.iconMd),
            const SizedBox(height: MP.s2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: MP.ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: MP.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bloco de configurações: título + cartão com linhas separadas por divisor.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: MP.s1, bottom: MP.s2),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
            color: MP.textSecondary,
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: MP.card,
          borderRadius: BorderRadius.circular(MP.rLarge),
          boxShadow: MP.shadowCard,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MP.rLarge),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 68),
                children[i],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon, this.color);
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(MP.rSmall),
    ),
    child: Icon(icon, color: color, size: MP.iconMd),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Material(
    color: MP.card,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MP.s4,
            vertical: MP.s3,
          ),
          child: Row(
            children: [
              _RowIcon(icon, color),
              const SizedBox(width: MP.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: danger ? MP.error : MP.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: MP.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!danger)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MP.textMuted,
                  size: MP.iconLg,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: MP.card,
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MP.s4,
        vertical: MP.s1,
      ),
      secondary: _RowIcon(icon, MP.navy),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MP.ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: MP.textSecondary),
      ),
    ),
  );
}

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
      style: const TextStyle(fontSize: 18),
      decoration: const InputDecoration(labelText: 'Seu nome'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('name-save'),
        style: FilledButton.styleFrom(minimumSize: const Size(110, 52)),
        onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
        child: const Text('Salvar'),
      ),
    ],
  );
}

/// MP-T22 · Conexões MaraPass: convidar por link.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    const link = 'https://teste.marapass.com/convite';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader(
              'Conexões MaraPass',
              subtitle: 'Convide quem vai viajar com você.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MpPhoto(photo: 'p2', height: 180),
                  const SizedBox(height: MP.s4),
                  Text(
                    'Viajar junto é melhor',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: MP.s2),
                  const Text(
                    'Mande o link para amigos e família. Quem entrar pelo convite já começa com o passaporte ativo.',
                    style: TextStyle(fontSize: 17, height: 1.5),
                  ),
                  const SizedBox(height: MP.s4),
                  Container(
                    padding: const EdgeInsets.all(MP.s4),
                    decoration: BoxDecoration(
                      color: MP.soft,
                      borderRadius: BorderRadius.circular(MP.rMedium),
                    ),
                    child: const Text(
                      link,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: MP.navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  MpCtaButton(
                    key: const Key('invite-share'),
                    label: 'Compartilhar link',
                    icon: Icons.ios_share_rounded,
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(
                          text:
                              'Vamos viajar pelo Maranhão com o MaraPass! $link',
                        ),
                      );
                      store.invite();
                      if (!context.mounted) return;
                      await push<void>(
                        context,
                        MpStatusScreen(
                          title: 'Convite pronto!',
                          message: 'O link foi copiado. Cole na conversa do WhatsApp ou onde preferir.',
                          primaryLabel: 'Abrir o WhatsApp',
                          onPrimary: () => openWhatsApp(
                            context,
                            '',
                            'Vamos viajar pelo Maranhão com o MaraPass! $link',
                          ),
                          secondaryLabel: 'Fechar',
                          onSecondary: () => Navigator.of(context).pop(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: MP.s3),
                  Text(
                    'Convites enviados: ${store.invites}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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

/// Ajuda com busca.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = Content.faq
        .where(
          (f) =>
              _q.isEmpty ||
              '${f.pergunta} ${f.resposta}'.toLowerCase().contains(
                _q.toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader('Ajuda', subtitle: 'Perguntas frequentes.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: TextField(
                key: const Key('help-search'),
                onChanged: (v) => setState(() => _q = v.trim()),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Buscar na ajuda',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: MP.s3),
            if (list.isEmpty)
              MpEmpty(
                icon: Icons.help_outline_rounded,
                title: 'Nada encontrado',
                message: 'Fale com o atendimento que respondemos você.',
                actionLabel: 'Abrir atendimento',
                onAction: () =>
                    push<void>(context, const SupportCenterScreen()),
              ),
            for (final f in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s2,
                ),
                child: MpCard(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    shape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: MP.s4,
                      vertical: MP.s1,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      MP.s4,
                      0,
                      MP.s4,
                      MP.s4,
                    ),
                    title: Text(
                      f.pergunta,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MP.ink,
                      ),
                    ),
                    children: [
                      Text(
                        f.resposta,
                        style: const TextStyle(fontSize: 17, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(MP.pageH),
              child: OutlinedButton.icon(
                onPressed: () =>
                    push<void>(context, const SupportCenterScreen()),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Falar com o atendimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
