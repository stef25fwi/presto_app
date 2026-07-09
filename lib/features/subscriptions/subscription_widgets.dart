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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mon abonnement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kSubscriptionTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Découvrez les formules iliprestō+ et ilipro. 0 % de commission : vous gardez toujours 100 % de vos gains. Les abonnements seront activés prochainement.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kSubscriptionTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SubscriptionLaunchBanner(),
                  const SizedBox(height: 14),
                  SubscriptionCurrentStatusCard(
                    userState: userState,
                    config: config,
                  ),
                  const SizedBox(height: 18),
                  SubscriptionPlanTabs(
                    config: config,
                    userState: userState,
                  ),
                ],
              ),
            );
          },
        );
      },
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
    final features = getFeaturesForSubscriptionPlan(
      userState.plan,
      freeAccessMode: config.freeAccessMode,
    );
    final messagingEntitlements = getConversationAttachmentEntitlements(
      userState.plan,
      freeAccessMode: config.freeAccessMode,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD7BF)),
        boxShadow: [
          BoxShadow(
            color: _kSubscriptionOrange.withValues(alpha: 0.10),
            blurRadius: 16,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kSubscriptionOrange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Bientôt disponible',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _kSubscriptionOrange,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kSubscriptionBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Plan actuel : ${subscriptionPlanLabel(userState.plan)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _kSubscriptionBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Accès gratuit actuellement actif',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kSubscriptionTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pour le moment, toutes les fonctionnalités de l’application restent accessibles sans abonnement. Les offres ci-dessous sont en préparation et seront activées prochainement.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: _kSubscriptionTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatusChip(
                label: config.freeAccessMode
                    ? 'Accès gratuit complet : actif'
                    : 'Restrictions futures prêtes',
                color: Colors.green.shade700,
              ),
              _MiniStatusChip(
                label: userState.phoneVerified
                    ? 'Téléphone vérifié'
                    : 'Téléphone vérifiable plus tard',
                color: _kSubscriptionBlue,
              ),
              _MiniStatusChip(
                label: features.canAccessStats
                    ? 'Architecture premium prête'
                    : 'Architecture évolutive prête',
                color: _kSubscriptionOrange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SubscriptionMessagingRulesCard(
            config: config,
            plan: userState.plan,
            entitlements: messagingEntitlements,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openSubscriptionManagement(
                context,
                stripeEnabled: config.stripeEnabled,
                source: 'account_subscription_status',
              ),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Gestion future des abonnements'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionMessagingRulesCard extends StatelessWidget {
  final SubscriptionAppConfig config;
  final SubscriptionPlan plan;
  final ConversationAttachmentEntitlements entitlements;

  const _SubscriptionMessagingRulesCard({
    required this.config,
    required this.plan,
    required this.entitlements,
  });

  @override
  Widget build(BuildContext context) {
    final title = config.freeAccessMode
        ? 'Règles messagerie préparées'
        : 'Règles messagerie actives';
    final summary = config.freeAccessMode
        ? 'Aujourd’hui, personne n’est limité. Quand le mode gratuit complet sera coupé, ces règles s’appliqueront.'
        : 'Les limites ci-dessous sont actuellement pilotées par l’abonnement.';
    final photoRule = entitlements.maxPhotosPerConversation >= 999
        ? 'Photos: envoi étendu'
        : 'Photos: ${entitlements.maxPhotosPerConversation} par conversation';
    final audioRule = entitlements.maxAudioPerConversation >= 999
        ? 'Audio: envoi étendu'
        : 'Audio: ${entitlements.maxAudioPerConversation} par conversation';
    final documentRule = entitlements.canSendDocuments
        ? 'Documents et fichiers: autorisés'
        : 'Documents et fichiers: iliprestō+ requis';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _kSubscriptionTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: _kSubscriptionTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _SubscriptionRuleLine(
              label: 'Plan', value: subscriptionPlanLabel(plan)),
          _SubscriptionRuleLine(label: 'Photos', value: photoRule),
          _SubscriptionRuleLine(label: 'Audio', value: audioRule),
          _SubscriptionRuleLine(label: 'Fichiers', value: documentRule),
        ],
      ),
    );
  }
}

