part of 'partner.dart';

class _ValidateTab extends ConsumerStatefulWidget {
  const _ValidateTab();
  @override
  ConsumerState<_ValidateTab> createState() => _ValidateTabState();
}

class _ValidateTabState extends ConsumerState<_ValidateTab> {
  final _code = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) return;
    final s = ref.read(appStoreProvider);
    LocalCoupon? found;
    for (final c in s.coupons) {
      if (c.code == code) found = c;
    }
    // Conferência obrigatória antes de registrar o uso.
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferência'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código: $code',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: MP.s2),
            Text(
              found?.cupom == null
                  ? 'Cupom não encontrado nesta demonstração.'
                  : '${found!.cupom!.parceiro}\n${found.cupom!.beneficio}',
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: MP.s2),
            const Text(
              'Confira se é o titular e se a compra atende às condições.',
              style: TextStyle(color: MP.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('validate-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(130, 52)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar uso'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final cents =
        ((double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0) * 100)
            .round();
    final bool ok;
    final String msg;
    try {
      (ok, msg) = await s.validateCodeAsync(code, cents);
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
      return;
    }
    if (!mounted) return;
    await push<void>(
      context,
      MpStatusScreen(
        icon: ok ? Icons.check_rounded : Icons.block_rounded,
        color: ok ? MP.success : MP.error,
        bg: ok ? MP.successBg : MP.errorBg,
        title: ok ? 'Validação concluída' : 'Validação bloqueada',
        message: msg,
        details: ok
            ? MpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comprovante',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    MpInfoRow(Icons.tag_rounded, 'Código $code'),
                    MpInfoRow(
                      Icons.schedule_rounded,
                      '${fmtDate(DateTime.now())} às ${fmtTime(DateTime.now())}',
                    ),
                    if (cents > 0)
                      MpInfoRow(
                        Icons.payments_rounded,
                        'Compra de ${formatBrl(cents)}',
                      ),
                  ],
                ),
              )
            : null,
        primaryLabel: 'Validar outro cupom',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    );
    _code.clear();
    _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    if (s.remote != null) return const PartnerCouponList(lookup: true);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const _PartnerHeader(
            'Validar cupom',
            subtitle: 'Leia o QR ou digite o código do turista.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: MP.ink,
                    borderRadius: BorderRadius.circular(MP.rXl),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: MP.yellow,
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: MP.s2),
                const Text(
                  'A leitura pela câmera entra na versão instalada. Aqui, digite o código.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MP.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: MP.s4),
                TextField(
                  key: const Key('validate-code'),
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Código do cupom',
                    hintText: 'MP-XXXX',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: MP.s3),
                TextField(
                  key: const Key('validate-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: r'Valor da compra (opcional)',
                    prefixText: r'R$ ',
                  ),
                ),
                const SizedBox(height: MP.s4),
                MpCtaButton(
                  key: const Key('validate-submit'),
                  label: 'Conferir cupom',
                  onPressed: _code.text.trim().length >= 4 ? _check : null,
                ),
                const SizedBox(height: MP.sectionGap),
                const MpSectionTitle('Últimas validações'),
                const SizedBox(height: MP.s2),
                if (s.validations.isEmpty)
                  const MpCard(
                    color: MP.soft,
                    child: Text(
                      'Nenhuma validação ainda.',
                      style: TextStyle(fontSize: 16, color: MP.textSecondary),
                    ),
                  ),
                for (final v in s.validations.take(8)) ...[
                  MpListTile(
                    icon: v.ok
                        ? Icons.check_circle_rounded
                        : Icons.block_rounded,
                    tint: v.ok ? MP.successBg : MP.errorBg,
                    color: v.ok ? MP.success : MP.error,
                    title: '${v.code} · ${v.title}',
                    subtitle:
                        '${fmtDate(v.at)} ${fmtTime(v.at)}${v.ok ? '' : ' · ${v.reason}'}',
                  ),
                  const SizedBox(height: MP.s2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Relatórios (MP-P08)
class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();
  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  int _days = 7;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    if (s.remote != null) return const PartnerCouponList();
    final issued = s.partnerOffers.fold<int>(0, (a, o) => a + o.issued);
    final used =
        s.partnerOffers.fold<int>(0, (a, o) => a + o.used) +
        s.validations.where((v) => v.ok).length;
    // Série de demonstração estável + validações reais do aparelho.
    final series = List.generate(
      _days == 7 ? 7 : 10,
      (k) =>
          [3, 5, 4, 8, 6, 9, 7, 5, 6, 8][k % 10] +
          (k == (_days == 7 ? 6 : 9)
              ? s.validations.where((v) => v.ok).length
              : 0),
    );
    final maxV = series.reduce((a, b) => a > b ? a : b).toDouble();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const _PartnerHeader(
            'Relatórios',
            subtitle: 'Faturamento, retenção e horários de pico.',
          ),
          FilterChips<int>(
            options: const [7, 30],
            selected: _days,
            label: (v) => 'Últimos $v dias',
            onSelect: (v) => setState(() => _days = v),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _Kpi('Cupons emitidos', '$issued')),
                    const SizedBox(width: MP.s3),
                    Expanded(
                      child: _Kpi(
                        'Conversão',
                        issued == 0
                            ? '0%'
                            : '${(used * 100 / issued).round()}%',
                        color: MP.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MP.s4),
                MpCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cupons usados por dia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: MP.s4),
                      SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var k = 0; k < series.length; k++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${series[k]}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: MP.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        height: 120 * series[k] / maxV,
                                        decoration: BoxDecoration(
                                          color: k == series.length - 1
                                              ? MP.green
                                              : MP.green.withValues(alpha: .4),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s4),
                const MpCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horários de pico',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: MP.s2),
                      MpInfoRow(
                        Icons.wb_sunny_rounded,
                        'Manhã (8h às 11h): 45% dos usos',
                      ),
                      MpInfoRow(
                        Icons.wb_twilight_rounded,
                        'Fim de tarde (16h às 19h): 35%',
                      ),
                      MpInfoRow(Icons.nights_stay_rounded, 'Noite: 20%'),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s3),
                const MpNotice.demo(
                  'Números de demonstração somados às validações feitas neste aparelho.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Conta (MP-P09)
