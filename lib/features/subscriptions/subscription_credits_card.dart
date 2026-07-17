import 'package:flutter/material.dart';

import 'subscription_credit_service.dart';

const _orange = Color(0xFFFF6600);
const _blue = Color(0xFF1A73E8);
const _green = Color(0xFF138A46);
const _red = Color(0xFFC0392B);
const _muted = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class SubscriptionCreditsCard extends StatefulWidget {
  final String userId;
  final SubscriptionCreditService? service;

  const SubscriptionCreditsCard({
    super.key,
    required this.userId,
    this.service,
  });

  @override
  State<SubscriptionCreditsCard> createState() =>
      _SubscriptionCreditsCardState();
}

class _SubscriptionCreditsCardState extends State<SubscriptionCreditsCard> {
  late SubscriptionCreditService _service;
  late Future<SubscriptionCreditSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SubscriptionCreditService();
    _future = _service.getSnapshot();
  }

  @override
  void didUpdateWidget(covariant SubscriptionCreditsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final serviceChanged = oldWidget.service != widget.service;
    final userChanged = oldWidget.userId != widget.userId;
    if (serviceChanged) {
      _service = widget.service ?? SubscriptionCreditService();
    }
    if (serviceChanged || userChanged) {
      _future = _service.getSnapshot();
    }
  }

  void _reload() {
    final nextSnapshot = _service.getSnapshot();
    setState(() {
      _future = nextSnapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionCreditSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CreditsShell(
            child: SizedBox(
              height: 54,
              child: Center(
                child: Text(
                  'Chargement de vos crédits…',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _CreditsShell(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Impossible de charger vos crédits pour le moment.',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Réessayer',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded, color: _blue),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        return _CreditsShell(
          subtitle: data.freeAccessMode
              ? 'Accès illimité pendant la période gratuite.'
              : _resetLabel(data.nextResetAt),
          trailing: IconButton(
            tooltip: 'Actualiser mes crédits',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, color: _blue, size: 20),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CreditPill(
                label: 'Parcours',
                icon: Icons.route_rounded,
                status: data[SubscriptionCreditKind.journeys],
              ),
              _CreditPill(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                status: data[SubscriptionCreditKind.pdf],
              ),
              _CreditPill(
                label: 'IA vocale',
                icon: Icons.mic_rounded,
                status: data[SubscriptionCreditKind.voiceAi],
              ),
              _CreditPill(
                label: 'IA texte',
                icon: Icons.auto_awesome_rounded,
                status: data[SubscriptionCreditKind.textAi],
              ),
              _CreditPill(
                label: 'Annonces actives',
                icon: Icons.campaign_rounded,
                status: data[SubscriptionCreditKind.activeOffers],
              ),
            ],
          ),
        );
      },
    );
  }
}

class SubscriptionCreditsInlineBadges extends StatefulWidget {
  final List<SubscriptionCreditKind> kinds;
  final SubscriptionCreditService? service;

  const SubscriptionCreditsInlineBadges({
    super.key,
    required this.kinds,
    this.service,
  });

  @override
  State<SubscriptionCreditsInlineBadges> createState() =>
      _SubscriptionCreditsInlineBadgesState();
}

class _SubscriptionCreditsInlineBadgesState
    extends State<SubscriptionCreditsInlineBadges> {
  late SubscriptionCreditService _service;
  late Future<SubscriptionCreditSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SubscriptionCreditService();
    _future = _service.getSnapshot();
  }

  @override
  void didUpdateWidget(covariant SubscriptionCreditsInlineBadges oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _service = widget.service ?? SubscriptionCreditService();
      _future = _service.getSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionCreditSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final kind in widget.kinds)
              SubscriptionCreditBadge(
                label: _labelFor(kind),
                status: data[kind],
              ),
          ],
        );
      },
    );
  }
}

class SubscriptionCreditBadge extends StatelessWidget {
  final String label;
  final SubscriptionCreditStatus status;

  const SubscriptionCreditBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label · ${status.compactLabel}',
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CreditsShell extends StatelessWidget {
  final Widget child;
  final String? subtitle;
  final Widget? trailing;

  const _CreditsShell({
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.toll_rounded, color: _orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mes crédits',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CreditPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final SubscriptionCreditStatus status;

  const _CreditPill({
    required this.label,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final detail = status.unlimited
        ? 'Illimité'
        : status.limit <= 0
            ? 'Non inclus'
            : '${status.remaining} restant${status.remaining > 1 ? 's' : ''} sur ${status.limit}';
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(SubscriptionCreditStatus status) {
  if (status.unlimited) return _green;
  if (status.limit <= 0 || status.exhausted) return _red;
  if (status.remaining / status.limit <= 0.25) return _orange;
  return _blue;
}

String _labelFor(SubscriptionCreditKind kind) {
  switch (kind) {
    case SubscriptionCreditKind.journeys:
      return 'Parcours';
    case SubscriptionCreditKind.pdf:
      return 'PDF';
    case SubscriptionCreditKind.voiceAi:
      return 'IA vocale';
    case SubscriptionCreditKind.textAi:
      return 'IA texte';
    case SubscriptionCreditKind.activeOffers:
      return 'Annonces';
  }
}

String _resetLabel(DateTime? date) {
  if (date == null) return 'Crédits mensuels actualisés automatiquement.';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return 'Crédits mensuels renouvelés le $day/$month.';
}