class _SubscriptionRuleLine extends StatelessWidget {
  final String label;
  final String value;

  const _SubscriptionRuleLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kSubscriptionTextPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kSubscriptionTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionPlanTabs extends StatefulWidget {
  final SubscriptionAppConfig config;
  final AppUserSubscriptionState userState;

  const SubscriptionPlanTabs({
    super.key,
    required this.config,
    required this.userState,
  });

  @override
  State<SubscriptionPlanTabs> createState() => _SubscriptionPlanTabsState();
}

class _SubscriptionPlanTabsState extends State<SubscriptionPlanTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _tabController.index;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: _kSubscriptionTextSecondary,
            indicator: BoxDecoration(
              color: _kSubscriptionBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Particulier'),
              Tab(text: 'Professionnel'),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: tabIndex == 0
                ? _SubscriptionPlanPanel(
                    key: const ValueKey('individual-plans'),
                    cards: [
                      SubscriptionComparisonCard(
                        title: 'Gratuit',
                        price: '0 €/mois',
                        subtitle:
                            'Pour découvrir iliprestō et tester les outils essentiels.',
                        features: const [
                          'Consulter les annonces',
                          'Publier des annonces',
                          'Répondre à 3 annonces par mois',
                          'Messagerie basique',
                          '5 favoris maximum',
                          'Alertes limitées',
                          '1 assistance IA pour rédiger une annonce',
                          '0 % de commission',
                          'Vous gardez 100 % de vos gains',
                        ],
                        buttonLabel: 'Formule actuelle',
                        onPressed: null,
                        isPrimary: false,
                      ),
                      SubscriptionComparisonCard(
                        title: 'iliprestō+',
                        price: '1,99 €/mois',
                        subtitle:
                            'Pour ne plus rater les annonces autour de vous.',
                        marketingHighlight:
                            '1,99 €/mois. 0 % de commission. Vous gardez 100 % de vos gains.',
                        badge: 'Bientôt disponible',
                        features: const [
                          'Réponses aux annonces illimitées',
                          'Alertes instantanées',
                          'Alertes par catégorie',
                          'Favoris illimités',
                          'Messagerie complète',
                          'Documents autorisés',
                          'Appel direct facilité',
                          'Assistant IA annonce illimité',
                          'Remontée simple d’annonce',
                          'Badge membre actif',
                          '0 % de commission',
                          'Vous gardez 100 % de vos gains',
                        ],
                        buttonLabel: 'Me prévenir au lancement',
                        onPressed: () async {
                          await notifySubscriptionLaunch(
                            context,
                            subscriptionPlanKey(SubscriptionPlan.iliprestoPlus),
                            stripeEnabled: widget.config.stripeEnabled,
                            source: 'account_plan_ilipresto_plus_notify',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Les abonnements seront bientôt disponibles.',
                                ),
                              ),
                            );
                        },
                        onSecondaryPressed: () => startSubscriptionCheckout(
                          context,
                          subscriptionPlanKey(SubscriptionPlan.iliprestoPlus),
                          stripeEnabled: widget.config.stripeEnabled,
                          source: 'account_plan_ilipresto_plus_checkout',
                        ),
                        secondaryButtonLabel: 'Préparer le paiement',
                        isPrimary: true,
                      ),
                    ],
                  )
                : _SubscriptionPlanPanel(
                    key: const ValueKey('pro-plans'),
                    cards: [
                      SubscriptionComparisonCard(
                        title: 'Pro gratuit',
                        price: '0 €/mois',
                        subtitle:
                            'Pour découvrir iliprestō et tester les outils essentiels.',
                        features: const [
                          'Consulter les annonces',
                          'Publier des annonces',
                          'Répondre à 3 annonces par mois',
                          'Messagerie basique',
                          '3 annonces actives maximum',
                          '1 assistance IA pour rédiger une annonce',
                          '0 % de commission',
                          'Vous gardez 100 % de vos gains',
                        ],
                        buttonLabel: 'Continuer gratuitement',
                        onPressed: null,
                        isPrimary: false,
                      ),
                      SubscriptionComparisonCard(
                        title: 'ilipro',
                        price: '9,99 €/mois',
                        subtitle:
                            'Pour développer son activité locale avec plus de visibilité.',
                        marketingHighlight:
                            'Votre mini-vitrine locale, sans commission sur vos prestations.',
                        badge: 'Recommandé pour les prestataires',
                        features: const [
                          'Tout iliprestō+',
                          'Profil professionnel complet',
                          'Badge Pro vérifié',
                          'Mise en avant locale',
                          'Statistiques de vues et de contacts',
                          'Portfolio de réalisations',
                          'Zone d’intervention personnalisée',
                          'Réponses rapides',
                          'Boosts / remontées inclus',
                          '10 photos par annonce',
                          'Support prioritaire',
                          '0 % de commission',
                          'Vous gardez 100 % de vos gains',
                        ],
                        buttonLabel: 'Me prévenir au lancement',
                        onPressed: () async {
                          await notifySubscriptionLaunch(
                            context,
                            subscriptionPlanKey(SubscriptionPlan.ilipro),
                            stripeEnabled: widget.config.stripeEnabled,
                            source: 'account_plan_ilipro_notify',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Les abonnements seront bientôt disponibles.',
                                ),
                              ),
                            );
                        },
                        onSecondaryPressed: () => startSubscriptionCheckout(
                          context,
                          subscriptionPlanKey(SubscriptionPlan.ilipro),
                          stripeEnabled: widget.config.stripeEnabled,
                          source: 'account_plan_ilipro_checkout',
                        ),
                        secondaryButtonLabel: 'Préparer le paiement',
                        isPrimary: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionComparisonCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final List<String> features;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final String? badge;
  final String? marketingHighlight;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  const SubscriptionComparisonCard({
    super.key,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.features,
    required this.buttonLabel,
    required this.onPressed,
    required this.isPrimary,
    this.badge,
    this.marketingHighlight,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isPrimary ? _kSubscriptionOrange : const Color(0xFFD1D5DB);
    final background = isPrimary
        ? const LinearGradient(
            colors: [Color(0xFFFFF5EE), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: isPrimary ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
            color: (isPrimary ? _kSubscriptionOrange : Colors.black)
                .withValues(alpha: isPrimary ? 0.12 : 0.05),
            blurRadius: isPrimary ? 20 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPrimary
                    ? _kSubscriptionOrange.withValues(alpha: 0.12)
                    : _kSubscriptionBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isPrimary ? _kSubscriptionOrange : _kSubscriptionBlue,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _kSubscriptionTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isPrimary ? _kSubscriptionOrange : _kSubscriptionBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: _kSubscriptionTextSecondary,
            ),
          ),
          if (marketingHighlight != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary
                    ? _kSubscriptionOrange.withValues(alpha: 0.08)
                    : _kSubscriptionBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                marketingHighlight!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? _kSubscriptionOrange : _kSubscriptionBlue,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final feature in features) ...[
            SubscriptionFeatureRow(label: feature, isPrimary: isPrimary),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isPrimary
                ? FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kSubscriptionOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSubscriptionBlue,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
          ),
          if (isPrimary && secondaryButtonLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onSecondaryPressed,
                child: Text(
                  secondaryButtonLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SubscriptionFeatureRow extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const SubscriptionFeatureRow({
    super.key,
    required this.label,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: isPrimary ? _kSubscriptionOrange : Colors.green.shade600,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: _kSubscriptionTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
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
                      ? 'Phase de lancement : aucune restriction n’est appliquée. Tous les utilisateurs gardent l’accès complet.'
                      : 'Restrictions abonnement actives : Gratuit, iliprestō+ et ilipro appliquent leurs quotas.',
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

class _SubscriptionPlanPanel extends StatelessWidget {
  final List<SubscriptionComparisonCard> cards;

  const _SubscriptionPlanPanel({
    super.key,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth >= 820;
        if (useRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 14),
            cards[1],
          ],
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

class _SubscriptionLaunchBanner extends StatelessWidget {
  const _SubscriptionLaunchBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSubscriptionBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kSubscriptionBlue.withValues(alpha: 0.14)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phase de lancement : l’accès reste gratuit pour tous.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _kSubscriptionBlue,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Les abonnements sont en préparation. Aucune fonctionnalité n’est bloquée actuellement.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kSubscriptionTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
