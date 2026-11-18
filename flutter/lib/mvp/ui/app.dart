import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../theme/brand.dart';
import '../data/store.dart';
import '../theme/mara_logo.dart';
import '../theme/tokens.dart';
import 'animated_splash.dart';
import 'login_screen.dart';
import 'coupon_commerce.dart';
import '../data/coupon_commerce.dart';
import 'shell.dart';

const _onboardedKey = 'mvp_onboarded_v1';

/// Raiz do app: Abertura → Apresentação → (Login opcional) → Início.
/// A opção "Letra grande" do perfil amplia o texto do app inteiro.
class MvpApp extends ConsumerWidget {
  const MvpApp({super.key, this.splash = const Duration(milliseconds: 1400)});
  final Duration splash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final big = ref.watch(appStoreProvider.select((s) => s.bigText));
    final english = ref.watch(appStoreProvider.select((s) => s.language == 'en'));
    return MaterialApp(
      title: 'MaraPass',
      debugShowCheckedModeBanner: false,
      locale: english ? const Locale('en') : const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: mvpTheme(),
      themeMode: ThemeMode.light,
      scrollBehavior: const _AppScroll(),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final base = mq.textScaler.scale(1);
        final scale = (big ? base * 1.22 : base).clamp(1.0, 1.6);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: ColoredBox(
            color: MP.soft,
            child: Center(
              // No computador, o app fica com largura de celular.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          ),
        );
      },
      home:
          commercialCouponCode(Uri.base.queryParameters['cupom'] ?? '') != null
          ? CouponReceipt(
              code: commercialCouponCode(Uri.base.queryParameters['cupom']!)!,
              channel: 'whatsapp',
              scope: Uri.base.queryParameters['uso'] == 'parceiro'
                  ? 'partner'
                  : 'tourist',
            )
          : _Gate(splash: splash),
    );
  }
}

/// Rolagem de app: efeito elástico e sem barra de rolagem de site.
class _AppScroll extends MaterialScrollBehavior {
  const _AppScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}

class _Gate extends StatefulWidget {
  const _Gate({required this.splash});
  final Duration splash;
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool? _onboarded;
  late bool _splashDone = widget.splash == Duration.zero;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    var seen = false;
    try {
      seen =
          (await SharedPreferences.getInstance()).getBool(_onboardedKey) ??
          false;
    } catch (_) {}
    if (mounted) setState(() => _onboarded = seen);
  }

  Future<void> _done() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(
        _onboardedKey,
        true,
      );
    } catch (_) {}
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    final o = _onboarded;
    final Widget child;
    if (!_splashDone) {
      child = AnimatedSplash(
        key: const ValueKey('splash'),
        onDone: () => setState(() => _splashDone = true),
      );
    } else if (o == null) {
      // Na web a abertura em HTML cobre este instante; no app, a marca.
      child = widget.splash == Duration.zero
          ? const ColoredBox(key: ValueKey('blank'), color: MP.soft, child: SizedBox.expand())
          : const _Splash();
    } else if (!o) {
      child = _Welcome(key: const ValueKey('welcome'), onDone: _done);
    } else {
      child = const MvpShell(key: ValueKey('shell'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: child);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: maraNight,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MpLogo(width: 150, white: true),
          SizedBox(height: MP.s3),
          Text(
            'DESCUBRA · VIVA · VALORIZE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Apresentação simples: título, ilustração e as opções de entrada.
class _Welcome extends ConsumerWidget {
  const _Welcome({super.key, required this.onDone});
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> login() async {
      if (await requireLogin(context, ref)) await onDone();
    }

    return Scaffold(
      backgroundColor: const Color(0xfff4f3ee),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MP.s6, MP.s2, MP.s6, MP.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Fechar',
                  onPressed: onDone,
                  icon: const Icon(Icons.close_rounded, color: MP.ink, size: 28),
                ),
              ),
              const SizedBox(height: MP.s4),
              const Text(
                'Bem-vindo! Bora\nconhecer o Maranhão.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: MP.ink, height: 1.12, letterSpacing: -.6),
              ),
              const Expanded(child: Center(child: _WelcomeArt())),
              _PillButton(key: const Key('onb-login'), icon: Icons.mail_outline_rounded, label: 'Continuar com e-mail', onTap: login),
              const SizedBox(height: MP.s3),
              _PillButton(key: const Key('onb-social'), icon: Icons.account_circle_outlined, label: 'Continuar com Google ou Apple', onTap: login),
              const SizedBox(height: MP.s5),
              Center(
                child: TextButton(
                  key: const Key('onb-visitor'),
                  onPressed: onDone,
                  style: TextButton.styleFrom(foregroundColor: MP.ink),
                  child: const Text('Explorar sem cadastro',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: MP.ink,
        side: const BorderSide(color: MP.ink, width: 1.2),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: MP.s5),
      ),
      child: Row(children: [
        Icon(icon, size: 22),
        Expanded(
          child: Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 22),
      ]),
    ),
  );
}

/// Foto recortada em arco com nuvens e sol desenhados, no traço da referência.
class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: 260,
    child: Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: 30, right: 30, top: 10, bottom: 0,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: MP.ink, width: 2.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(200), bottom: Radius.circular(28)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(198), bottom: Radius.circular(26)),
            child: Image.asset('assets/photos/w_lencois.jpg', fit: BoxFit.cover),
          ),
        ),
      ),
      Positioned(right: 12, top: 0, child: _sun()),
      const Positioned(left: -6, top: 70, child: _Cloud(width: 92)),
      const Positioned(right: -10, top: 130, child: _Cloud(width: 76)),
    ]),
  );

  Widget _sun() => Container(
    width: 54, height: 54,
    decoration: BoxDecoration(color: MP.yellow, shape: BoxShape.circle, border: Border.all(color: MP.ink, width: 2.5)),
  );
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * .42,
    decoration: BoxDecoration(
      color: const Color(0xffc9d6f8),
      borderRadius: BorderRadius.circular(width),
      border: Border.all(color: MP.ink, width: 2.5),
    ),
  );
}
