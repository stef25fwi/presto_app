import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/friendly_snackbar.dart';
import 'subscription_action_placeholders.dart';
import 'subscription_config_service.dart';
import 'subscription_models.dart';

const Color _kSubscriptionOrange = Color(0xFFFF6600);
const Color _kSubscriptionBlue = Color(0xFF1A73E8);
const Color _kSubscriptionBackground = Color(0xFFF7F8FA);
const Color _kSubscriptionTextPrimary = Color(0xFF111827);
const Color _kSubscriptionTextSecondary = Color(0xFF6B7280);
const Color _kSubscriptionGreen = Color(0xFF138A46);
const Color _kSubscriptionBorder = Color(0xFFE5E7EB);

class SubscriptionSection extends StatelessWidget {
  final String userId;
  final SubscriptionConfigService? service;

  const SubscriptionSection({
    super.key,
    required this.userId,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final configService = service ?? SubscriptionConfigService();

    return StreamBuilder<SubscriptionAppConfig>(
      stream: configService.watchConfig(),
      builder: (context, configSnapshot) {
        if (configSnapshot.hasError) {
          return const SizedBox.shrink();
        }

        final config =
            configSnapshot.data ?? const SubscriptionAppConfig.defaults();
        if (!config.subscriptionSectionEnabled) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, userSnapshot) {
            final userState = AppUserSubscriptionState.fromMap(
              userSnapshot.data?.data(),
            );

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _kSubscriptionBackground,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _kSubscriptionBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SubscriptionSectionHeader(),
                  const SizedBox(height: 18),
                  SubscriptionCurrentStatusCard(
                    userState: userState,
                    config: config,
                  ),
                  const SizedBox(height: 18),
                  SubscriptionPlanTabs(
                    config: config,
                    userState: userState,
                  ),
                  const SizedBox(height: 14),
                  const _SubscriptionFooterNote(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SubscriptionSectionHeader extends StatelessWidget {
  const _SubscriptionSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _kSubscriptionBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: _kSubscriptionBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mon abonnement iliprestō',
                style: TextStyle(
                  fontSize: 22,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: _kSubscriptionTextPrimary,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Gérez votre formule, vos avantages et vos options.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: _kSubscriptionTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SubscriptionCurrentStatusCard extends StatelessWidget {
  final AppUserSubscriptionState userState;
  final SubscriptionAppConfig config;

  const SubscriptionCurrentStatusCard({
    super.key,
    required this.userState,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final plan = _planPresentationFor(userState.plan);
    final nextPlan = _nextUpgradePlan(userState.plan);
    final isTopPlan = nextPlan == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            plan.accent.withValues(alpha: 0.08),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: plan.accent.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: plan.accent.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SubscriptionBadge(
                label: 'FORMULE ACTUELLE',
                color: _kSubscriptionBlue,
                filled: false,
              ),
              const Spacer(),
              const _SubscriptionBadge(
                label: '✓ Actif',
                color: _kSubscriptionGreen,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanIconBubble(
                icon: plan.icon,
                color: plan.accent,
                size: 62,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 25,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: _kSubscriptionTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      plan.price,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: plan.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.currentSummary,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: _kSubscriptionTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: plan.accent.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final showColumns = constraints.maxWidth >= 620;
              final advantages = _BenefitColumn(
                title: 'Avantages :',
                icon: Icons.check_circle_outline_rounded,
                color: _kSubscriptionBlue,
                items: plan.currentAdvantages,
              );
              final limits = _BenefitColumn(
                title: userState.plan == SubscriptionPlan.ilipro
                    ? 'Premium :'
                    : 'Limites :',
                icon: userState.plan == SubscriptionPlan.ilipro
                    ? Icons.workspace_premium_rounded
                    : Icons.remove_circle_rounded,
                color: userState.plan == SubscriptionPlan.ilipro
                    ? _kSubscriptionOrange
                    : _kSubscriptionOrange,
                items: plan.currentLimits,
              );

              if (showColumns) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: advantages),
                    Container(
                      width: 1,
                      height: 98,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: _kSubscriptionBorder,
                    ),
                    Expanded(child: limits),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  advantages,
                  const SizedBox(height: 12),
                  limits,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isTopPlan
                  ? () => openSubscriptionManagement(
                        context,
                        stripeEnabled: config.stripeEnabled,
                        source: 'account_current_ilipro_manage',
                      )
                  : () => _handleSubscriptionPlanAction(
                        context,
                        config,
                        nextPlan,
                        source: 'account_current_upgrade',
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: isTopPlan ? _kSubscriptionOrange : _kSubscriptionBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isTopPlan
                        ? 'Gérer mon abonnement'
                        : 'Passer à ${subscriptionPlanLabel(nextPlan)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionPlanTabs extends StatelessWidget {
  final SubscriptionAppConfig config;
  final AppUserSubscriptionState userState;

  const SubscriptionPlanTabs({
    super.key,
    required this.config,
    required this.userState,
  });

  @override
  Widget build(BuildContext context) {
    return _SubscriptionPlansComparison(
      config: config,
      userState: userState,
    );
  }
}

class _SubscriptionPlansComparison extends StatelessWidget {
  final SubscriptionAppConfig config;
  final AppUserSubscriptionState userState;

  const _SubscriptionPlansComparison({
    required this.config,
    required this.userState,
  });

  @override
  Widget build(BuildContext context) {
    final cards = _subscriptionPlanPresentations
        .map(
          (plan) => _SubscriptionPlanCard(
            presentation: plan,
            currentPlan: userState.plan,
            config: config,
          ),
        )
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 940) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final _PlanPresentation presentation;
  final SubscriptionPlan currentPlan;
  final SubscriptionAppConfig config;

  const _SubscriptionPlanCard({
    required this.presentation,
    required this.currentPlan,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = presentation.plan == currentPlan;
    final isFree = presentation.plan == SubscriptionPlan.free;
    final actionColor = isCurrent
        ? _kSubscriptionTextSecondary
        : presentation.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: presentation.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCurrent
              ? _kSubscriptionBorder
              : presentation.accent.withValues(alpha: 0.75),
          width: presentation.isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (presentation.isHighlighted ? presentation.accent : Colors.black)
                .withValues(alpha: presentation.isHighlighted ? 0.10 : 0.04),
            blurRadius: presentation.isHighlighted ? 16 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanIconBubble(
                    icon: presentation.icon,
                    color: isCurrent && !presentation.isHighlighted
                        ? _kSubscriptionTextSecondary
                        : presentation.accent,
                    size: compact ? 50 : 58,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              presentation.title,
                              style: TextStyle(
                                fontSize: compact ? 19 : 21,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                color: presentation.accent,
                              ),
                            ),
                            if (presentation.badge != null)
                              _SubscriptionBadge(
                                label: presentation.badge!,
                                color: presentation.accent,
                                filled: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          presentation.price,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: presentation.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          presentation.summary,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.28,
                            fontWeight: FontWeight.w500,
                            color: _kSubscriptionTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 9,
                children: presentation.features
                    .map(
                      (feature) => _CompactFeaturePill(
                        label: feature,
                        color: presentation.accent,
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: isCurrent
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Offre actuelle',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      )
                    : FilledButton(
                        onPressed: () => isFree
                            ? openSubscriptionManagement(
                                context,
                                stripeEnabled: config.stripeEnabled,
                                source: 'account_plan_free_manage',
                              )
                            : _handleSubscriptionPlanAction(
                                context,
                                config,
                                presentation.plan,
                                source:
                                    'account_plan_${subscriptionPlanKey(presentation.plan)}_select',
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _buttonLabelFor(presentation.plan),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (!isFree) ...[
                              const SizedBox(width: 7),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BenefitColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _BenefitColumn({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 9),
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                    color: _kSubscriptionTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CompactFeaturePill extends StatelessWidget {
  final String label;
  final Color color;

  const _CompactFeaturePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: _kSubscriptionTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanIconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PlanIconBubble({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.48,
      ),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _SubscriptionBadge({
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

class _SubscriptionFooterNote extends StatelessWidget {
  const _SubscriptionFooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kSubscriptionBorder),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: _kSubscriptionBlue,
            size: 24,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sans engagement, vous pouvez changer de formule à tout moment.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _kSubscriptionTextPrimary,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: _kSubscriptionBlue,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _PlanPresentation {
  final SubscriptionPlan plan;
  final String title;
  final String price;
  final String summary;
  final String currentSummary;
  final String? badge;
  final IconData icon;
  final Color accent;
  final Color cardBackground;
  final bool isHighlighted;
  final List<String> features;
  final List<String> currentAdvantages;
  final List<String> currentLimits;

  const _PlanPresentation({
    required this.plan,
    required this.title,
    required this.price,
    required this.summary,
    required this.currentSummary,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.cardBackground,
    required this.isHighlighted,
    required this.features,
    required this.currentAdvantages,
    required this.currentLimits,
  });
}

const List<_PlanPresentation> _subscriptionPlanPresentations = [
  _PlanPresentation(
    plan: SubscriptionPlan.free,
    title: 'Gratuit',
    price: '0 €/mois',
    summary: 'Pour découvrir la plateforme sans engagement.',
    currentSummary:
        'Idéal pour découvrir iliprestō et tester les premières fonctionnalités.',
    badge: null,
    icon: Icons.card_giftcard_rounded,
    accent: _kSubscriptionBlue,
    cardBackground: Colors.white,
    isHighlighted: false,
    features: [
      'Publier une annonce simple',
      'Consulter les annonces',
      'Tester 1 annonce IA',
      'Sauvegarder 1 parcours / mois',
    ],
    currentAdvantages: [
      '1 annonce IA offerte',
      '1 parcours sauvegardé / mois',
      'Consultation des annonces',
      'Accès aux fonctions de base',
    ],
    currentLimits: [
      'Pas d’export PDF',
      'Options premium désactivées',
    ],
  ),
  _PlanPresentation(
    plan: SubscriptionPlan.iliprestoPlus,
    title: 'iliprestō+',
    price: '1,99 €/mois',
    summary: 'Plus de confort pour utiliser iliprestō au quotidien.',
    currentSummary:
        'La formule accessible pour sauvegarder, exporter et utiliser plus d’options pratiques.',
    badge: 'Le plus accessible',
    icon: Icons.star_rounded,
    accent: _kSubscriptionBlue,
    cardBackground: Color(0xFFF2F7FF),
    isHighlighted: true,
    features: [
      '2 exports PDF / mois',
      'PDF avec logo iliprestō',
      'Sauvegarde locale',
      'Plus d’options pratiques',
    ],
    currentAdvantages: [
      'Sauvegarde locale des parcours',
      '2 exports PDF par mois',
      'PDF avec logo iliprestō',
      'Expérience utilisateur améliorée',
    ],
    currentLimits: [
      'Quota PDF mensuel limité',
      'Options professionnelles réservées à ilipro',
    ],
  ),
  _PlanPresentation(
    plan: SubscriptionPlan.ilipro,
    title: 'ilipro',
    price: '9,99 €/mois',
    summary:
        'Pour les pros qui veulent recevoir plus d’opportunités.',
    currentSummary:
        'La formule pro pour renforcer votre visibilité et recevoir plus de demandes.',
    badge: 'Pour les pros',
    icon: Icons.business_center_rounded,
    accent: _kSubscriptionOrange,
    cardBackground: Color(0xFFFFF6EF),
    isHighlighted: true,
    features: [
      'Visibilité renforcée',
      'Alertes annonces',
      'Jusqu’à 10 photos',
      'Outils pro',
    ],
    currentAdvantages: [
      'Visibilité professionnelle renforcée',
      'Alertes sur les annonces pertinentes',
      'Jusqu’à 10 photos par annonce',
      'Outils pour développer son activité',
    ],
    currentLimits: [
      'Vous profitez déjà de la meilleure formule iliprestō.',
      'Les options premium pro sont activées.',
    ],
  ),
];

_PlanPresentation _planPresentationFor(SubscriptionPlan plan) {
  return _subscriptionPlanPresentations.firstWhere(
    (presentation) => presentation.plan == plan,
    orElse: () => _subscriptionPlanPresentations.first,
  );
}

SubscriptionPlan? _nextUpgradePlan(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.free:
      return SubscriptionPlan.iliprestoPlus;
    case SubscriptionPlan.iliprestoPlus:
      return SubscriptionPlan.ilipro;
    case SubscriptionPlan.ilipro:
      return null;
  }
}

String _buttonLabelFor(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.free:
      return 'Choisir Gratuit';
    case SubscriptionPlan.iliprestoPlus:
      return 'Choisir iliprestō+';
    case SubscriptionPlan.ilipro:
      return 'Choisir ilipro';
  }
}

Future<void> _handleSubscriptionPlanAction(
  BuildContext context,
  SubscriptionAppConfig config,
  SubscriptionPlan plan, {
  required String source,
}) async {
  final planKey = subscriptionPlanKey(plan);
  if (config.stripeEnabled) {
    await startSubscriptionCheckout(
      context,
      planKey,
      stripeEnabled: config.stripeEnabled,
      source: source,
    );
    return;
  }

  await notifySubscriptionLaunch(
    context,
    planKey,
    stripeEnabled: config.stripeEnabled,
    source: source,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Les abonnements seront bientôt disponibles.'),
      ),
    );
}

class AdminSubscriptionTile extends StatefulWidget {
  final SubscriptionConfigService? service;

  const AdminSubscriptionTile({
    super.key,
    this.service,
  });

  @override
  State<AdminSubscriptionTile> createState() => _AdminSubscriptionTileState();
}

class _AdminSubscriptionTileState extends State<AdminSubscriptionTile> {
  bool _saving = false;

  SubscriptionConfigService get _service =>
      widget.service ?? SubscriptionConfigService();

  @override
  void initState() {
    super.initState();
    unawaited(
      _service.ensureDefaultConfigExists(
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      ),
    );
  }

  Future<void> _toggleSectionVisibility(bool enabled) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await _service.updateSectionVisibility(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Visibilité de la section abonnement mise à jour.',
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
          context, 'Impossible de mettre à jour la configuration.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleFreeAccessMode(bool enabled) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await _service.updateFreeAccessMode(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        enabled
            ? 'Accès gratuit complet réactivé.'
            : 'Mode restrictions préparées activé.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible de mettre à jour freeAccessMode.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SubscriptionAppConfig>(
      stream: _service.watchConfig(ensureExists: true),
      builder: (context, snapshot) {
        final config = snapshot.data ?? const SubscriptionAppConfig.defaults();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kSubscriptionOrange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: _kSubscriptionOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Abonnements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kSubscriptionTextPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Préparer et afficher les offres iliprestō+ et ilipro.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kSubscriptionTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Afficher la section abonnement dans le profil',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kSubscriptionTextPrimary,
                  ),
                ),
                subtitle: Text(
                  config.subscriptionSectionEnabled
                      ? 'La section est visible sur la page compte.'
                      : 'La section reste masquée sur la page compte.',
                  style: const TextStyle(color: _kSubscriptionTextSecondary),
                ),
                value: config.subscriptionSectionEnabled,
                onChanged: _saving ? null : _toggleSectionVisibility,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'freeAccessMode',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kSubscriptionTextPrimary,
                  ),
                ),
                subtitle: Text(
                  config.freeAccessMode
                      ? 'Aucune restriction abonnement n’est appliquée aux utilisateurs.'
                      : 'Les limites Gratuit vs iliprestō+ sont maintenant actives dans l’app.',
                  style: const TextStyle(color: _kSubscriptionTextSecondary),
                ),
                value: config.freeAccessMode,
                onChanged: _saving ? null : _toggleFreeAccessMode,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStatusChip(
                    label: config.stripeEnabled
                        ? 'Stripe : activé'
                        : 'Stripe : non activé',
                    color: config.stripeEnabled
                        ? Colors.green.shade700
                        : _kSubscriptionTextSecondary,
                  ),
                  _MiniStatusChip(
                    label: config.freeAccessMode
                        ? 'Accès gratuit complet : actif'
                        : 'Accès gratuit complet : inactif',
                    color: config.freeAccessMode
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  _MiniStatusChip(
                    label: config.subscriptionsPrepared
                        ? 'Architecture prête'
                        : 'Préparation incomplète',
                    color: _kSubscriptionBlue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Text(
                  'Stripe peut rester inactif : freeAccessMode permet déjà de préparer ou d’activer les règles d’accès côté app sans ouvrir le paiement.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: _kSubscriptionTextSecondary,
                  ),
                ),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  'La lecture Firestore a échoué, les valeurs par défaut restent affichées.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
