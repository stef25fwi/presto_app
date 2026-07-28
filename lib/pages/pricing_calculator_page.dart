import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../constants.dart';

/// Prestō – Calculatrice de Prix Artisan (mockup fidèle à l'image)
/// - Écran 1 : choix du mode
/// - Écran 2 : mode express (sections + champs)
/// - Écran 3 : résultats + positionnement marché
///
/// ✅ Copie/colle ce fichier comme `lib/pricing_calculator_page.dart`
/// puis ouvre `PrestoPriceCalculatorApp()` depuis ton main.dart (ou pousse cette page via Navigator).

// ---------------------------
// THEME / COLORS (Prestō)
// ---------------------------
const Color kPrestoOrange = Color(0xFFFF6600);
const Color kPrestoBlue = Color(0xFF1A73E8);

class PrestoPriceCalculatorApp extends StatelessWidget {
  const PrestoPriceCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iliprestō – Calculatrice',
      theme: buildPrestoTheme().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrestoBlue,
          primary: kPrestoBlue,
          secondary: kPrestoOrange,
        ),
      ),
      home: const _ModeSelectionPage(),
    );
  }
}

// ---------------------------
// MODE SELECTION (Screen 1)
// ---------------------------
enum PricingMode { express, standard, expert }

class _ModeOption {
  const _ModeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.badge,
    required this.timeLabel,
    required this.bestFor,
    required this.fieldsLabel,
    required this.analysisLabel,
    required this.highlights,
  });

  final PricingMode mode;
  final String title;
  final String subtitle;
  final Color accent;
  final String badge;
  final String timeLabel;
  final String bestFor;
  final String fieldsLabel;
  final String analysisLabel;
  final List<String> highlights;
}

const List<_ModeOption> _pricingModes = [
  _ModeOption(
    mode: PricingMode.express,
    title: 'Mode Express',
    subtitle: 'Rapide & Simple',
    accent: kPrestoOrange,
    badge: 'Le plus rapide',
    timeLabel: '2 min',
    bestFor: 'Estimation immédiate',
    fieldsLabel: 'Essentiels',
    analysisLabel: 'Base prix + marge',
    highlights: [
      'Saisie minimale',
      'Parfait pour tester une idée',
      'Résultat immédiat',
    ],
  ),
  _ModeOption(
    mode: PricingMode.standard,
    title: 'Mode Standard',
    subtitle: 'Complet',
    accent: kPrestoBlue,
    badge: 'Le plus équilibré',
    timeLabel: '5 min',
    bestFor: 'Fixer un vrai tarif de vente',
    fieldsLabel: 'Coûts + charges + marché',
    analysisLabel: 'Prix conseillé + positionnement',
    highlights: [
      'Vision plus fiable',
      'Inclut les charges réelles',
      'Adapté à la plupart des cas',
    ],
  ),
  _ModeOption(
    mode: PricingMode.expert,
    title: 'Mode Expert',
    subtitle: 'Analyse avancée',
    accent: Color(0xFF0F4C81),
    badge: 'Le plus précis',
    timeLabel: '8 min',
    bestFor: 'Décision fine et arbitrages',
    fieldsLabel: 'Données détaillées',
    analysisLabel: 'Lecture avancée de rentabilité',
    highlights: [
      'Scénarios plus poussés',
      'Analyse détaillée des postes',
      'Pour affiner au maximum',
    ],
  ),
];

class _ModeSelectionPage extends StatefulWidget {
  const _ModeSelectionPage();

  @override
  State<_ModeSelectionPage> createState() => _ModeSelectionPageState();
}

