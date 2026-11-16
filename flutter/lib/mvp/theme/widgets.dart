import 'package:flutter/material.dart';

import 'tokens.dart';

/// Foto real do catálogo (assets/photos). Sem foto: gradiente da marca com ícone,
/// nunca um espaço vazio.
class MpPhoto extends StatelessWidget {
  const MpPhoto({
    super.key,
    this.photo,
    this.height = 160,
    this.radius = MP.rLarge,
    this.icon = Icons.landscape_rounded,
    this.seed = 0,
    this.child,
    this.darken = false,
  });
  final String? photo;
  final double? height;
  final double radius;
  final IconData icon;
  final int seed;
  final Widget? child;
  final bool darken;

  @override
  Widget build(BuildContext context) {
    const palettes = [
      [MP.green, MP.navy],
      [MP.navy, MP.green],
      [MP.greenPressed, MP.gold],
      [Color(0xff2f6f9f), MP.navy],
    ];
    final p = palettes[seed.abs() % palettes.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.asset(
                'assets/photos/$photo.jpg',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                semanticLabel: '',
                errorBuilder: (_, __, ___) =>
                    _Gradient(p: p, icon: icon, h: height),
              )
            else
              _Gradient(p: p, icon: icon, h: height),
            if (darken)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x22000000),
                      Color(0x00000000),
                      Color(0xcc000000),
                    ],
                    stops: [0, .4, 1],
                  ),
                ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _Gradient extends StatelessWidget {
  const _Gradient({required this.p, required this.icon, required this.h});
  final List<Color> p;
  final IconData icon;
  final double? h;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: p,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(
        icon,
        size: ((h ?? 160) * .32).clamp(28, 90),
        color: Colors.white.withValues(alpha: .85),
      ),
    ),
  );
}

class MpCard extends StatelessWidget {
  const MpCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(MP.s4),
    this.color = MP.card,
    this.semanticLabel,
    this.border = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final String? semanticLabel;
  final bool border;

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
            border: border && color == MP.card
                ? Border.all(color: MP.borderSubtle)
                : null,
            boxShadow: border && color == MP.card ? MP.shadowCard : null,
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

class MpBadge extends StatelessWidget {
  const MpBadge(
    this.label, {
    super.key,
    this.fg = MP.green,
    this.bg,
    this.icon,
  });
  final String label;
  final Color fg;
  final Color? bg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg ?? fg.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(MP.rPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class MpSectionTitle extends StatelessWidget {
  const MpSectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 22),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

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
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(MP.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: MP.soft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: MP.navy),
          ),
          const SizedBox(height: MP.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MP.s2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: MP.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: MP.s5),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

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
          const Icon(Icons.wifi_off_rounded, size: 44, color: MP.error),
          const SizedBox(height: MP.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
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

/// Botão principal com estado de processamento: impede toque repetido.
class MpPrimaryButton extends StatelessWidget {
  const MpPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.color,
    this.foreground,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: color == null
        ? null
        : FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: foreground ?? Colors.white,
          ),
    child: busy
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 22),
              ],
            ],
          ),
  );
}

/// Botão amarelo de destaque do protótipo aprovado ("Começar", "Reservar").
class MpCtaButton extends StatelessWidget {
  const MpCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.chevron_right_rounded,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => MpPrimaryButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    busy: busy,
    color: MP.yellow,
    foreground: MP.ink,
  );
}

/// Botão "‹ Voltar" em pílula, do protótipo aprovado.
class MpBackPill extends StatelessWidget {
  const MpBackPill({super.key, this.onDark = false, this.onPressed});
  final bool onDark;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Voltar',
    child: Material(
      color: onDark ? Colors.white : MP.soft,
      borderRadius: BorderRadius.circular(MP.rPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(MP.rPill),
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left_rounded, color: MP.ink),
              Text(
                'Voltar',
                style: TextStyle(
                  color: MP.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Cabeçalho padrão de tela interna: pílula Voltar + título grande.
class MpHeader extends StatelessWidget {
  const MpHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.back = true,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final bool back;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (back || trailing != null)
          Row(
            children: [if (back) const MpBackPill(), const Spacer(), ?trailing],
          ),
        if (back || trailing != null) const SizedBox(height: MP.s3),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: MP.s1),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: MP.textSecondary),
          ),
        ],
      ],
    ),
  );
}

