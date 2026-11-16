import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';

/// Cadastro de parceiro: a conta logada pede acesso e a equipe MaraPass
/// aprova. Enquanto isso, mostra o andamento do pedido.
class PartnerRequestScreen extends ConsumerStatefulWidget {
  const PartnerRequestScreen({super.key});
  @override
  ConsumerState<PartnerRequestScreen> createState() => _PartnerRequestState();
}

class _PartnerRequestState extends ConsumerState<PartnerRequestScreen> {
  final _business = TextEditingController();
  final _cadastur = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  Map<String, dynamic>? _req;
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = ref.read(appStoreProvider).remote;
    (r == null ? Future.value(null) : r.myPartnerRequest()).then((v) {
      if (mounted) setState(() => _req = v);
    }).catchError((Object _) {}).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    for (final c in [_business, _cadastur, _city, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_business.text.trim().length < 2 || _city.text.trim().isEmpty || _phone.text.trim().length < 8) {
      setState(() => _error = 'Preencha o nome do negócio, a cidade e um telefone com DDD.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(appStoreProvider).remote!.requestPartner(
        business: _business.text,
        cadastur: _cadastur.text,
        city: _city.text,
        phone: _phone.text,
      );
      if (mounted) setState(() => _req = r);
    } on MvpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, Key key, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: MP.s3),
    child: TextField(key: key, controller: c, keyboardType: type, decoration: InputDecoration(labelText: label)),
  );

  @override
  Widget build(BuildContext context) {
    final status = _req?['status'] as String?;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader('Seja parceiro MaraPass', subtitle: 'Publique ofertas, valide cupons e receba reservas.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(MP.s8), child: MpLoading())
                  : status == 'pendente'
                  ? MpNotice(
                      key: const Key('partner-pending'),
                      'Recebemos o cadastro de ${_req!['business']}. A equipe MaraPass confere os dados e libera a área do parceiro em até 2 dias úteis.',
                      icon: Icons.hourglass_top_rounded,
                      fg: MP.info,
                      bg: MP.infoBg,
                    )
                  : status == 'recusado'
                  ? MpNotice(
                      'O cadastro não foi aprovado${_req!['note'] == null ? '' : ': ${_req!['note']}'}. Fale com o suporte para revisar.',
                      icon: Icons.info_outline_rounded,
                      fg: MP.warning,
                      bg: MP.warningBg,
                    )
                  : status == 'aprovado'
                  ? const MpNotice(
                      'Cadastro aprovado. Volte e toque em Área do parceiro de novo.',
                      icon: Icons.verified_rounded,
                      fg: MP.success,
                      bg: MP.successBg,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(_business, 'Nome do negócio', const Key('pr-business')),
                        _field(_cadastur, 'Cadastur (opcional)', const Key('pr-cadastur')),
                        _field(_city, 'Cidade', const Key('pr-city')),
                        _field(_phone, 'Telefone com DDD', const Key('pr-phone'), type: TextInputType.phone),
                        if (_error != null) ...[
                          MpNotice(_error!, icon: Icons.error_outline_rounded, fg: MP.error, bg: MP.errorBg),
                          const SizedBox(height: MP.s3),
                        ],
                        MpPrimaryButton(key: const Key('pr-send'), label: 'Enviar cadastro', busy: _busy, onPressed: _send),
                        const SizedBox(height: MP.s3),
                        const Text(
                          'A área do parceiro é liberada depois que a equipe MaraPass confirma o negócio.',
                          style: TextStyle(fontSize: 14, color: MP.textSecondary),
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