class _ModeSelectionPageState extends State<_ModeSelectionPage> {
  PricingMode _mode = PricingMode.express;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _PrestoTopBar(
        title: 'iliprestō',
        background: kPrestoOrange,
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 16, 6, 16),
          children: [
            const SizedBox(height: 6),
            const Text(
              'Calculatrice de Prix Artisan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ..._pricingModes.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModeCard(
                  option: option,
                  selected: _mode == option.mode,
                  onTap: () => setState(() => _mode = option.mode),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PrestoPrimaryButton(
              icon: Icons.play_arrow_rounded,
              text: 'Commencer',
              background: kPrestoOrange,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ExpressFormPage(mode: _mode),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = option.accent;
    final border = selected ? accent : const Color(0xFFE5E7EB);
    final fill = selected ? accent.withValues(alpha: 0.10) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: selected ? 2 : 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 16,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _RadioPill(selected: selected, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(option.title,
                            style: kPrestoCardTitleStyle.copyWith(
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          option.timeLabel,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(option.subtitle,
                      style: kPrestoCardTitleStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(option.bestFor,
                      style: kPrestoMetaTextStyle.copyWith(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ModeMetaChip(
                        label: option.badge,
                        accent: accent,
                      ),
                      _ModeMetaChip(
                        label: option.analysisLabel,
                        accent: accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeMetaChip extends StatelessWidget {
  const _ModeMetaChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _RadioPill extends StatelessWidget {
  final bool selected;
  final Color accent;
  const _RadioPill({required this.selected, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : const Color(0xFFBDBDBD),
          width: 2,
        ),
        color: selected ? accent : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

// ---------------------------
// EXPRESS FORM (Screen 2)
// ---------------------------
class _ExpressFormPage extends StatefulWidget {
  final PricingMode mode;
  const _ExpressFormPage({required this.mode});

  @override
  State<_ExpressFormPage> createState() => _ExpressFormPageState();
}

class _ExpressFormPageState extends State<_ExpressFormPage> {
  // Controllers (image values by default)
  final _matieresCtrl = TextEditingController(text: '12,50');
  final _emballageCtrl = TextEditingController(text: '1,20');
  final _consommablesCtrl = TextEditingController(text: '0,80');

  final _tempsMinCtrl = TextEditingController(text: '45');
  final _tauxHoraireCtrl = TextEditingController(text: '25');

  final _chargesMensCtrl = TextEditingController(text: '300');
  final _objetsMensCtrl = TextEditingController(text: '30');

  bool _fraisTypePct = true;
  final _fraisPctCtrl = TextEditingController(text: '12');
  final _fraisFixeCtrl = TextEditingController(text: '0');

  // Market inputs (for screen 3)
  final _marketLowCtrl = TextEditingController(text: '39');
  final _marketMidCtrl = TextEditingController(text: '55');
  final _marketHighCtrl = TextEditingController(text: '79');

  @override
  void dispose() {
    _matieresCtrl.dispose();
    _emballageCtrl.dispose();
    _consommablesCtrl.dispose();
    _tempsMinCtrl.dispose();
    _tauxHoraireCtrl.dispose();
    _chargesMensCtrl.dispose();
    _objetsMensCtrl.dispose();
    _fraisPctCtrl.dispose();
    _fraisFixeCtrl.dispose();
    _marketLowCtrl.dispose();
    _marketMidCtrl.dispose();
    _marketHighCtrl.dispose();
    super.dispose();
  }

  double _parseDouble(String s) {
    final cleaned = s.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  int _parseInt(String s) {
    final cleaned = s.trim().replaceAll(' ', '');
    return int.tryParse(cleaned) ?? 0;
  }

  bool get _canCompute {
    final mat = _parseDouble(_matieresCtrl.text);
    final emb = _parseDouble(_emballageCtrl.text);
    final conso = _parseDouble(_consommablesCtrl.text);
    final t = _parseInt(_tempsMinCtrl.text);
    final th = _parseDouble(_tauxHoraireCtrl.text);
    final ch = _parseDouble(_chargesMensCtrl.text);
    final vol = _parseInt(_objetsMensCtrl.text);

    final fraisOk = _fraisTypePct
        ? _parseDouble(_fraisPctCtrl.text) >= 0 &&
            _parseDouble(_fraisPctCtrl.text) < 99.9
        : _parseDouble(_fraisFixeCtrl.text) >= 0;

    return (mat + emb + conso) >= 0 &&
        t > 0 &&
        th > 0 &&
        ch >= 0 &&
        vol > 0 &&
        fraisOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _PrestoTopBar(
        title: 'iliprestō',
        background: kPrestoBlue,
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 16),
          children: [
            const Text(
              'Mode Express : Estimation Rapide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),

            // 1) Coûts Matériels
            _SectionCard(
              headerColor: kPrestoOrange,
              headerIcon: Icons.inventory_2_outlined,
              title: '1. Coûts Matériels',
              child: Column(
                children: [
                  _RowField(
                    icon: Icons.category_outlined,
                    label: 'Matières',
                    controller: _matieresCtrl,
                    suffix: '€',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.all_inbox_outlined,
                    label: 'Emballage',
                    controller: _emballageCtrl,
                    suffix: '€',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.auto_awesome_mosaic_outlined,
                    label: 'Consommables',
                    controller: _consommablesCtrl,
                    suffix: '€',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2) Temps & Main d'œuvre
            _SectionCard(
              headerColor: kPrestoBlue,
              headerIcon: Icons.timer_outlined,
              title: '2. Temps & Main d\'oeuvre',
              child: Column(
                children: [
                  _RowField(
                    icon: Icons.schedule_outlined,
                    label: 'Temps de fabrication',
                    controller: _tempsMinCtrl,
                    suffix: 'min',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.badge_outlined,
                    label: 'Taux horaire',
                    controller: _tauxHoraireCtrl,
                    suffix: '€/h',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    trailing: _QuickRatePresets(
                      onPick: (v) {
                        _tauxHoraireCtrl.text = v.toStringAsFixed(0);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3) Charges Fixes
            _SectionCard(
              headerColor: kPrestoBlue,
              headerIcon: Icons.home_work_outlined,
              title: '3. Charges Fixes',
              subtitle: '(mensuel: 300 € / 30 objets)',
              child: Column(
                children: [
                  _RowField(
                    icon: Icons.receipt_long_outlined,
                    label: 'Charges / mois',
                    controller: _chargesMensCtrl,
                    suffix: '€',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.widgets_outlined,
                    label: 'Objets / mois',
                    controller: _objetsMensCtrl,
                    suffix: 'nb',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _MiniInfoPill(
                    icon: Icons.calculate_outlined,
                    text:
                        'Charge estimée : ${_money(_chargeFixeUnitaire())} € par objet',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4) Frais de Vente
            _SectionCard(
              headerColor: kPrestoOrange,
              headerIcon: Icons.storefront_outlined,
              title: '4. Frais de Vente',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToggleTypeRow(
                    valueIsPct: _fraisTypePct,
                    onChanged: (v) => setState(() => _fraisTypePct = v),
                  ),
                  const SizedBox(height: 10),
                  if (_fraisTypePct)
                    _RowField(
                      icon: Icons.percent_rounded,
                      label: 'Frais de plateforme',
                      controller: _fraisPctCtrl,
                      suffix: '%',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    )
                  else
                    _RowField(
                      icon: Icons.euro_rounded,
                      label: 'Frais fixes par vente',
                      controller: _fraisFixeCtrl,
                      suffix: '€',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // CTA
            _PrestoPrimaryButton(
              text: 'Voir mon Prix Conseillé',
              background: kPrestoOrange,
              onTap: _canCompute
                  ? () {
                      final input = _collectInputs();
                      final result = PricingEngine.compute(input);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ResultsPage(
                            input: input,
                            result: result,
                            marketLow: _parseDouble(_marketLowCtrl.text),
                            marketMid: _parseDouble(_marketMidCtrl.text),
                            marketHigh: _parseDouble(_marketHighCtrl.text),
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 10),

            // Market quick fields (kept minimal, but available)
            _MarketMiniCard(
              lowCtrl: _marketLowCtrl,
              midCtrl: _marketMidCtrl,
              highCtrl: _marketHighCtrl,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  PricingInput _collectInputs() {
    final matieres = _parseDouble(_matieresCtrl.text);
    final emballage = _parseDouble(_emballageCtrl.text);
    final consommables = _parseDouble(_consommablesCtrl.text);

    final tempsMin = _parseInt(_tempsMinCtrl.text);
    final tauxHoraire = _parseDouble(_tauxHoraireCtrl.text);

    final chargesMens = _parseDouble(_chargesMensCtrl.text);
    final objetsMens = _parseInt(_objetsMensCtrl.text);

    final fraisPct =
        _fraisTypePct ? _parseDouble(_fraisPctCtrl.text) / 100.0 : 0.0;
    final fraisFixe = _fraisTypePct ? 0.0 : _parseDouble(_fraisFixeCtrl.text);

    return PricingInput(
      matieres: matieres,
      emballage: emballage,
      consommables: consommables,
      tempsFabricationMin: tempsMin,
      tauxHoraire: tauxHoraire,
      chargesMensuelles: chargesMens,
      volumeMensuel: math.max(objetsMens, 1),
      fraisVentePct: fraisPct,
      fraisVenteFixe: fraisFixe,
      // marge par défaut pour coller à un "prix conseillé" crédible
      margePctSurCout: 0.35, // 35%
      tvaPct: 0.0, // à activer plus tard si besoin
    );
  }

  double _chargeFixeUnitaire() {
    final charges = _parseDouble(_chargesMensCtrl.text);
    final vol = math.max(_parseInt(_objetsMensCtrl.text), 1);
    return charges / vol;
  }
}

// ---------------------------
// RESULTS (Screen 3)
// ---------------------------
class _ResultsPage extends StatelessWidget {
  final PricingInput input;
  final PricingResult result;
  final double marketLow;
  final double marketMid;
  final double marketHigh;

  const _ResultsPage({
    required this.input,
    required this.result,
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
  });

  @override
  Widget build(BuildContext context) {
    final market = MarketPositioning.evaluate(
      price: result.prixConseille,
      low: marketLow,
      mid: marketMid,
      high: marketHigh,
    );

    return Scaffold(
      appBar: _PrestoTopBar(
        title: 'iliprestō',
        background: kPrestoBlue,
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            const Text(
              'Résultats & Positionnement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),

            // Résultats card (top)
            _ResultSummaryCard(result: result),

            const SizedBox(height: 14),

            // Positionnement Marché
            _MarketCard(
              marketLow: marketLow,
              marketMid: marketMid,
              marketHigh: marketHigh,
              price: result.prixConseille,
              label: market.label,
              hint: market.hint,
              levelColor: market.color,
            ),

            const SizedBox(height: 16),

            // CTAs
            _PrestoPrimaryButton(
              text: 'Publier sur Prestō',
              background: kPrestoOrange,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Action : publier (à connecter à ton flux Prestō)')),
                );
              },
            ),
            const SizedBox(height: 10),
            _PrestoPrimaryButton(
              text: 'Ajuster Marges',
              background: kPrestoBlue,
              onTap: () {
                Navigator.of(context).pop(); // revient à l'écran form
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------
// CALC ENGINE (pure logic)
// ---------------------------
class PricingInput {
  final double matieres;
  final double emballage;
  final double consommables;

  final int tempsFabricationMin;
  final double tauxHoraire;

  final double chargesMensuelles;
  final int volumeMensuel;

  /// Either percent OR fixed can be used (both allowed; engine handles)
  final double fraisVentePct; // ex: 0.12
  final double fraisVenteFixe; // ex: 1.20

  final double margePctSurCout; // ex: 0.35 (35%)
  final double tvaPct; // ex: 0.20

  const PricingInput({
    required this.matieres,
    required this.emballage,
    required this.consommables,
    required this.tempsFabricationMin,
    required this.tauxHoraire,
    required this.chargesMensuelles,
    required this.volumeMensuel,
    required this.fraisVentePct,
    required this.fraisVenteFixe,
    required this.margePctSurCout,
    required this.tvaPct,
  });
}

class PricingResult {
  final double coutDirect;
  final double coutMainOeuvre;
  final double chargeFixeUnitaire;
  final double coutDeRevient; // CR (hors frais % sur prix)
  final double prixMinimumRentable;
  final double prixConseille;
  final double prixTTC;

  const PricingResult({
    required this.coutDirect,
    required this.coutMainOeuvre,
    required this.chargeFixeUnitaire,
    required this.coutDeRevient,
    required this.prixMinimumRentable,
    required this.prixConseille,
    required this.prixTTC,
  });
}

class PricingEngine {
  static PricingResult compute(PricingInput i) {
    final coutDirect = i.matieres + i.emballage + i.consommables;

    final coutMO = (i.tempsFabricationMin / 60.0) * i.tauxHoraire;

    final chargeFixe = i.chargesMensuelles / math.max(i.volumeMensuel, 1);

    final crHorsFraisPct = coutDirect + coutMO + chargeFixe;

    // Prix minimum rentable
    final prixMin = _applyFeesToReachNet(
      targetNet: crHorsFraisPct + i.fraisVenteFixe,
      fraisPct: i.fraisVentePct,
    );

    // Prix conseillé (net cible = CR + marge%)
    final netCible =
        (crHorsFraisPct * (1 + i.margePctSurCout)) + i.fraisVenteFixe;
    final prixConseille = _applyFeesToReachNet(
      targetNet: netCible,
      fraisPct: i.fraisVentePct,
    );

    final prixTTC = prixConseille * (1 + i.tvaPct);

    return PricingResult(
      coutDirect: coutDirect,
      coutMainOeuvre: coutMO,
      chargeFixeUnitaire: chargeFixe,
      coutDeRevient: crHorsFraisPct,
      prixMinimumRentable: prixMin,
      prixConseille: prixConseille,
      prixTTC: prixTTC,
    );
  }

  /// If platform takes pct on sale price, and you need to KEEP `targetNet`,
  /// then price must be: targetNet / (1 - pct)
  static double _applyFeesToReachNet({
    required double targetNet,
    required double fraisPct,
  }) {
    final p = fraisPct.clamp(0.0, 0.999);
    return targetNet / (1.0 - p);
  }
}

// ---------------------------
// MARKET POSITIONING
// ---------------------------
class MarketEval {
  final String label;
  final String hint;
  final Color color;

  const MarketEval(this.label, this.hint, this.color);
}

class MarketPositioning {
  static MarketEval evaluate({
    required double price,
    required double low,
    required double mid,
    required double high,
  }) {
    if (low <= 0 || mid <= 0 || high <= 0 || !(low <= mid && mid <= high)) {
      return const MarketEval(
        'Marché non renseigné',
        'Ajoute une fourchette (bas / moyen / haut) pour un conseil plus précis.',
        Color(0xFF9CA3AF),
      );
    }

    if (price < low) {
      return const MarketEval(
        'Sous-évalué',
        'Tu peux augmenter ton prix sans sortir du marché.',
        Color(0xFFF59E0B),
      );
    }
    if (price <= high) {
      return const MarketEval(
        'Aligné sur le marché!',
        'Bien placé. Mets en avant qualité & délai.',
        Color(0xFF22C55E),
      );
    }
    return const MarketEval(
      'Positionnement Premium',
      'À ce prix, renforce la valeur perçue (finitions, packaging, story, édition limitée).',
      Color(0xFFEF4444),
    );
  }
}

// ---------------------------
// UI COMPONENTS
// ---------------------------
class _PrestoTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color background;
  final bool showBack;

  const _PrestoTopBar({
    required this.title,
    required this.background,
    required this.showBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: background,
      elevation: 0,
      title: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
            ),
          if (showBack) const SizedBox(width: 2),
          Text(
            title,
            style: kPrestoAppBarTitleStyle.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color headerColor;
  final IconData headerIcon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.headerColor,
    required this.headerIcon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(headerIcon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          )),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.black38),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _RowField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const _RowField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.suffix,
    this.keyboardType,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label :',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType ??
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: suffix,
              suffixStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _ToggleTypeRow extends StatelessWidget {
  final bool valueIsPct;
  final ValueChanged<bool> onChanged;

  const _ToggleTypeRow({required this.valueIsPct, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Type :',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 10),
        _PillToggle(
          left: '%',
          right: '€',
          selectedLeft: valueIsPct,
          onChanged: onChanged,
        ),
        const Spacer(),
        const Icon(Icons.info_outline, size: 18, color: Colors.black45),
      ],
    );
  }
}

class _PillToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool selectedLeft;
  final ValueChanged<bool> onChanged;

  const _PillToggle({
    required this.left,
    required this.right,
    required this.selectedLeft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedLeft ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  left,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selectedLeft ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedLeft ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  right,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selectedLeft ? Colors.black54 : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRatePresets extends StatelessWidget {
  final ValueChanged<double> onPick;
  const _QuickRatePresets({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Presets',
      splashRadius: 18,
      icon: const Icon(Icons.tune_rounded, size: 20, color: Colors.black54),
      onSelected: onPick,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 15, child: Text('15 €/h (débutant)')),
        PopupMenuItem(value: 25, child: Text('25 €/h (standard)')),
        PopupMenuItem(value: 35, child: Text('35 €/h (expert)')),
      ],
    );
  }
}

class _PrestoPrimaryButton extends StatelessWidget {
  final String text;
  final Color background;
  final VoidCallback? onTap;
  final IconData? icon;

  const _PrestoPrimaryButton({
    required this.text,
    required this.background,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? background : background.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  final PricingResult result;
  const _ResultSummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _ResultRow(
              label: 'Coût de revient',
              value: '${_money(result.coutDeRevient)} €'),
          const SizedBox(height: 10),
          _ResultRow(
              label: 'Prix minimum rentable',
              value: '${_money(result.prixMinimumRentable)} €'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrestoOrange.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prix conseillé :',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${_money(result.prixConseille)} €',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                const Text('TTC',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label :',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _MarketCard extends StatelessWidget {
  final double marketLow;
  final double marketMid;
  final double marketHigh;
  final double price;
  final String label;
  final String hint;
  final Color levelColor;

  const _MarketCard({
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
    required this.price,
    required this.label,
    required this.hint,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Positionnement Marché',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Prix du marché : ${_money(marketLow)} € - ${_money(marketMid)} € - ${_money(marketHigh)} €',
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ton prix conseillé : ${_money(price)} €',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: levelColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: levelColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: levelColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MarketMiniCard extends StatelessWidget {
  final TextEditingController lowCtrl;
  final TextEditingController midCtrl;
  final TextEditingController highCtrl;
  final VoidCallback onChanged;

  const _MarketMiniCard({
    required this.lowCtrl,
    required this.midCtrl,
    required this.highCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marché (optionnel)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _MiniMarketField(
                      label: 'Bas', ctrl: lowCtrl, onChanged: onChanged)),
              const SizedBox(width: 10),
              Expanded(
                  child: _MiniMarketField(
                      label: 'Moyen', ctrl: midCtrl, onChanged: onChanged)),
              const SizedBox(width: 10),
              Expanded(
                  child: _MiniMarketField(
                      label: 'Haut', ctrl: highCtrl, onChanged: onChanged)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMarketField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  const _MiniMarketField({
    required this.label,
    required this.ctrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ---------------------------
// HELPERS
// ---------------------------
String _money(double v) {
  // format simple "59,90"
  final fixed = v.isFinite ? v.toStringAsFixed(2) : '0.00';
  return fixed.replaceAll('.', ',');
}
