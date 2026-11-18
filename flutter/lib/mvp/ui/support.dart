import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';

const _supportPhone = '(98) 3000-0000';

/// MP-T50 · Central de relacionamento: conversas, suporte e canais,
/// avaliações e sugestões, abrir solicitação. O WhatsApp é opcional:
/// o histórico oficial fica no app, com protocolo.
class SupportCenterScreen extends ConsumerWidget {
  const SupportCenterScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(appStoreProvider).tickets;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader(
              'Atendimento',
              subtitle: 'Fale com o MaraPass e com os parceiros.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpListTile(
                    key: const Key('sup-open'),
                    icon: Icons.support_agent_rounded,
                    title: 'Abrir solicitação',
                    subtitle: 'Problema com cupom, reserva ou conta',
                    tint: MP.tintBlue,
                    onTap: () => push<void>(
                      context,
                      const ComposeScreen(
                        kind: 'Suporte',
                        subject: 'Solicitação',
                        hint: 'Conte o que aconteceu',
                      ),
                    ),
                  ),
                  const SizedBox(height: MP.s2),
                  MpListTile(
                    key: const Key('sup-suggest'),
                    icon: Icons.lightbulb_rounded,
                    title: 'Sugestões e avaliações',
                    subtitle: 'Ajude a melhorar o programa',
                    tint: MP.tintYellow,
                    color: const Color(0xffa87b00),
                    onTap: () => push<void>(
                      context,
                      const ComposeScreen(
                        kind: 'Sugestão',
                        subject: 'Sugestão',
                        hint: 'Escreva a sua sugestão',
                      ),
                    ),
                  ),
                  const SizedBox(height: MP.s2),
                  MpListTile(
                    key: const Key('sup-channels'),
                    icon: Icons.forum_rounded,
                    title: 'Canais e WhatsApp',
                    subtitle: 'Telefone, e-mail e orientações',
                    tint: MP.tintGreen,
                    color: MP.green,
                    onTap: () => push<void>(context, const ChannelsScreen()),
                  ),
                  const SizedBox(height: MP.sectionGap),
                  const MpSectionTitle('Minhas conversas'),
                  const SizedBox(height: MP.s3),
                  if (tickets.isEmpty)
                    const MpCard(
                      color: MP.soft,
                      child: Text(
                        'Nenhuma conversa ainda. Quando você abrir uma solicitação, ela aparece aqui com o protocolo.',
                        style: TextStyle(fontSize: 16, color: MP.textSecondary),
                      ),
                    ),
                  for (final t in tickets) ...[
                    MpListTile(
                      icon: switch (t.kind) {
                        'Reserva' => Icons.event_rounded,
                        'Artesanato' => Icons.palette_rounded,
                        'Fotografia' => Icons.photo_camera_rounded,
                        'Transfer' => Icons.airport_shuttle_rounded,
                        'Sugestão' => Icons.lightbulb_rounded,
                        _ => Icons.support_agent_rounded,
                      },
                      title: '${t.kind}: ${t.subject}',
                      subtitle:
                          'Protocolo ${t.id} · ${t.status} · ${fmtDate(t.at)}',
                      onTap: () => push<void>(context, TicketScreen(id: t.id)),
                    ),
                    const SizedBox(height: MP.s2),
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

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const MpHeader('Canais de atendimento'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MpListTile(
                  icon: Icons.call_rounded,
                  title: 'Telefone',
                  subtitle: '$_supportPhone · seg a sáb, 8h às 20h',
                  onTap: () => callPhone(context, _supportPhone),
                ),
                const SizedBox(height: MP.s2),
                const MpListTile(
                  icon: Icons.mail_rounded,
                  title: 'E-mail',
                  subtitle: 'atendimento@marapass.com.br',
                ),
                const SizedBox(height: MP.s2),
                MpListTile(
                  icon: Icons.chat_rounded,
                  title: 'WhatsApp',
                  subtitle: 'Mensagem pronta com o seu protocolo',
                  tint: MP.tintGreen,
                  color: MP.green,
                  onTap: () => openWhatsApp(
                    context,
                    AppConfig.supportWhatsapp,
                    'Olá! Preciso de ajuda com o MaraPass.',
                  ),
                ),
                const SizedBox(height: MP.s4),
                const MpNotice(
                  'No WhatsApp, informe o número do protocolo. Nunca envie senhas, códigos de login ou dados de cartão.',
                  icon: Icons.shield_rounded,
                  fg: MP.warning,
                  bg: MP.warningBg,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Redigir mensagem → solicitação aberta com protocolo.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({
    super.key,
    required this.kind,
    required this.subject,
    required this.hint,
  });
  final String kind;
  final String subject;
  final String hint;
  @override
  ConsumerState<ComposeScreen> createState() => _ComposeState();
}

class _ComposeState extends ConsumerState<ComposeScreen> {
  final _ctrl = TextEditingController();
  int _stars = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = '${_stars > 0 ? '${'★' * _stars} ' : ''}${_ctrl.text.trim()}';
    final t = await ref
        .read(appStoreProvider)
        .openTicketAsync(
          kind: widget.kind,
          subject: widget.subject,
          body: body,
        );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MpStatusScreen(
          title: widget.kind == 'Sugestão'
              ? 'Obrigado pela sugestão!'
              : 'Mensagem enviada',
          message:
              'Protocolo ${t.id}. Você recebe a resposta em Atendimento, aqui no app.',
          primaryLabel: 'Ver atendimento',
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const SupportCenterScreen(),
            ),
          ),
          secondaryLabel: 'Fechar',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          MpHeader(
            widget.kind == 'Sugestão' ? 'Sua sugestão' : 'Nova mensagem',
            subtitle: widget.subject,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.kind == 'Sugestão') ...[
                  const Text(
                    'Que nota você dá para o MaraPass?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  StarRating(
                    value: _stars,
                    onChanged: (v) => setState(() => _stars = v),
                  ),
                  const SizedBox(height: MP.s3),
                ],
                TextField(
                  key: const Key('compose-text'),
                  controller: _ctrl,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 800,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: MP.s4),
                FilledButton(
                  key: const Key('compose-send'),
                  onPressed: _ctrl.text.trim().length >= 5 ? _send : null,
                  child: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TicketScreen> createState() => _TicketState();
}

class _TicketState extends ConsumerState<TicketScreen> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final t = store.tickets.firstWhere((e) => e.id == widget.id);
    Widget bubble(String text, bool mine) => Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: MP.s2),
        padding: const EdgeInsets.all(MP.s3),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? MP.navy : MP.soft,
          borderRadius: BorderRadius.circular(MP.rLarge),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17,
            color: mine ? Colors.white : MP.ink,
            height: 1.4,
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MpHeader(t.subject, subtitle: 'Protocolo ${t.id} · ${t.status}'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: OutlinedButton.icon(
                key: const Key('ticket-whatsapp'),
                onPressed: () => openWhatsApp(
                  context,
                  AppConfig.supportWhatsapp,
                  'Olá! Preciso falar com uma pessoa sobre o protocolo ${t.id} (${t.kind}: ${t.subject}).',
                ),
                icon: const Icon(Icons.chat_rounded, size: MP.iconMd),
                label: const Text('Falar com uma pessoa no WhatsApp'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                children: [
                  bubble(t.body, true),
                  bubble(
                    'Recebemos a sua mensagem. Respondemos em até 1 dia útil.',
                    false,
                  ),
                  for (final r in t.replies) bubble(r, true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MP.s3),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ticket-reply'),
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Escreva aqui',
                      ),
                    ),
                  ),
                  const SizedBox(width: MP.s2),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    iconSize: 26,
                    style: IconButton.styleFrom(
                      backgroundColor: MP.green,
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;
                      _ctrl.clear();
                      try {
                        await store.replyAsync(t.id, text);
                      } on MvpException catch (e) {
                        if (context.mounted) showMpSnack(context, e.message);
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
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
