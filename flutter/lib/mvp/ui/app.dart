import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/brand.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'login_screen.dart';
import 'shell.dart';

const _onboardedKey = 'mvp_onboarded_v1';

/// Raiz do app do turista: Splash → Onboarding → (Login opcional) → Início.
class MvpApp extends StatelessWidget {
  const MvpApp({super.key, this.splash = const Duration(milliseconds: 1100)});
  final Duration splash;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MaraPass',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: mvpTheme(),
    themeMode: ThemeMode.light,
    home: _Gate(splash: splash),
  );
}

class _Gate extends StatefulWidget {
  const _Gate({required this.splash});
  final Duration splash;
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    var seen = false;
    try {
      final p = await SharedPreferences.getInstance();
      seen = p.getBool(_onboardedKey) ?? false;
    } catch (_) {}
    if (widget.splash > Duration.zero) {
      await Future<void>.delayed(widget.splash);
    }
    if (mounted) setState(() => _onboarded = seen);
  }

  Future<void> _finishOnboarding() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_onboardedKey, true);
    } catch (_) {}
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    final o = _onboarded;
    if (o == null) return const _Splash();
    if (!o) return _Onboarding(onDone: _finishOnboarding);
    return const MvpShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: MP.page,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(painter: PinwheelPainter()),
          ),
          SizedBox(height: MP.s4),
          Text(
            'MaraPass',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: MP.navy,
            ),
          ),
          SizedBox(height: MP.s1),
          Text(
            'Maranhão infinito.',
            style: TextStyle(
              color: MP.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Onboarding extends ConsumerStatefulWidget {
  const _Onboarding({required this.onDone});
  final Future<void> Function() onDone;
  @override
  ConsumerState<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<_Onboarding> {
  final _page = PageController();
  int _i = 0;

  static const _slides = [
    (
      Icons.landscape_rounded,
      'Descubra o Maranhão',
      'Lençóis, Delta e muito mais: passeios, sabores e histórias reunidos em um só lugar.',
    ),
    (
      Icons.local_activity_rounded,
      'Benefícios de verdade',
      'Ative cupons em parceiros aprovados e apresente o QR na hora de usar.',
    ),
    (
      Icons.verified_rounded,
      'Seu passaporte digital',
      'Acompanhe seus benefícios e suas reservas sem papel e sem complicação.',
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
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text(
                  'Pular',
                  style: TextStyle(
                    color: MP.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MP.s6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MpPhoto(height: 220, icon: s.$1, seed: i),
                        const SizedBox(height: MP.s8),
                        Text(
                          s.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontSize: 30),
                        ),
                        const SizedBox(height: MP.s3),
                        Text(
                          s.$3,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: MP.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _i ? MP.green : MP.border,
                      borderRadius: BorderRadius.circular(MP.rPill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(MP.pageH),
              child: Column(
                children: [
                  if (!last)
                    FilledButton(
                      key: const Key('onb-next'),
                      onPressed: () => _page.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Continuar'),
                    )
                  else ...[
                    FilledButton(
                      key: const Key('onb-login'),
                      onPressed: _login,
                      child: const Text('Entrar com e-mail'),
                    ),
                    const SizedBox(height: MP.s3),
                    OutlinedButton(
                      key: const Key('onb-visitor'),
                      onPressed: widget.onDone,
                      child: const Text('Explorar sem cadastro'),
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
}
