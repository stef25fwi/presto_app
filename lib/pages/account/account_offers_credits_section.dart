import 'package:flutter/material.dart';

import '../../features/subscriptions/subscription_credit_service.dart';
import '../../features/subscriptions/subscription_credits_card.dart';
import '../user_offers_section.dart';

class AccountOffersCreditsSection extends StatelessWidget {
  final String userId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AccountOffersCreditsSection({
    super.key,
    required this.userId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.4),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_outlined, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gérer mes annonces',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Retrouve tes annonces par statut, modifie-les ou supprime-les avec confirmation.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        SubscriptionCreditsInlineBadges(
                          kinds: [SubscriptionCreditKind.activeOffers],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: RepaintBoundary(
                child: UserOffersSection(userId: userId, showTitle: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
