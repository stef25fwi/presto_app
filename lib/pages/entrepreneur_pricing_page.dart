import 'package:flutter/material.dart';

import 'entrepreneur_pricing/entrepreneur_pricing_form_page.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_form_widgets.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_history_page.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_mode_widgets.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_models.dart';

class EntrepreneurPricingPage extends StatefulWidget {
  const EntrepreneurPricingPage({super.key});

  @override
  State<EntrepreneurPricingPage> createState() =>
      _EntrepreneurPricingPageState();
}

class _EntrepreneurPricingPageState extends State<EntrepreneurPricingPage> {
  EntrepreneurPricingMode _mode = EntrepreneurPricingMode.standard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: PricingHeader(
        color: formOrange,
        homeBack: true,
        onBack: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 22),
          children: [
            const Text(
              "Calculatrice de l'entrepreneur",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choisis le niveau de précision adapté à ton activité.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            EntrepreneurPricingModeCard(
              mode: EntrepreneurPricingMode.standard,
              selected: _mode == EntrepreneurPricingMode.standard,
              title: 'Mode Standard',
              subtitle: 'Guidé & complet',
              description: 'Coûts essentiels, amortissement et prix rentable',
              badge: '5 min',
              chips: const ['Recommandé', 'Prix rentable + marge'],
              onTap: () => setState(
                () => _mode = EntrepreneurPricingMode.standard,
              ),
            ),
            const SizedBox(height: 12),
            EntrepreneurPricingModeCard(
              mode: EntrepreneurPricingMode.expert,
              selected: _mode == EntrepreneurPricingMode.expert,
              title: 'Mode Expert',
              subtitle: 'Coût exact de production',
              description:
                  'Machines, watts, durée, accessoires, marché et scénarios',
              badge: '12 min',
              chips: const ['Le plus précis', 'Machines + accessoires'],
              onTap: () => setState(
                () => _mode = EntrepreneurPricingMode.expert,
              ),
            ),
            const SizedBox(height: 18),
            PricingStartButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EntrepreneurPricingFormPage(mode: _mode),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EntrepreneurPricingHistoryPage(),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Mes calculs enregistrés'),
            ),
          ],
        ),
      ),
    );
  }
}