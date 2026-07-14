import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/friendly_snackbar.dart';
import 'subscription_action_placeholders.dart';
import 'subscription_config_service.dart';
import 'subscription_models.dart';

const Color _orange = Color(0xFFFF6600);
const Color _blue = Color(0xFF1A73E8);
const Color _background = Color(0xFFF7F8FA);
const Color _text = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _green = Color(0xFF138A46);
const Color _border = Color(0xFFE5E7EB);

enum OfferAudience { particuliers, pro }

class SubscriptionSection extends StatelessWidget {
  final String userId;
  final SubscriptionConfigService? service;

  const SubscriptionSection({super.key, required this.userId, this.service});

  @override
  Widget build(BuildContext context) {
    final configService = service ?? SubscriptionConfigService();
    return StreamBuilder<SubscriptionAppConfig>(
      stream: configService.watchConfig(),
      builder: (context, configSnapshot) {
        if (configSnapshot.hasError) return const SizedBox.shrink();
        final config =
            configSnapshot.data ?? const SubscriptionAppConfig.defaults();
        if (!config.subscriptionSectionEnabled) return const SizedBox.shrink();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, userSnapshot) {
            final userState = AppUserSubscriptionState.fromMap(
              userSnapshot.data?.data(),
            );
            if (config.stripeEnabled &&
                userState.plan == SubscriptionPlan.free) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(
                  prefetchSubscriptionCheckout(
                    subscriptionPlanKey(SubscriptionPlan.iliprestoPlus),
                    stripeEnabled: true,
                    source: 'account_subscription_overview_prefetch',
                  ),
                );
              });
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
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
                  const _Header(
                    title: 'Mon abonnement iliprestō',
                    subtitle:
                        'Gérez votre formule, vos avantages et vos options.',
                  ),
                  const SizedBox(height: 10),
                  SubscriptionCurrentStatusCard(
                    userId: userId,
                    userState: userState,
                    config: config,
                    service: configService,
                  ),
                  const SizedBox(height: 10),
                  const _FooterNote(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class SubscriptionDetailsPage extends StatefulWidget {
  final String userId;
  final SubscriptionConfigService? service;

  const SubscriptionDetailsPage({
    super.key,
    required this.userId,
    this.service,
  });

  @override
  State<SubscriptionDetailsPage> createState() =>
      _SubscriptionDetailsPageState();
}

class _SubscriptionDetailsPageState extends State<SubscriptionDetailsPage> {
  OfferAudience _audience = OfferAudience.particuliers;
  final Set<SubscriptionPlan> _prefetchScheduled = <SubscriptionPlan>{};

  void _scheduleCheckoutPrefetch({
    required SubscriptionAppConfig config,
    required AppUserSubscriptionState userState,
  }) {
    final targetPlan = _audience == OfferAudience.particuliers
        ? SubscriptionPlan.iliprestoPlus
        : SubscriptionPlan.ilipro;
    if (!config.stripeEnabled ||
        targetPlan == userState.plan ||
        !_prefetchScheduled.add(targetPlan)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        prefetchSubscriptionCheckout(
          subscriptionPlanKey(targetPlan),
          stripeEnabled: true,
          source: 'account_subscription_details_prefetch',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final configService = widget.service ?? SubscriptionConfigService();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        centerTitle: true,
        title: const Text(
          'Mon abonnement iliprestō',
          style: TextStyle(color: _blue, fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<SubscriptionAppConfig>(
        stream: configService.watchConfig(),
        builder: (context, configSnapshot) {
          final config =
              configSnapshot.data ?? const SubscriptionAppConfig.defaults();
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, userSnapshot) {
              final userState = AppUserSubscriptionState.fromMap(
                userSnapshot.data?.data(),
              );
              _scheduleCheckoutPrefetch(config: config, userState: userState);
              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SubscriptionCurrentStatusCard(
                            userId: widget.userId,
                            userState: userState,
                            config: config,
                            service: configService,
                            showDetailsButton: false,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Découvrez les offres',
                            style: TextStyle(
                              color: _text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Choisissez votre profil pour afficher uniquement les formules qui vous concernent.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _AudienceSelector(
                            audience: _audience,
                            onChanged: (value) =>
                                setState(() => _audience = value),
                          ),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: SubscriptionPlanTabs(
                              key: ValueKey(_audience),
                              config: config,
                              userState: userState,
                              audience: _audience,
                              showCurrentPlan: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const _FooterNote(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AudienceSelector extends StatelessWidget {
  final OfferAudience audience;
  final ValueChanged<OfferAudience> onChanged;

  const _AudienceSelector({required this.audience, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AudienceButton(
              label: 'Particuliers',
              icon: Icons.person_rounded,
              selected: audience == OfferAudience.particuliers,
              color: _blue,
              onTap: () => onChanged(OfferAudience.particuliers),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _AudienceButton(
              label: 'Pro',
              icon: Icons.business_center_rounded,
              selected: audience == OfferAudience.pro,
              color: _orange,
              onTap: () => onChanged(OfferAudience.pro),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AudienceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: color.withValues(alpha: 0.45))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : _muted, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionCurrentStatusCard extends StatelessWidget {
  final String userId;
  final AppUserSubscriptionState userState;
  final SubscriptionAppConfig config;
  final SubscriptionConfigService? service;
  final bool showDetailsButton;

  const SubscriptionCurrentStatusCard({
    super.key,
    required this.userId,
    required this.userState,
    required this.config,
    this.service,
    this.showDetailsButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final plan = _planFor(userState.plan);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [plan.accent.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.accent.withValues(alpha: 0.38),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _Badge(label: 'OFFRE ACTUELLE', color: _blue),
              Spacer(),
              _Badge(label: '✓ Actif', color: _green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanIcon(icon: plan.icon, color: plan.accent, size: 62),
              const SizedBox(width: 10),
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
                        color: _text,
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
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BenefitList(items: plan.currentAdvantages, color: plan.accent),
          if (showDetailsButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SubscriptionDetailsPage(
                      userId: userId,
                      service: service,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Découvrir les autres offres',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SubscriptionPlanTabs extends StatelessWidget {
  final SubscriptionAppConfig config;
  final AppUserSubscriptionState userState;
  final bool showCurrentPlan;
  final OfferAudience audience;

  const SubscriptionPlanTabs({
    super.key,
    required this.config,
    required this.userState,
    this.showCurrentPlan = false,
    this.audience = OfferAudience.particuliers,
  });

  @override
  Widget build(BuildContext context) {
    final plans = _plans.where((plan) {
      final audienceMatches = audience == OfferAudience.particuliers
          ? plan.plan != SubscriptionPlan.ilipro
          : plan.plan == SubscriptionPlan.ilipro;
      return audienceMatches &&
          (showCurrentPlan || plan.plan != userState.plan);
    }).toList(growable: false);

    return Column(
      children: [
        for (var i = 0; i < plans.length; i++) ...[
          _PlanCard(
            presentation: plans[i],
            currentPlan: userState.plan,
            config: config,
          ),
          if (i != plans.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanPresentation presentation;
  final SubscriptionPlan currentPlan;
  final SubscriptionAppConfig config;

  const _PlanCard({
    required this.presentation,
    required this.currentPlan,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = presentation.plan == currentPlan;
    final isFree = presentation.plan == SubscriptionPlan.free;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: presentation.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? _green.withValues(alpha: 0.50)
              : presentation.accent.withValues(alpha: 0.65),
          width: presentation.highlighted ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: presentation.accent.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanIcon(
                icon: presentation.icon,
                color: presentation.accent,
                size: 54,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: presentation.accent,
                          ),
                        ),
                        if (isCurrent)
                          const _Badge(label: 'ACTUELLE', color: _green)
                        else if (presentation.badge != null)
                          _Badge(
                            label: presentation.badge!,
                            color: presentation.accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      presentation.price,
                      style: TextStyle(
                        color: presentation.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      presentation.summary,
                      style: const TextStyle(
                        color: _muted,
                        height: 1.35,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BenefitList(
            items: presentation.features,
            color: presentation.accent,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Offre actuelle'),
                  )
                : FilledButton(
                    onPressed: () => isFree
                        ? openSubscriptionManagement(
                            context,
                            stripeEnabled: config.stripeEnabled,
                            source: 'account_plan_free_manage',
                          )
                        : _handlePlanAction(context, config, presentation.plan),
                    style: FilledButton.styleFrom(
                      backgroundColor: presentation.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      _buttonLabel(presentation.plan),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _BenefitList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: _blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PlanIcon({
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
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: _blue, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sans engagement, vous pouvez changer de formule à tout moment.',
              style: TextStyle(
                color: _text,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
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
  final bool highlighted;
  final List<String> features;
  final List<String> currentAdvantages;

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
    required this.highlighted,
    required this.features,
    required this.currentAdvantages,
  });
}

const List<_PlanPresentation> _plans = [
  _PlanPresentation(
    plan: SubscriptionPlan.free,
    title: 'Gratuit',
    price: '0 €/mois',
    summary: 'Pour découvrir iliprestō sans engagement.',
    currentSummary: 'La formule essentielle pour commencer sur iliprestō.',
    badge: null,
    icon: Icons.card_giftcard_rounded,
    accent: _blue,
    cardBackground: Colors.white,
    highlighted: false,
    features: [
      '3 annonces actives',
      '1 photo par annonce',
      '2 créations d’annonce avec l’IA',
      '1 création d’annonce avec l’IA vocale',
      'Consultation des annonces et messagerie',
      '1 parcours création d’entreprise sauvegardé par mois',
      'Pas d’export PDF du parcours',
    ],
    currentAdvantages: [
      'Publier et consulter des annonces',
      'Tester les outils IA iliprestō',
      'Sauvegarder 1 parcours par mois',
    ],
  ),
  _PlanPresentation(
    plan: SubscriptionPlan.iliprestoPlus,
    title: 'iliprestō+',
    price: '1,99 €/mois',
    summary: 'La formule particuliers avec davantage de confort et d’outils.',
    currentSummary:
        'Plus de possibilités pour publier, sauvegarder et exporter vos parcours.',
    badge: 'Particuliers',
    icon: Icons.star_rounded,
    accent: _blue,
    cardBackground: Color(0xFFF2F7FF),
    highlighted: true,
    features: [
      'Davantage d’annonces actives',
      'Plus de photos par annonce',
      'Créations d’annonces IA supplémentaires',
      'Créations d’annonces avec l’IA vocale',
      'Alertes sur les annonces favorites',
      'Sauvegarde locale des parcours',
      '2 exports PDF par mois',
      'PDF avec logo et filigrane iliprestō',
    ],
    currentAdvantages: [
      'Sauvegarde locale des parcours',
      '2 exports PDF par mois',
      'Alertes et outils supplémentaires',
    ],
  ),
  _PlanPresentation(
    plan: SubscriptionPlan.ilipro,
    title: 'ilipro',
    price: '9,99 €/mois',
    summary: 'La formule complète dédiée aux professionnels.',
    currentSummary:
        'Développez votre visibilité et recevez davantage d’opportunités.',
    badge: 'Professionnels',
    icon: Icons.business_center_rounded,
    accent: _orange,
    cardBackground: Color(0xFFFFF6EF),
    highlighted: true,
    features: [
      'Toutes les fonctions iliprestō+',
      'Davantage d’annonces actives',
      'Jusqu’à 10 photos par annonce',
      'Créations d’annonces IA et IA vocale renforcées',
      'Alertes instantanées sur les demandes pertinentes',
      'Statistiques de consultation et de performance',
      'Profil professionnel enrichi',
      'Visibilité prioritaire dans les résultats',
      'Outils conçus pour développer votre activité',
    ],
    currentAdvantages: [
      'Visibilité professionnelle renforcée',
      'Alertes sur les annonces pertinentes',
      'Jusqu’à 10 photos par annonce',
      'Statistiques et profil professionnel enrichi',
    ],
  ),
];

_PlanPresentation _planFor(SubscriptionPlan plan) =>
    _plans.firstWhere((item) => item.plan == plan, orElse: () => _plans.first);

String _buttonLabel(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.free:
      return 'Choisir Gratuit';
    case SubscriptionPlan.iliprestoPlus:
      return 'Choisir iliprestō+';
    case SubscriptionPlan.ilipro:
      return 'Choisir ilipro';
  }
}

Future<void> _handlePlanAction(
  BuildContext context,
  SubscriptionAppConfig config,
  SubscriptionPlan plan,
) async {
  final planKey = subscriptionPlanKey(plan);
  final source = 'account_plan_${subscriptionPlanKey(plan)}_select';
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
}

class AdminSubscriptionTile extends StatefulWidget {
  final SubscriptionConfigService? service;

  const AdminSubscriptionTile({super.key, this.service});

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

  Future<void> _toggleVisibility(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.updateSectionVisibility(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Visibilité des abonnements mise à jour.');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Impossible de mettre à jour la configuration.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleFreeAccess(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.updateFreeAccessMode(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Mode d’accès abonnement mis à jour.');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Impossible de mettre à jour freeAccessMode.',
        );
      }
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
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(
                title: 'Abonnements',
                subtitle: 'Pilotez l’affichage et les règles des formules.',
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Afficher la section abonnement'),
                value: config.subscriptionSectionEnabled,
                onChanged: _saving ? null : _toggleVisibility,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accès gratuit complet'),
                subtitle: const Text(
                  'Désactivez-le pour appliquer les limites des formules.',
                ),
                value: config.freeAccessMode,
                onChanged: _saving ? null : _toggleFreeAccess,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AdminChip(
                    label: config.stripeEnabled
                        ? 'Stripe activé'
                        : 'Stripe non activé',
                    color: config.stripeEnabled ? _green : _muted,
                  ),
                  _AdminChip(
                    label: config.subscriptionsPrepared
                        ? 'Architecture prête'
                        : 'Préparation incomplète',
                    color: _blue,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminChip extends StatelessWidget {
  final String label;
  final Color color;

  const _AdminChip({required this.label, required this.color});

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
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
