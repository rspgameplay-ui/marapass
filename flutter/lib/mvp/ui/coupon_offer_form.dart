import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/coupon_commerce.dart';
import '../data/models.dart' show formatBrl;
import '../data/store.dart';

class SaleOfferForm extends ConsumerStatefulWidget {
  const SaleOfferForm({super.key, this.offerId, this.existing});
  final String? offerId;
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<SaleOfferForm> createState() => _SaleOfferFormState();
}

class _SaleOfferFormState extends ConsumerState<SaleOfferForm> {
  late final Map<String, TextEditingController> fields;
  String kind = 'percent', category = 'hospedagem';
  bool points = true, busy = false;
  DateTime until = DateTime.now().add(const Duration(days: 30));
  DateTime starts = DateTime.now();
  String getValue(String key) => fields[key]!.text.trim();
  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    String decimal(dynamic n) => n == null
        ? ''
        : '${(n as int) ~/ 100},${(n % 100).toString().padLeft(2, '0')}';
    starts = DateTime.tryParse(t?['from'] as String? ?? '') ?? DateTime.now();
    kind = t?['kind'] as String? ?? 'percent';
    points = t?['points'] as bool? ?? true;
    fields = {
      for (final e in {
        'title': '',
        'rules': '',
        'limit': '100',
        'per_user': '${t?['per_user'] ?? 1}',
        'price': decimal(t?['price']),
        'discount': decimal(t?['discount']),
        'hours': t?['hours'] as String? ?? '',
        'contact': t?['contact'] as String? ?? '',
        'payment': t?['payment'] as String? ?? '',
        'url': t?['url'] as String? ?? '',
      }.entries)
        e.key: TextEditingController(text: e.value),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String key,
    String label, {
    TextInputType? keyboard,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: fields[key],
      keyboardType: keyboard,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );
  Future<void> submit({bool draft = false}) async {
    if (busy) return;
    final price = couponHundredths(getValue('price')),
        discount = couponHundredths(getValue('discount'));
    final per = int.tryParse(getValue('per_user')),
        limit = int.tryParse(getValue('limit'));
    final uri = Uri.tryParse(getValue('url'));
    String? problem;
    if (widget.offerId == null &&
        (getValue('title').length < 4 ||
            limit == null ||
            limit < 1 ||
            limit > 10000)) {
      problem = 'Confira o nome e o estoque da oferta.';
    }
    if (price == null ||
        price < 1 ||
        price > 1000000000 ||
        discount == null ||
        discount < 0 ||
        discount > (kind == 'percent' ? 10000 : price)) {
      problem = 'Confira o preço e o desconto.';
    }
    if (per == null || per < 1 || per > 10000) {
      problem = 'Informe um limite válido por turista.';
    }
    if (getValue('payment').isEmpty && getValue('url').isEmpty) {
      problem = 'Informe como o turista deve pagar ao estabelecimento.';
    }
    if (getValue('url').isNotEmpty &&
        (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
      problem = 'Use o endereço HTTPS do parceiro.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => busy = true);
    try {
      final store = ref.read(appStoreProvider);
      await store.remote!.saveSale(
        {
          'title': getValue('title'),
          'draft': draft,
          'rules': getValue('rules'),
          'limit': limit,
          'category': category,
          'until': until.toIso8601String().split('T').first,
        },
        {
          'price': price,
          'kind': kind,
          'discount': discount,
          'points': points,
          'per_user': per,
          'payment': getValue('payment'),
          'window': {
            'from': starts.toIso8601String().split('T').first,
            'contact': getValue('contact'),
            'hours': getValue('hours'),
          },
          'url': getValue('url'),
        },
        id: widget.offerId,
      );
      await store.syncFromServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              draft ? 'Rascunho salvo.' : 'Oferta enviada para aprovação.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = couponHundredths(getValue('price')),
        discount = couponHundredths(getValue('discount'));
    final due = price == null || discount == null
        ? null
        : kind == 'promo'
        ? discount
        : price -
              (kind == 'percent'
                  ? (price * discount + 5000) ~/ 10000
                  : discount);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.offerId == null ? 'Criar oferta' : 'Condições comerciais',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.offerId == null) ...[
            field('title', 'Produto ou serviço'),
            field('rules', 'Condições de uso', lines: 2),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(labelText: tr('Categoria')),
              items: [
                for (final e in const {
                  'hospedagem': 'Hospedagem',
                  'passeio': 'Passeios',
                  'gastronomia': 'Gastronomia',
                  'cultura': 'Cultura',
                  'natureza': 'Natureza',
                  'evento': 'Eventos',
                  'artesanato': 'Artesanato',
                  'fotografia': 'Fotografia',
                  'transporte': 'Transporte turístico',
                }.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => category = v!),
            ),
            field(
              'limit',
              'Estoque total de cupons',
              keyboard: TextInputType.number,
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: until,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) setState(() => until = date);
              },
              child: Text(
                'Válido até ${until.day}/${until.month}/${until.year}',
              ),
            ),
          ],
          field(
            'per_user',
            'Limite por turista',
            keyboard: TextInputType.number,
          ),
          field(
            'price',
            'Preço do item antes do desconto (R\$)',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          SegmentedButton(
            segments: [
              ButtonSegment(value: 'percent', label: Text(tr('Percentual'))),
              ButtonSegment(value: 'fixed', label: Text(tr('Valor fixo'))),
              ButtonSegment(value: 'promo', label: Text(tr('Preço final'))),
            ],
            selected: {kind},
            onSelectionChanged: (v) => setState(() => kind = v.first),
          ),
          field(
            'discount',
            kind == 'promo'
                ? 'Preço promocional (R\$)'
                : kind == 'percent'
                ? 'Desconto (%)'
                : 'Desconto (R\$)',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (due != null && due >= 0)
            Text(
              'Turista paga ${formatBrl(due)} · Comissão na conversão ${formatBrl((due * 5 + 50) ~/ 100)}',
            ),
          field(
            'url',
            'Link HTTPS para pagar ao parceiro',
            keyboard: TextInputType.url,
          ),
          TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: starts,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) setState(() => starts = date);
            },
            child: Text(
              'Início da vigência ${starts.day}/${starts.month}/${starts.year}',
            ),
          ),
          field('hours', 'Horários de utilização do serviço'),
          field(
            'contact',
            'WhatsApp comercial para contato (DDI e DDD)',
            keyboard: TextInputType.phone,
          ),
          field('payment', 'Instruções de pagamento direto', lines: 2),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Compra elegível a pontos')),
            value: points,
            onChanged: (v) => setState(() => points = v),
          ),
          if (widget.offerId == null)
            TextButton(
              onPressed: busy ? null : () => submit(draft: true),
              child: Text(tr('Salvar rascunho')),
            ),
          FilledButton(
            onPressed: busy ? null : () => submit(),
            child: Text(tr('Enviar para aprovação')),
          ),
        ],
      ),
    );
  }
}
