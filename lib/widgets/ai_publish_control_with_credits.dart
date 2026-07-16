import 'package:flutter/material.dart';

import '../features/subscriptions/subscription_credit_service.dart';
import '../features/subscriptions/subscription_credits_card.dart';
import 'ai_publish_control.dart';

export 'ai_publish_control.dart';

class AiPublishControlWithCredits extends StatelessWidget {
  final AiPublishState state;
  final LayerLink micAnchorLink;
  final bool isAudioAnalyzing;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onSelectVocal;
  final VoidCallback onSelectText;
  final VoidCallback onDiagnostic;
  final VoidCallback onClear;
  final bool showAdminDiagnostics;
  final bool highlightVocalCard;
  final bool dimVocalCard;

  const AiPublishControlWithCredits({
    super.key,
    required this.state,
    required this.micAnchorLink,
    this.isAudioAnalyzing = false,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSelectVocal,
    required this.onSelectText,
    required this.onDiagnostic,
    required this.onClear,
    this.showAdminDiagnostics = false,
    this.highlightVocalCard = false,
    this.dimVocalCard = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SubscriptionCreditsInlineBadges(
          kinds: [
            SubscriptionCreditKind.voiceAi,
            SubscriptionCreditKind.textAi,
          ],
        ),
        const SizedBox(height: 10),
        AiPublishControl(
          state: state,
          micAnchorLink: micAnchorLink,
          isAudioAnalyzing: isAudioAnalyzing,
          onStartRecording: onStartRecording,
          onStopRecording: onStopRecording,
          onSelectVocal: onSelectVocal,
          onSelectText: onSelectText,
          onDiagnostic: onDiagnostic,
          onClear: onClear,
          showAdminDiagnostics: showAdminDiagnostics,
          highlightVocalCard: highlightVocalCard,
          dimVocalCard: dimVocalCard,
        ),
      ],
    );
  }
}
