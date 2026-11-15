import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';

class ExperienceCard extends StatelessWidget {
  const ExperienceCard({
    super.key,
    required this.experience,
    required this.onTap,
    this.compact = false,
  });
  final Experience experience;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final x = experience;
    final meta = [
      if (x.establishment?.city != null) x.establishment!.city!,
      if (x.durationMinutes != null) formatDuration(x.durationMinutes!),
    ].join(' · ');
    return SizedBox(
      width: compact ? 240 : null,
      child: MpCard(
        onTap: onTap,
        padding: const EdgeInsets.all(MP.s3),
        semanticLabel: x.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MpPhoto(height: compact ? 110 : 140, seed: x.id.hashCode),
            const SizedBox(height: MP.s3),
            Text(
              x.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: MP.s1),
              Text(meta, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: MP.s2),
            Text(
              x.priceFromCents == null
                  ? 'Consulte o valor'
                  : 'a partir de ${formatBrl(x.priceFromCents!)}',
              style: const TextStyle(
                color: MP.green,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, required this.onTap});
  final Offer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    return MpCard(
      onTap: onTap,
      semanticLabel: '${o.title}, ${o.benefitLabel}',
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MP.gold.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(MP.rMedium),
            ),
            child: const Icon(
              Icons.local_activity_rounded,
              color: MP.gold,
              size: 28,
            ),
          ),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MP.s1),
                Text(
                  o.establishment?.name ?? 'Parceiro MaraPass',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: MP.s2),
                MpBadge(o.benefitLabel, fg: MP.gold),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: MP.textMuted),
        ],
      ),
    );
  }
}
