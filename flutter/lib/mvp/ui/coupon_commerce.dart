import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/coupon_commerce.dart';
import '../data/models.dart' show formatBrl;
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';

String _when(dynamic date) {
  final t = DateTime.parse(date as String).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} às ${two(t.hour)}:${two(t.minute)}';
}

void _message(BuildContext c, Object e) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(e.toString())));

class CouponReceipt extends ConsumerStatefulWidget {
  const CouponReceipt({
    super.key,
    required this.code,
    required this.scope,
    this.channel = 'panel',
  });
  final String code, scope, channel;
  @override
  ConsumerState<CouponReceipt> createState() => _CouponReceiptState();
}

class _CouponReceiptState extends ConsumerState<CouponReceipt> {
  Map<String, dynamic>? receipt;
  String? error;
  bool busy = false;
  final amount = TextEditingController(),
      reason = TextEditingController(),
      reference = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    reference.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    final store = ref.read(appStoreProvider);
    if (store.remote == null) {
      setState(() => error = 'Este link exige conexão com o MaraPass.');
      return;
    }
    if (!store.online &&
        !await requireLogin(
          context,
          ref,
          reason: 'Entre para consultar este cupom.',
        )) {
      if (mounted) setState(() => error = 'Entre para consultar este cupom.');
      return;
    }
    try {
      final rows = await store.remote!.statement(
        widget.scope,
        code: widget.code,
      );
      if (!mounted) return;
      setState(() {
        receipt = rows.firstOrNull;
        error = rows.isEmpty ? 'Cupom indisponível para esta conta.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
      if (mounted) await ref.read(appStoreProvider).syncFromServer();
    } catch (e) {
      if (mounted) _message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transition(
    String action,
    String label, {
    bool explain = false,
  }) async {
    String? note;
    if (explain) {
      var value = '';
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(label),
          content: TextField(
            autofocus: true,
            maxLength: 300,
            onChanged: (s) => value = s.trim(),
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value),
              child: const Text('Registrar'),
            ),
          ],
        ),
      );
      if (note == null || !mounted) return;
      if (note.isEmpty) {
        _message(context, 'Registre o motivo.');
        return;
      }
    }
    await act(
      () => ref
          .read(appStoreProvider)
          .remote!
          .couponAction(widget.code, action, note, widget.channel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = receipt, partner = widget.scope == 'partner';
    return Scaffold(
      appBar: AppBar(
        title: Text(partner ? 'Conferir recebimento' : 'Meu cupom'),
      ),
      body: error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(
                    onPressed: load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : r == null
          ? const Padding(padding: EdgeInsets.all(MP.pageH), child: MpSkeletonList(rows: 5))
          : Builder(
              builder: (context) {
                final sale = r['sale'] as Map, state = r['state'] as String;
                final open = [
                  'issued',
                  'interested',
                  'payment_reported',
                ].contains(state);
                final remote = ref.read(appStoreProvider).remote!;
                final url = Uri.tryParse(sale['url'] as String? ?? '');
                final receiptCode = r['code'] as String;
                return RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        sale['title'] as String,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(couponStates[state] ?? state),
                      Text(
                        'Validade até ${_when(sale['expires'])} (limite exclusivo)',
                      ),
                      const Divider(),
                      Text(
                        'Preço do item   ${formatBrl(sale['price'] as int)}',
                      ),
                      Text(
                        'Desconto   ${formatBrl(sale['discount_cents'] as int)}',
                      ),
                      Text(
                        'Valor a pagar ao parceiro   ${formatBrl(sale['due'] as int)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if ((sale['rules'] as String).isNotEmpty)
                        Text(sale['rules'] as String),
                      const SizedBox(height: 12),
                      if (!partner && open) ...[
                        Center(
                          child: QrImageView(
                            data: 'marapass:cupom:$receiptCode',
                            size: 164,
                            semanticsLabel:
                                'Código para o parceiro conferir este cupom',
                          ),
                        ),
                        SelectableText(
                          receiptCode,
                          textAlign: TextAlign.center,
                        ),
                        if ((sale['payment'] as String?)?.isNotEmpty == true)
                          SelectableText(
                            'Instruções do parceiro\n${sale['payment']}',
                          ),
                        if (url != null &&
                            url.scheme == 'https' &&
                            url.host.isNotEmpty)
                          FilledButton(
                            onPressed: () async {
                              try {
                                if (!await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  throw 'Não foi possível abrir o pagamento.';
                                }
                              } catch (e) {
                                if (context.mounted) _message(context, e);
                              }
                            },
                            child: const Text('Pagar diretamente ao parceiro'),
                          ),
                        if (url == null || url.scheme != 'https')
                          OutlinedButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Pagar ao parceiro'),
                                content: SelectableText(
                                  sale['payment'] as String? ?? '',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('Ver instruções de pagamento'),
                          ),
                        if (state == 'issued' || state == 'interested')
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => act(
                                    () => remote.reportPayment(receiptCode),
                                  ),
                            child: const Text('Já paguei ao parceiro'),
                          ),
                        if (state == 'payment_reported')
                          const Text(
                            'Aguardando o parceiro conferir o recebimento.',
                          ),
                      ],
                      if (partner && open) ...[
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Valor recebido pelo item (R\$)',
                          ),
                        ),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => act(() async {
                                  final cents = couponHundredths(amount.text);
                                  if (cents == null) throw 'Informe o valor recebido, com até dois decimais.';
                                  final result = await remote.confirmReceipt(
                                    receiptCode,
                                    cents,
                                    widget.channel,
                                  );
                                  if (result['ok'] != true) await load();
                                  if (result['ok'] != true) {
                                    throw switch (result['reason']) {
                                      'amount_mismatch' => 'O valor diverge do cupom. Confira o pagamento antes de confirmar.',
                                      'rate_limited' => 'Aguarde um minuto para tentar novamente.',
                                      'expired' => 'Cupom vencido.',
                                      _ =>
                                        'Cupom indisponível para esta conta.',
                                    };
                                  }
                                }),
                          child: const Text('Confirmo que recebi este valor'),
                        ),
                      ],
                      const Divider(),
                      Text(
                        'Valor confirmado, líquido de estornos   ${formatBrl(r['paid'] as int)}',
                      ),
                      if (partner)
                        Text(
                          'Comissão MaraPass   ${formatBrl(r['fee'] as int)}',
                        ),
                      if (partner && r['fee_state'] != null)
                        Text(
                          'Situação da comissão: ${couponFeeStates[r['fee_state']]}',
                        ),
                      if (sale['hours']?.toString().isNotEmpty == true)
                        Text('Horários do serviço: ${sale['hours']}'),
                      if (!partner &&
                          open &&
                          sale['contact']?.toString().isNotEmpty == true)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => act(() async {
                                  if (state == 'issued') {
                                    await remote.couponAction(
                                      receiptCode,
                                      'interest',
                                      null,
                                      widget.channel,
                                    );
                                  }
                                  final uri = Uri.https(
                                    'wa.me',
                                    '/${sale['contact']}',
                                    {
                                      'text':
                                          'Quero falar sobre o cupom $receiptCode',
                                    },
                                  );
                                  if (!await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  )) {
                                    throw 'Não foi possível abrir a conversa.';
                                  }
                                }),
                          child: const Text('Falar com o parceiro'),
                        ),
                      if (open)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => transition(
                                  partner ? 'decline' : 'cancel',
                                  partner ? 'Recusar cupom' : 'Cancelar cupom',
                                  explain: true,
                                ),
                          child: Text(
                            partner ? 'Recusar cupom' : 'Cancelar cupom',
                          ),
                        ),
                      if (open ||
                          [
                            'converted',
                            'utilized',
                            'completed',
                            'partial_refund',
                          ].contains(state))
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => transition(
                                  'dispute',
                                  'Contestar',
                                  explain: true,
                                ),
                          child: const Text('Contestar'),
                        ),
                      if (state == 'disputed' && partner)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => transition(
                                  'resolve',
                                  'Registrar solução',
                                  explain: true,
                                ),
                          child: const Text('Resolver divergência'),
                        ),
                      if (partner &&
                          r['stage'] == 'converted' &&
                          state != 'refunded')
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => transition(
                                  'utilize',
                                  'Registrar utilização',
                                ),
                          child: const Text('Registrar utilização'),
                        ),
                      if (partner && r['stage'] == 'utilized')
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () =>
                                    transition('complete', 'Concluir entrega'),
                          child: const Text('Concluir entrega'),
                        ),
                      Text('Pontos no Passaporte   ${r['points']}'),
                      for (final e in r['entries'] as List)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e['kind'] == 'refund'
                                ? 'Estorno · ${e['reason']}'
                                : 'Conversão confirmada',
                          ),
                          subtitle: Text(
                            '${_when(e['at'])} · ${e['reference']}',
                          ),
                          trailing: Text(formatBrl(e['paid_cents'] as int)),
                        ),
                      if (partner && (r['paid'] as int) > 0)
                        ExpansionTile(
                          title: const Text('Registrar reembolso já efetuado'),
                          children: [
                            TextField(
                              controller: amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Valor devolvido (R\$)',
                              ),
                            ),
                            TextField(
                              controller: reference,
                              decoration: const InputDecoration(
                                labelText: 'Referência única do reembolso',
                              ),
                            ),
                            TextField(
                              controller: reason,
                              decoration: const InputDecoration(
                                labelText: 'Motivo',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => act(() async {
                                      final cents = couponHundredths(
                                        amount.text,
                                      );
                                      if (cents == null ||
                                          cents < 1 ||
                                          reference.text.trim().isEmpty ||
                                          reason.text.trim().isEmpty) {
                                        throw 'Informe valor, referência e motivo.';
                                      }
                                      await remote.refundCoupon(
                                        receiptCode,
                                        cents,
                                        reference.text,
                                        reason.text,
                                      );
                                      if (mounted) {
                                        amount.clear();
                                        reference.clear();
                                        reason.clear();
                                      }
                                    }),
                              child: const Text('Registrar ajuste'),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class PartnerCouponList extends ConsumerStatefulWidget {
  const PartnerCouponList({
    super.key,
    this.lookup = false,
    this.dashboard = false,
    this.shortcuts,
  });
  final bool lookup, dashboard;
  final Widget? shortcuts;
  @override
  ConsumerState<PartnerCouponList> createState() => _PartnerCouponListState();
}

class _PartnerCouponListState extends ConsumerState<PartnerCouponList> {
  final input = TextEditingController();
  final rows = <Map<String, dynamic>>[];
  Map<String, dynamic> filters = {}, summary = {};
  bool more = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final remote = ref.read(appStoreProvider).remote!;
      final data = await remote.statement(
        'partner',
        cursor: reset ? null : rows.lastOrNull,
        filters: filters,
      );
      final totals = reset ? await remote.couponOverview(filters) : summary;
      if (mounted) {
        setState(() {
          summary = totals;
          if (reset) rows.clear();
          rows.addAll(data);
          more = data.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(String value, {String channel = 'panel'}) async {
    final code = commercialCouponCode(value);
    if (code == null) {
      _message(context, 'Confira o código completo emitido pelo MaraPass.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CouponReceipt(code: code, scope: 'partner', channel: channel),
      ),
    );
    if (mounted) await load(reset: true);
  }

  Future<void> scan() async {
    bool read = false;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Ler QR do cupom')),
          body: MobileScanner(
            onDetect: (capture) {
              if (read) return;
              for (final b in capture.barcodes) {
                final c = commercialCouponCode(b.rawValue ?? '');
                if (c != null) {
                  read = true;
                  Navigator.of(ctx).pop(c);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
    if (code != null && mounted) await open(code, channel: 'qr');
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: () => load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.dashboard)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Modo turista'),
              ),
            ),
          Text(
            widget.lookup
                ? 'Validar cupom'
                : widget.dashboard
                ? 'Painel do parceiro'
                : 'Extrato de cupons',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (widget.shortcuts != null) widget.shortcuts!,
          if (!widget.lookup) ...[
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (range != null && mounted) {
                        filters = {
                          'from': range.start
                              .toIso8601String()
                              .split('T')
                              .first,
                          'until': range.end.toIso8601String().split('T').first,
                        };
                        await load(reset: true);
                      }
                    },
              child: Text(
                filters.isEmpty
                    ? 'Filtrar período de emissão'
                    : '${filters['from']} a ${filters['until']}',
              ),
            ),
            if (filters.isNotEmpty)
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        filters = {};
                        load(reset: true);
                      },
                child: const Text('Limpar período'),
              ),
            if (summary.isNotEmpty)
              Text(
                '${summary['converted']} conversões de ${summary['issued']} emissões · Recebido ${formatBrl(summary['paid'] as int)} · Comissão ${formatBrl(summary['fee'] as int)}',
              ),
          ],
          if (widget.lookup) ...[
            TextField(
              controller: input,
              decoration: const InputDecoration(labelText: 'Código do cupom'),
            ),
            FilledButton(
              onPressed: () => open(input.text),
              child: const Text('Consultar cupom'),
            ),
            TextButton.icon(
              onPressed: scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Ler QR'),
            ),
          ],
          TextButton.icon(
            onPressed: busy ? null : () => load(reset: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
          ),
          if (error != null) Text(error!),
          if (rows.isEmpty && !busy && error == null)
            const Text('Nenhum cupom comercial emitido nas suas ofertas.'),
          for (final row in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row['sale']['title'] as String),
              subtitle: Text(
                '${couponStates[row['state']]} · ${_when(row['issued_at'])}\nRecebido ${formatBrl(row['paid'] as int)} · Comissão ${formatBrl(row['fee'] as int)}',
              ),
              onTap: () => open(row['code'] as String),
            ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (more && rows.isNotEmpty)
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Ver mais'),
            ),
        ],
      ),
    ),
  );
}

class CouponConsent extends ConsumerStatefulWidget {
  const CouponConsent({super.key});
  @override
  ConsumerState<CouponConsent> createState() => _CouponConsentState();
}

class _CouponConsentState extends ConsumerState<CouponConsent> {
  final phone = TextEditingController(), otp = TextEditingController();
  bool? enabled;
  bool sent = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = ref.read(appStoreProvider).remote!;
      final value = await r.waPreference();
      if (mounted) {
        setState(() {
          enabled = value;
          phone.text = r.confirmedPhone ?? '';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final r = ref.read(appStoreProvider).remote!;
      final number = phone.text.trim();
      final digits = number.replaceFirst('+', '');
      if (enabled == true) {
        await r.setWa(false);
      } else if (!RegExp(r'^[1-9]\d{7,14}$').hasMatch(digits)) {
        throw 'Informe o telefone com código do país e DDD.';
      } else if ((r.confirmedPhone ?? '').replaceFirst('+', '') != digits &&
          !sent) {
        await r.startPhone('+$digits');
        if (mounted) setState(() => sent = true);
        return;
      } else {
        if (sent) await r.confirmPhone('+$digits', otp.text.trim());
        await r.setWa(true);
      }
      if (mounted) {
        setState(() => sent = false);
        await load();
      }
    } catch (e) {
      if (mounted) _message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cupons pelo WhatsApp')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Autorizo o MaraPass a enviar avisos de emissão dos meus cupons e das minhas ofertas a este número. Posso cancelar aqui ou responder SAIR.',
        ),
        if (error != null)
          TextButton(onPressed: load, child: Text('$error · Tentar novamente')),
        if (enabled != null) ...[
          TextField(
            controller: phone,
            enabled: !busy && !sent && enabled != true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone com DDI e DDD',
            ),
          ),
          if (sent)
            TextField(
              controller: otp,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código de verificação recebido',
              ),
            ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(
              enabled == true
                  ? 'Revogar autorização'
                  : sent
                  ? 'Verificar e autorizar'
                  : 'Autorizar avisos de cupom',
            ),
          ),
        ],
      ],
    ),
  );
}
