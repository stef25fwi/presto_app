import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ads_consent_service.dart';

class AdsPrivacyOptionsCard extends StatefulWidget {
  const AdsPrivacyOptionsCard({super.key});

  @override
  State<AdsPrivacyOptionsCard> createState() => _AdsPrivacyOptionsCardState();
}

class _AdsPrivacyOptionsCardState extends State<AdsPrivacyOptionsCard> {
  static const Color _orange = Color(0xFFFF6600);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  bool _opening = false;

  @override
  void initState() {
    super.initState();
    unawaited(AdsConsentService.instance.refreshPrivacyState());
  }

  Future<void> _openPrivacyOptions() async {
    if (_opening) return;
    setState(() => _opening = true);
    final shown = await AdsConsentService.instance.showPrivacyOptions();
    if (!mounted) return;
    setState(() => _opening = false);

    if (!shown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les options publicitaires Google ne sont plus requises pour votre configuration actuelle.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdsConsentService.instance,
      builder: (context, _) {
        final required = AdsConsentService.instance.privacyOptionsRequired;
        if (!required) return const SizedBox.shrink();

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: _orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Préférences publicitaires Google',
                        style: TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Google UMP demande qu’un accès aux options de confidentialité reste disponible.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _opening ? null : _openPrivacyOptions,
                  icon: _opening
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tune_rounded),
                  label: const Text('Gérer mes choix publicitaires'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