/// Atalho quadrado com ícone sobre fundo pastel (Home do protótipo).
class MpShortcut extends StatelessWidget {
  const MpShortcut({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color tint;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(MP.rLarge),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MP.s3),
        decoration: BoxDecoration(
          border: Border.all(color: MP.border),
          borderRadius: BorderRadius.circular(MP.rLarge),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(MP.rMedium),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: MP.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Linha de informação com ícone (horário, endereço, telefone...).
class MpInfoRow extends StatelessWidget {
  const MpInfoRow(this.icon, this.text, {super.key, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(MP.rSmall),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MP.soft,
              borderRadius: BorderRadius.circular(MP.rSmall),
            ),
            child: Icon(icon, color: MP.navy, size: 22),
          ),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: MP.textMuted),
        ],
      ),
    ),
  );
}

/// Linha de lista com ícone, título, subtítulo e seta.
class MpListTile extends StatelessWidget {
  const MpListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color = MP.navy,
    this.tint = MP.soft,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color color;
  final Color tint;
  @override
  Widget build(BuildContext context) => MpCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: MP.s4, vertical: MP.s3),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(MP.rMedium),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: MP.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing ??
            (onTap != null
                ? const Icon(
                    Icons.chevron_right_rounded,
                    color: MP.textMuted,
                    size: 28,
                  )
                : const SizedBox()),
      ],
    ),
  );
}

/// Tela de estado (sucesso, enviado, bloqueado...). Explica o que aconteceu e
/// oferece uma saída clara, como pede o design.
class MpStatusScreen extends StatelessWidget {
  const MpStatusScreen({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.check_rounded,
    this.color = MP.success,
    this.bg = MP.successBg,
    this.details,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Color bg;
  final Widget? details;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(MP.pageH),
        children: [
          const SizedBox(height: MP.s8),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .6, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 56),
              ),
            ),
          ),
          const SizedBox(height: MP.s5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: MP.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: MP.textSecondary),
          ),
          if (details != null) ...[const SizedBox(height: MP.s5), details!],
          const SizedBox(height: MP.s8),
          FilledButton(
            key: const Key('status-primary'),
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: MP.s3),
            OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Faixa de 12 meses com a melhor época destacada (protótipo aprovado).
class MonthStrip extends StatelessWidget {
  const MonthStrip({super.key, required this.best});
  final List<int> best;
  static const _m = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];
  static const _full = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().month - 1;
    final ok = best.contains(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 12; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: best.contains(i) ? MP.green : MP.soft,
                    borderRadius: BorderRadius.circular(6),
                    border: i == now
                        ? Border.all(color: MP.ink, width: 2)
                        : null,
                  ),
                  child: Text(
                    _m[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: best.contains(i) ? Colors.white : MP.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: MP.s2),
        MpBadge(
          ok
              ? 'Agora (${_full[now]}) é boa época'
              : 'Agora (${_full[now]}) não é a melhor época',
          fg: ok ? MP.green : MP.warning,
          icon: ok ? Icons.wb_sunny_rounded : Icons.info_outline_rounded,
        ),
      ],
    );
  }
}

/// Estrelas de avaliação tocáveis.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 44,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          key: Key('star-$i'),
          tooltip: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
          iconSize: size,
          onPressed: () => onChanged(i),
          icon: Icon(
            i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i <= value ? MP.yellow : MP.border,
          ),
        ),
    ],
  );
}

/// Contador +/- grande.
class MpStepper extends StatelessWidget {
  const MpStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.keyPrefix = 'step',
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filledTonal(
        key: Key('$keyPrefix-minus'),
        tooltip: 'Diminuir',
        iconSize: 28,
        onPressed: value > min ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_rounded),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      ),
      SizedBox(
        width: 64,
        child: Text(
          '$value',
          key: Key('$keyPrefix-value'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      IconButton.filledTonal(
        key: Key('$keyPrefix-plus'),
        tooltip: 'Aumentar',
        iconSize: 28,
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_rounded),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      ),
    ],
  );
}

/// Aviso em caixa colorida (informação, atenção, demonstração).
class MpNotice extends StatelessWidget {
  const MpNotice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.fg = MP.info,
    this.bg = MP.infoBg,
  });
  const MpNotice.demo(this.text, {super.key})
    : icon = Icons.science_outlined,
      fg = MP.warning,
      bg = MP.warningBg;
  final String text;
  final IconData icon;
  final Color fg;
  final Color bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(MP.s4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(MP.rMedium),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: fg, size: 24),
        const SizedBox(width: MP.s3),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

void showMpSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Rota padrão.
Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
