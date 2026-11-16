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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s10),
          children: [
            const MpHeader('Perfil'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: MP.yellow,
                          child: Text(
                            display.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
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
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                user?.email ?? 'Você está como visitante',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${store.points} pontos · ${store.level.$1}',
                                style: const TextStyle(
                                  color: MP.green,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('edit-name'),
                          tooltip: 'Editar nome',
                          iconSize: 26,
                          onPressed: () => _editName(context, store),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (user == null) ...[
                    const SizedBox(height: MP.s3),
                    MpCtaButton(
                      key: const Key('profile-login'),
                      label: 'Entrar com e-mail',
                      onPressed: () => requireLogin(context, ref),
                    ),
                  ],
                  const SizedBox(height: MP.sectionGap),
                  const MpSectionTitle('Facilidades'),
                  const SizedBox(height: MP.s2),
                  MpCard(
                    padding: const EdgeInsets.symmetric(horizontal: MP.s3),
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('big-text'),
                          value: store.bigText,
                          onChanged: store.setBigText,
                          secondary: const Icon(
                            Icons.text_increase_rounded,
                            color: MP.navy,
                            size: 30,
                          ),
                          title: const Text(
                            'Letra grande',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: const Text(
                            'Aumenta o texto do aplicativo inteiro',
                          ),
                        ),
                        const Divider(),
                        SwitchListTile(
                          key: const Key('offer-alerts'),
                          value: store.offerAlerts,
                          onChanged: store.setOfferAlerts,
                          secondary: const Icon(
                            Icons.notifications_active_rounded,
                            color: MP.navy,
                            size: 30,
                          ),
                          title: const Text(
                            'Avisos de ofertas',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            store.offerAlerts
                                ? 'Você recebe cupons novos e lembretes'
                                : 'Desligados: só lembretes de reserva',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.sectionGap),
                  const MpSectionTitle('Minha conta'),
                  const SizedBox(height: MP.s2),
                  for (final e
                      in <(IconData, String, String, Widget?, VoidCallback?)>[
                        (
                          Icons.event_note_rounded,
                          'Minhas reservas',
                          '${store.myReservations.length} reservas',
                          const ReservationsScreen(),
                          null,
                        ),
                        (
                          Icons.local_activity_rounded,
                          'Meus cupons',
                          '${store.coupons.where((c) => c.active).length} ativos',
                          null,
                          () {
                            ref.read(shellTabProvider.notifier).go(Tabs.cupons);
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                        ),
                        (
                          Icons.photo_library_rounded,
                          'Minhas galerias',
                          'Fotos e álbum da viagem',
                          const GalleriesScreen(),
                          null,
                        ),
                        (
                          Icons.support_agent_rounded,
                          'Atendimento',
                          'Conversas, suporte e sugestões',
                          const SupportCenterScreen(),
                          null,
                        ),
                        (
                          Icons.group_add_rounded,
                          'Conexões MaraPass',
                          'Convide amigos e família',
                          const ConnectionsScreen(),
                          null,
                        ),
                        (
                          Icons.help_rounded,
                          'Ajuda',
                          'Perguntas frequentes',
                          const HelpScreen(),
                          null,
                        ),
                      ]) ...[
                    MpListTile(
                      icon: e.$1,
                      title: e.$2,
                      subtitle: e.$3,
                      onTap: e.$5 ?? () => push<void>(context, e.$4!),
                    ),
                    const SizedBox(height: MP.s2),
                  ],
                  const SizedBox(height: MP.s4),
                  MpListTile(
                    key: const Key('partner-area'),
                    icon: Icons.storefront_rounded,
                    title: 'Área do parceiro',
                    subtitle: 'Para empresas: cupons, validação e reservas',
                    tint: MP.navy,
                    color: Colors.white,
                    onTap: () {
                      store.enterPartnerArea();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PartnerShell(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: MP.s4),
                  const MpNotice.demo(
                    'Versão de teste: parceiros, ofertas e preços são de demonstração. Seus cupons, reservas e check-ins ficam salvos neste aparelho.',
                  ),
                  const SizedBox(height: MP.s5),
                  if (user != null) ...[
                    OutlinedButton.icon(
                      key: const Key('sign-out'),
                      onPressed: () async {
                        try {
                          await ref.read(authGatewayProvider).signOut();
                        } on MvpException catch (e) {
                          if (context.mounted) showMpSnack(context, e.message);
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sair da conta'),
                    ),
                    const SizedBox(height: MP.s2),
                    TextButton(
                      key: const Key('delete-account'),
                      onPressed: () => _delete(context, ref),
                      child: const Text(
                        'Excluir minha conta',
                        style: TextStyle(color: MP.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
