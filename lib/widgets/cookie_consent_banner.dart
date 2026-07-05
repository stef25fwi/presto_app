import 'package:flutter/material.dart';

import '../services/cookie_consent_service.dart';

class CookieConsentBanner extends StatelessWidget {
  const CookieConsentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CookieConsentService.instance,
      builder: (context, child) {
        if (!CookieConsentService.instance.shouldShowBanner) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          minimum: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Material(
                elevation: 18,
                borderRadius: BorderRadius.circular(22),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cookies et traceurs',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nous utilisons les traceurs strictement nécessaires au fonctionnement, et des traceurs analytics ou marketing uniquement après votre accord.',
                        style: TextStyle(color: Colors.black54, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              showCookiePreferencesDialog(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black26),
                            ),
                            child: const Text('Personnaliser'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              await CookieConsentService.instance.refuseAll();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black26),
                            ),
                            child: const Text('Refuser'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await CookieConsentService.instance.acceptAll();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6600),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accepter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showCookiePreferencesDialog(BuildContext context) async {
  final current = CookieConsentService.instance.state;
  bool analyticsAllowed = current?.analyticsAllowed ?? false;
  bool marketingAllowed = current?.marketingAllowed ?? false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Personnaliser les traceurs'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Les traceurs strictement nécessaires restent actifs. Vous pouvez autoriser séparément les analytics et les traceurs marketing.',
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Analytics'),
                    subtitle: const Text(
                      'Mesure de fréquentation et amélioration produit.',
                    ),
                    value: analyticsAllowed,
                    onChanged: (value) {
                      setState(() => analyticsAllowed = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Marketing / publicité'),
                    subtitle: const Text(
                      'Pixels publicitaires et publicité personnalisée.',
                    ),
                    value: marketingAllowed,
                    onChanged: (value) {
                      setState(() => marketingAllowed = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  await CookieConsentService.instance.refuseAll();
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Tout refuser'),
              ),
              FilledButton(
                onPressed: () async {
                  await CookieConsentService.instance.savePreferences(
                    analyticsAllowed: analyticsAllowed,
                    marketingAllowed: marketingAllowed,
                  );
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}