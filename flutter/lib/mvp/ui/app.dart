import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/brand.dart';
import '../data/store.dart';
import '../theme/mara_logo.dart';
import '../theme/tokens.dart';
import 'animated_splash.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';
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
    return MaterialApp(
      title: 'MaraPass',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      home: _Gate(splash: splash),
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

/// Apresentação com foto em tela cheia (protótipo aprovado) e os três
/// pilares do Design Master: descobrir, benefícios e passaporte.
class _Welcome extends ConsumerStatefulWidget {
  const _Welcome({super.key, required this.onDone});
  final Future<void> Function() onDone;
  @override
  ConsumerState<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends ConsumerState<_Welcome> {
  final _page = PageController();
  int _i = 0;

  static const _slides = [
    (
      'splash_bg',
      'Mais que destinos, boas histórias.',
      'Seu passaporte turístico do Maranhão.',
    ),
    (
      'lagoa_boat',
      'Benefícios de verdade',
      'Ative cupons em parceiros e mostre o QR na hora de usar.',
    ),
    (
      'cultura',
      'Seu passaporte digital',
      'Faça check-in, ganhe selos e acompanhe suas reservas.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final ok = await requireLogin(context, ref);
    if (ok) await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _page,
            itemCount: _slides.length,
            onPageChanged: (v) => setState(() => _i = v),
            itemBuilder: (_, i) => MpPhoto(
              photo: _slides[i].$1,
              height: null,
              radius: 0,
              darken: true,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.all(MP.pageH),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: c.maxHeight - MP.pageH * 2,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: MP.s4),
                        const MpLogo(width: 150, white: true),
                        const SizedBox(height: MP.s2),
                        const Text(
                          'DESCUBRA · VIVA · VALORIZE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _slides[_i].$2,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: MP.s2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _slides[_i].$3,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: MP.s5),
                        Row(
                          children: [
                            for (var k = 0; k < _slides.length; k++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 6),
                                width: k == _i ? 28 : 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: k == _i ? MP.yellow : Colors.white54,
                                  borderRadius: BorderRadius.circular(MP.rPill),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: MP.s5),
                        if (!last)
                          MpCtaButton(
                            key: const Key('onb-next'),
                            label: _i == 0 ? 'Começar' : 'Continuar',
                            onPressed: () => _page.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            ),
                          )
                        else ...[
                          MpCtaButton(
                            key: const Key('onb-login'),
                            label: 'Entrar com e-mail',
                            onPressed: _login,
                          ),
                          const SizedBox(height: MP.s3),
                          FilledButton(
                            key: const Key('onb-visitor'),
                            onPressed: widget.onDone,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: MP.ink,
                            ),
                            child: const Text('Entrar sem cadastro'),
                          ),
                        ],
                        TextButton(
                          onPressed: widget.onDone,
                          child: const Text(
                            'Pular apresentação',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
