import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/brand.dart';
import '../auth/auth.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';

/// Pede login só quando a ação exige conta e devolve `true` se o turista entrou.
/// Visitante explora livremente; a oferta escolhida é retomada pelo chamador.
Future<bool> requireLogin(
  BuildContext context,
  WidgetRef ref, {
  String? reason,
}) async {
  if (ref.read(authProvider) != null) return true;
  final ok = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => LoginScreen(reason: reason)));
  return ok == true && ref.read(authProvider) != null;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.reason});
  final String? reason;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _send() async {
    if (!_emailOk) {
      setState(() => _error = tr('Digite um e-mail válido, como nome@email.com.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authGatewayProvider).sendCode(_email.text);
      if (!mounted) return;
      setState(() => _codeStep = true);
    } on MvpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(
        () => _error = tr('O código tem 6 números. Confira o e-mail que enviamos.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authGatewayProvider).verifyCode(_email.text, code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on MvpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _social(String provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authGatewayProvider).signInWithProvider(provider);
    } on MvpException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Login social conclui fora desta tela (navegador): ao voltar logado, fecha.
    ref.listen<AuthUser?>(authProvider, (prev, next) {
      if (prev == null && next != null && mounted) {
        Navigator.of(context).pop(true);
      }
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr('Voltar'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _codeStep && !_busy
              ? setState(() {
                  _codeStep = false;
                  _error = null;
                })
              : Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s2, MP.pageH, MP.s8),
          children: [
            const MpLogo(width: 110),
            const SizedBox(height: MP.s6),
            Text(
              _codeStep ? tr('Digite o código') : tr('Entre no MaraPass'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: MP.s2),
            Text(
              _codeStep
                  ? '${tr('Enviamos um código para')} ${_email.text.trim()}.'
                  : (widget.reason ??
                        tr('Sem senha: enviamos um código para o seu e-mail.')),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: MP.textSecondary),
            ),
            const SizedBox(height: MP.s6),
            if (!_codeStep)
              TextField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  labelText: tr('E-mail'),
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              )
            else
              TextField(
                key: const Key('login-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: tr('Código'),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: MP.s3),
              Container(
                padding: const EdgeInsets.all(MP.s3),
                decoration: BoxDecoration(
                  color: MP.errorBg,
                  borderRadius: BorderRadius.circular(MP.rMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: MP.error, size: 20),
                    const SizedBox(width: MP.s2),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: MP.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MP.s5),
            MpPrimaryButton(
              key: const Key('login-submit'),
              label: _codeStep ? tr('Entrar') : tr('Enviar código'),
              busy: _busy,
              onPressed: _codeStep ? _verify : _send,
            ),
            if (_codeStep) ...[
              const SizedBox(height: MP.s3),
              OutlinedButton(
                onPressed: _busy ? null : _send,
                child: Text(tr('Enviar outro código')),
              ),
            ] else ...[
              const SizedBox(height: MP.s4),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: MP.s3),
                    child: Text(tr('ou entre com')),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: MP.s4),
              OutlinedButton.icon(
                key: const Key('login-google'),
                onPressed: _busy ? null : () => _social('google'),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 32),
                label: Text(tr('Continuar com Google')),
              ),
              const SizedBox(height: MP.s2),
              OutlinedButton.icon(
                key: const Key('login-apple'),
                onPressed: _busy ? null : () => _social('apple'),
                icon: const Icon(Icons.apple_rounded, size: 26),
                label: Text(tr('Continuar com Apple')),
              ),
            ],
            const SizedBox(height: MP.s5),
            Text(
              tr('Ao entrar, você concorda com os termos de uso e a política de privacidade do MaraPass.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(onPressed: () => openLegal(context, 'termos'), child: Text(tr('Termos de uso'))),
                TextButton(onPressed: () => openLegal(context, 'privacidade'), child: Text(tr('Privacidade'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
