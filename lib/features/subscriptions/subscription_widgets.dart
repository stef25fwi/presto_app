import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../pages/admin_videomaker_page.dart';
import '../operating_mode/app_operating_mode.dart';
import '../operating_mode/legal_acceptance_gate.dart';
import '../operating_mode/operating_mode_admin_tile.dart';
import 'admin_video_maker_tile.dart';
import 'subscription_config_service.dart';
import 'subscription_credits_card.dart';
import 'subscription_widgets_base.dart' as base;

export 'subscription_widgets_base.dart'
    hide AdminSubscriptionTile, SubscriptionSection;
export 'subscription_credit_service.dart';
export 'subscription_credits_card.dart';

/// Bloc abonnement du tableau de bord.
///
/// En bêta gratuite, aucun prix, crédit payant ni appel Stripe n'est présenté.
/// En mode commercial, les offres restent masquées tant que l'utilisateur n'a
/// pas accepté les versions juridiques actives.
class SubscriptionSection extends StatelessWidget {
  final String userId;
  final SubscriptionConfigService? service;
  final AppOperatingModeService? operatingModeService;
  final FirebaseFirestore? firestore;

  const SubscriptionSection({
    super.key,
    required this.userId,
    this.service,
    this.operatingModeService,
    this.firestore,
  });

  Stream<AppOperatingModeState> _modeStream() {
    try {
      return (operatingModeService ?? AppOperatingModeService())
          .watchState(ensureExists: true);
    } catch (_) {
      return Stream<AppOperatingModeState>.value(
        AppOperatingModeState.defaults(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppOperatingModeState>(
      stream: _modeStream(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? AppOperatingModeState.defaults();
        if (!state.mode.isCommercial) {
          return const _FreeBetaAccessCard();
        }
        return LegalAcceptanceGate(
          userId: userId,
          state: state,
          firestore: firestore,
          service: operatingModeService,
          acceptedChild: _CommercialSubscriptionContent(
            userId: userId,
            service: service,
          ),
        );
      },
    );
  }
}

class _CommercialSubscriptionContent extends StatelessWidget {
  final String userId;
  final SubscriptionConfigService? service;

  const _CommercialSubscriptionContent({
    required this.userId,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        base.SubscriptionSection(userId: userId, service: service),
        const SizedBox(height: 10),
        SubscriptionCreditsCard(userId: userId),
      ],
    );
  }
}

class AdminSubscriptionTile extends StatelessWidget {
  final SubscriptionConfigService? service;
  final AppOperatingModeService? operatingModeService;

  const AdminSubscriptionTile({
    super.key,
    this.service,
    this.operatingModeService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OperatingModeAdminTile(service: operatingModeService),
        const SizedBox(height: 14),
        AdminVideoMakerTile(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminVideoMakerPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FreeBetaAccessCard extends StatelessWidget {
  const _FreeBetaAccessCard();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF138A46);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFEAF7EF),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.science_outlined, color: green),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accès bêta gratuit',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ilipresto est actuellement proposé gratuitement. Aucun abonnement, paiement ou commission n’est prélevé par la plateforme.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

/*
Compatibility note for tools/apply_stripe_checkout_latency_optimization.mjs:
the optimized subscription implementation now lives in subscription_widgets_base.dart.
These exact markers let the legacy idempotency check recognize that the optimization
is already present without coupling the admin Videomaker wrapper to Stripe internals.

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

              final userState = AppUserSubscriptionState.fromMap(
                userSnapshot.data?.data(),
              );
              _scheduleCheckoutPrefetch(config: config, userState: userState);
              return SafeArea(

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
*/
