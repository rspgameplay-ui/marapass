import 'package:flutter/material.dart';

import 'tokens.dart';

/// Cartão base do design system.
class MpCard extends StatelessWidget {
  const MpCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(MP.s4),
    this.color = MP.card,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Semantics(
      container: true,
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(MP.rLarge),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MP.rLarge),
            border: Border.all(color: MP.borderSubtle),
          ),
          child: onTap == null
              ? body
              : InkWell(
                  borderRadius: BorderRadius.circular(MP.rLarge),
                  onTap: onTap,
                  child: body,
                ),
        ),
      ),
    );
  }
}

/// Selo de status (pill).
class MpBadge extends StatelessWidget {
  const MpBadge(this.label, {super.key, this.fg = MP.green, this.bg});
  final String label;
  final Color fg;
  final Color? bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg ?? fg.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(MP.rPill),
    ),
    child: Text(
      label,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

/// Título de seção com ação opcional.
class MpSectionTitle extends StatelessWidget {
  const MpSectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontSize: 20),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: const Size(MP.minTap, MP.minTap),
          ),
          child: Text(
            action!,
            style: const TextStyle(
              color: MP.green,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}

/// Estado vazio: nunca usa vermelho (regra do design).
class MpEmpty extends StatelessWidget {
  const MpEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(MP.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: MP.subtle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: MP.navy),
          ),
          const SizedBox(height: MP.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MP.s2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: MP.s4),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

/// Falha real com recuperação clara.
class MpError extends StatelessWidget {
  const MpError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(MP.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: MP.error),
          const SizedBox(height: MP.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: MP.s4),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Carregamento simples e acessível.
class MpLoading extends StatelessWidget {
  const MpLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(MP.s6),
      child: CircularProgressIndicator(color: MP.green),
    ),
  );
}

/// Placeholder visual de foto: gradiente da marca com ícone.
class MpPhoto extends StatelessWidget {
  const MpPhoto({
    super.key,
    this.height = 140,
    this.icon = Icons.landscape_rounded,
    this.seed = 0,
  });
  final double height;
  final IconData icon;
  final int seed;
  @override
  Widget build(BuildContext context) {
    const palettes = [
      [MP.green, MP.navy],
      [MP.navy, MP.green],
      [MP.greenPressed, MP.gold],
    ];
    final p = palettes[seed.abs() % palettes.length];
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(MP.rLarge),
      ),
      child: Center(
        child: Icon(
          icon,
          size: height * .36,
          color: Colors.white.withValues(alpha: .85),
        ),
      ),
    );
  }
}

/// Botão com estado de processamento: impede toque repetido (regra de idempotência do design).
class MpPrimaryButton extends StatelessWidget {
  const MpPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label)),
            ],
          ),
  );
}

void showMpSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
