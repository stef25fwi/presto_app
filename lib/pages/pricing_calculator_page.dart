import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../constants.dart';

part 'pricing_calculator/pricing_calculator_results_page.dart';
part 'pricing_calculator/pricing_calculator_models.dart';
part 'pricing_calculator/pricing_calculator_persistence.dart';
part 'pricing_calculator/pricing_calculator_pdf.dart';
part 'pricing_calculator/pricing_calculator_history.dart';
part 'pricing_calculator/pricing_calculator_mode_widgets.dart';
part 'pricing_calculator/pricing_calculator_result_widgets.dart';
part 'pricing_calculator/pricing_calculator_analysis_widgets.dart';
part 'pricing_calculator/pricing_calculator_market_widgets.dart';

/// Calculatrice de l'entrepreneur iliprestō.
///
/// Le mode Standard produit un prix rentable à partir des coûts essentiels.
/// Le mode Expert ajoute l'énergie, l'eau, le transport, le marché, les
/// scénarios de volume, la sauvegarde et l'export PDF.

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
enum PricingMode { standard, expert }

extension PricingModeLabel on PricingMode {
  String get label => this == PricingMode.standard ? 'Standard' : 'Expert';
}

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
    mode: PricingMode.standard,
    title: 'Mode Standard',
    subtitle: 'Guidé & complet',
    accent: kPrestoBlue,
    badge: 'Recommandé',
    timeLabel: '5 min',
    bestFor: 'Fixer un vrai tarif de vente',
    fieldsLabel: 'Coûts + charges + amortissement',
    analysisLabel: 'Prix rentable + marge',
    highlights: [
      'Coût de revient détaillé',
      'Prix minimum et prix conseillé',
      'Rentabilité du prix envisagé',
    ],
  ),
  _ModeOption(
    mode: PricingMode.expert,
    title: 'Mode Expert',
    subtitle: 'Analyse avancée',
    accent: Color(0xFF0F4C81),
    badge: 'Le plus précis',
    timeLabel: '10 min',
    bestFor: 'Décision fine et arbitrages',
    fieldsLabel: 'Coûts détaillés + scénarios',
    analysisLabel: 'Marché + seuil de rentabilité',
    highlights: [
      'Énergie, eau et transport',
      'Marché et volumes prudent / cible / haut',
      'Historique et export PDF',
    ],
  ),
];

class _ModeSelectionPage extends StatefulWidget {
  const _ModeSelectionPage();

  @override
  State<_ModeSelectionPage> createState() => _ModeSelectionPageState();
}

class _ModeSelectionPageState extends State<_ModeSelectionPage> {
  PricingMode _mode = PricingMode.standard;

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
              "Calculatrice de l'entrepreneur",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choisis le niveau de précision adapté à ton activité.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
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
                    builder: (_) => _PricingFormPage(mode: _mode),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _PricingHistoryPage(),
                  ),
                );
              },
              icon: const Icon(Icons.history_rounded),
              label: const Text('Mes calculs enregistrés'),
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
// PRICING FORM (Screen 2)
// ---------------------------
class _PricingFormPage extends StatefulWidget {
  final PricingMode mode;
  const _PricingFormPage({required this.mode});

  @override
  State<_PricingFormPage> createState() => _PricingFormPageState();
}

class _PricingFormPageState extends State<_PricingFormPage> {
  final _projectNameCtrl = TextEditingController(text: 'Mon produit ou service');
  final _prixEnvisageCtrl = TextEditingController(text: '50');

  final _matieresCtrl = TextEditingController(text: '12,50');
  final _emballageCtrl = TextEditingController(text: '1,20');
  final _consommablesCtrl = TextEditingController(text: '0,80');

  final _tempsMinCtrl = TextEditingController(text: '45');
  final _tauxHoraireCtrl = TextEditingController(text: '25');

  final _chargesMensCtrl = TextEditingController(text: '300');
  final _objetsMensCtrl = TextEditingController(text: '30');

  final _materielCtrl = TextEditingController(text: '300');
  final _amortissementUniteCtrl = TextEditingController(text: '10');

  bool _fraisTypePct = true;
  final _fraisPctCtrl = TextEditingController(text: '12');
  final _fraisFixeCtrl = TextEditingController(text: '0');
  final _margeCtrl = TextEditingController(text: '35');
  final _tvaCtrl = TextEditingController(text: '0');

  String _regionCode = '971';
  final _electriciteKwhCtrl = TextEditingController(text: '0,50');
  final _tarifElectriciteCtrl = TextEditingController(text: '0,25');
  final _eauM3Ctrl = TextEditingController(text: '0,02');
  final _tarifEauCtrl = TextEditingController(text: '4,50');
  final _transportCtrl = TextEditingController(text: '2');
  final _autresCoutsCtrl = TextEditingController(text: '0');

  final _marketLowCtrl = TextEditingController(text: '39');
  final _marketMidCtrl = TextEditingController(text: '55');
  final _marketHighCtrl = TextEditingController(text: '79');
  final _volumePrudentCtrl = TextEditingController(text: '15');
  final _volumeHautCtrl = TextEditingController(text: '45');
  bool _loadingTariffs = false;
  String? _tariffStatus;

  bool get _isExpert => widget.mode == PricingMode.expert;

  @override
  void dispose() {
    _projectNameCtrl.dispose();
    _prixEnvisageCtrl.dispose();
    _matieresCtrl.dispose();
    _emballageCtrl.dispose();
    _consommablesCtrl.dispose();
    _tempsMinCtrl.dispose();
    _tauxHoraireCtrl.dispose();
    _chargesMensCtrl.dispose();
    _objetsMensCtrl.dispose();
    _materielCtrl.dispose();
    _amortissementUniteCtrl.dispose();
    _fraisPctCtrl.dispose();
    _fraisFixeCtrl.dispose();
    _margeCtrl.dispose();
    _tvaCtrl.dispose();
    _electriciteKwhCtrl.dispose();
    _tarifElectriciteCtrl.dispose();
    _eauM3Ctrl.dispose();
    _tarifEauCtrl.dispose();
    _transportCtrl.dispose();
    _autresCoutsCtrl.dispose();
    _marketLowCtrl.dispose();
    _marketMidCtrl.dispose();
    _marketHighCtrl.dispose();
    _volumePrudentCtrl.dispose();
    _volumeHautCtrl.dispose();
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
    final prixEnvisage = _parseDouble(_prixEnvisageCtrl.text);
    final materiel = _parseDouble(_materielCtrl.text);
    final amortissement = _parseDouble(_amortissementUniteCtrl.text);
    final marge = _parseDouble(_margeCtrl.text);
    final tva = _parseDouble(_tvaCtrl.text);

    final fraisOk = _fraisTypePct
        ? _parseDouble(_fraisPctCtrl.text) >= 0 &&
            _parseDouble(_fraisPctCtrl.text) < 99.9
        : _parseDouble(_fraisFixeCtrl.text) >= 0;
    final amortissementOk = materiel == 0 || amortissement > 0;
    final expertOk = !_isExpert ||
        (_parseDouble(_electriciteKwhCtrl.text) >= 0 &&
            _parseDouble(_tarifElectriciteCtrl.text) >= 0 &&
            _parseDouble(_eauM3Ctrl.text) >= 0 &&
            _parseDouble(_tarifEauCtrl.text) >= 0 &&
            _parseDouble(_transportCtrl.text) >= 0 &&
            _parseDouble(_autresCoutsCtrl.text) >= 0 &&
            _parseDouble(_marketLowCtrl.text) > 0 &&
            _parseDouble(_marketLowCtrl.text) <=
                _parseDouble(_marketMidCtrl.text) &&
            _parseDouble(_marketMidCtrl.text) <=
                _parseDouble(_marketHighCtrl.text) &&
            _parseInt(_volumePrudentCtrl.text) > 0 &&
            _parseInt(_volumePrudentCtrl.text) <= vol &&
            _parseInt(_volumeHautCtrl.text) >= vol);

    return (mat + emb + conso) >= 0 &&
        t > 0 &&
        th > 0 &&
        ch >= 0 &&
        vol > 0 &&
        prixEnvisage >= 0 &&
        materiel >= 0 &&
        amortissement >= 0 &&
        marge >= 0 &&
        tva >= 0 &&
        fraisOk &&
        amortissementOk &&
        expertOk;
  }

  @override
  Widget build(BuildContext context) {
    final modeColor =
        _isExpert ? const Color(0xFF0F4C81) : kPrestoBlue;

    return Scaffold(
      appBar: _PrestoTopBar(
        title: 'iliprestō',
        background: modeColor,
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 16),
          children: [
            Text(
              'Mode ${widget.mode.label}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              _isExpert
                  ? 'Analyse complète : coûts détaillés, marché et scénarios de volume.'
                  : 'Calcul guidé : coûts essentiels, amortissement et prix rentable.',
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _ModeScopeBanner(mode: widget.mode),
            const SizedBox(height: 12),

            _SectionCard(
              headerColor: kPrestoOrange,
              headerIcon: Icons.sell_outlined,
              title: '1. Produit, service et prix envisagé',
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('project-name'),
                    controller: _projectNameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nom du produit ou service',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.price_check_outlined,
                    label: 'Prix TTC envisagé',
                    controller: _prixEnvisageCtrl,
                    suffix: '€',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  const _InlineHelp(
                    text:
                        'Ce prix est comparé au prix minimum rentable. Il ne remplace pas le prix conseillé calculé.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              headerColor: kPrestoOrange,
              headerIcon: Icons.inventory_2_outlined,
              title: '2. Coûts directs par unité',
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

            _SectionCard(
              headerColor: kPrestoBlue,
              headerIcon: Icons.timer_outlined,
              title: "3. Temps & main-d'œuvre",
              child: Column(
                children: [
                  _RowField(
                    icon: Icons.schedule_outlined,
                    label: 'Temps par unité',
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

            _SectionCard(
              headerColor: kPrestoBlue,
              headerIcon: Icons.home_work_outlined,
              title: '4. Charges fixes et volume cible',
              subtitle:
                  '${_money(_parseDouble(_chargesMensCtrl.text))} € / ${math.max(_parseInt(_objetsMensCtrl.text), 0)} unités',
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
                    label: 'Unités / mois',
                    controller: _objetsMensCtrl,
                    suffix: 'nb',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _MiniInfoPill(
                    icon: Icons.calculate_outlined,
                    text:
                        'Charge estimée : ${_money(_chargeFixeUnitaire())} € par unité',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              headerColor: kPrestoOrange,
              headerIcon: Icons.precision_manufacturing_outlined,
              title: '5. Amortissement du matériel',
              child: Column(
                children: [
                  _RowField(
                    icon: Icons.handyman_outlined,
                    label: 'Matériel à amortir',
                    controller: _materielCtrl,
                    suffix: '€',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.savings_outlined,
                    label: 'Part par unité',
                    controller: _amortissementUniteCtrl,
                    suffix: '€',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _MiniInfoPill(
                    icon: Icons.timelapse_rounded,
                    text: _amortizationPreview(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_isExpert) ...[
              _SectionCard(
                headerColor: const Color(0xFF0F4C81),
                headerIcon: Icons.bolt_outlined,
                title: '6. Coûts avancés et tarifs régionaux',
                subtitle: 'Électricité, eau, transport et autres coûts',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('expert-region'),
                      initialValue: _regionCode,
                      decoration: InputDecoration(
                        labelText: 'Territoire tarifaire',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '971', child: Text('Guadeloupe (971)')),
                        DropdownMenuItem(
                            value: '972', child: Text('Martinique (972)')),
                        DropdownMenuItem(
                            value: '973', child: Text('Guyane (973)')),
                        DropdownMenuItem(
                            value: '974', child: Text('La Réunion (974)')),
                        DropdownMenuItem(
                            value: '976', child: Text('Mayotte (976)')),
                        DropdownMenuItem(
                            value: 'HEX', child: Text('France hexagonale')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _regionCode = value);
                        _loadRegionalTariffs();
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          _loadingTariffs ? null : _loadRegionalTariffs,
                      icon: _loadingTariffs
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _loadingTariffs
                            ? 'Actualisation…'
                            : 'Actualiser les tarifs régionaux',
                      ),
                    ),
                    if (_tariffStatus != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _tariffStatus!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _RowField(
                      icon: Icons.electric_bolt_outlined,
                      label: 'Électricité / unité',
                      controller: _electriciteKwhCtrl,
                      suffix: 'kWh',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _RowField(
                      icon: Icons.euro_outlined,
                      label: 'Tarif électricité',
                      controller: _tarifElectriciteCtrl,
                      suffix: '€/kWh',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _RowField(
                      icon: Icons.water_drop_outlined,
                      label: 'Eau / unité',
                      controller: _eauM3Ctrl,
                      suffix: 'm³',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _RowField(
                      icon: Icons.euro_outlined,
                      label: 'Tarif eau',
                      controller: _tarifEauCtrl,
                      suffix: '€/m³',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _RowField(
                      icon: Icons.local_shipping_outlined,
                      label: 'Transport / unité',
                      controller: _transportCtrl,
                      suffix: '€',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _RowField(
                      icon: Icons.add_card_outlined,
                      label: 'Autres coûts / unité',
                      controller: _autresCoutsCtrl,
                      suffix: '€',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    const _InlineHelp(
                      text:
                          'Les tarifs restent modifiables afin de refléter la facture réelle de ton activité.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _SectionCard(
              headerColor: kPrestoOrange,
              headerIcon: Icons.tune_rounded,
              title: _isExpert
                  ? '7. Frais, marge et fiscalité'
                  : '6. Frais, marge et fiscalité',
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
                      label: 'Frais de vente externes',
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
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.trending_up_rounded,
                    label: 'Marge souhaitée',
                    controller: _margeCtrl,
                    suffix: '%',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _RowField(
                    icon: Icons.account_balance_outlined,
                    label: 'TVA applicable',
                    controller: _tvaCtrl,
                    suffix: '%',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  const _InlineHelp(
                    text:
                        "Les frais saisis sont tes frais externes réels. iliprestō n'ajoute aucune commission.",
                  ),
                ],
              ),
            ),

            if (_isExpert) ...[
              const SizedBox(height: 12),
              _SectionCard(
                headerColor: const Color(0xFF0F4C81),
                headerIcon: Icons.query_stats_outlined,
                title: '8. Analyse du marché',
                subtitle: 'Fourchette observée pour une offre comparable',
                child: _MarketMiniCard(
                  lowCtrl: _marketLowCtrl,
                  midCtrl: _marketMidCtrl,
                  highCtrl: _marketHighCtrl,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                headerColor: const Color(0xFF0F4C81),
                headerIcon: Icons.insights_outlined,
                title: '9. Scénarios de volume',
                child: Column(
                  children: [
                    _RowField(
                      icon: Icons.south_east_rounded,
                      label: 'Volume prudent',
                      controller: _volumePrudentCtrl,
                      suffix: 'nb',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _MiniInfoPill(
                      icon: Icons.horizontal_rule_rounded,
                      text:
                          'Volume cible : ${math.max(_parseInt(_objetsMensCtrl.text), 0)} unités / mois',
                    ),
                    const SizedBox(height: 10),
                    _RowField(
                      icon: Icons.north_east_rounded,
                      label: 'Volume haut',
                      controller: _volumeHautCtrl,
                      suffix: 'nb',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            _PrestoPrimaryButton(
              text: _isExpert
                  ? 'Lancer mon analyse experte'
                  : 'Calculer mon prix conseillé',
              background: kPrestoOrange,
              onTap: _canCompute
                  ? () {
                      final input = _collectInputs();
                      final result = PricingEngine.compute(input);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ResultsPage(
                            mode: widget.mode,
                            projectName: _projectNameCtrl.text.trim(),
                            input: input,
                            result: result,
                            marketLow: _isExpert
                                ? _parseDouble(_marketLowCtrl.text)
                                : 0,
                            marketMid: _isExpert
                                ? _parseDouble(_marketMidCtrl.text)
                                : 0,
                            marketHigh: _isExpert
                                ? _parseDouble(_marketHighCtrl.text)
                                : 0,
                            volumePrudent: _isExpert
                                ? math.max(
                                    _parseInt(_volumePrudentCtrl.text), 1)
                                : input.volumeMensuel,
                            volumeHaut: _isExpert
                                ? math.max(_parseInt(_volumeHautCtrl.text), 1)
                                : input.volumeMensuel,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            if (!_canCompute) ...[
              const SizedBox(height: 8),
              Text(
                _isExpert
                    ? 'Vérifie les valeurs, la fourchette marché et l’ordre des volumes prudent ≤ cible ≤ haut.'
                    : 'Vérifie les valeurs obligatoires et la part d’amortissement.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
      margePctSurCout: _parseDouble(_margeCtrl.text) / 100.0,
      tvaPct: _parseDouble(_tvaCtrl.text) / 100.0,
      prixVenteTtcEnvisage: _parseDouble(_prixEnvisageCtrl.text),
      materielAAmortir: _parseDouble(_materielCtrl.text),
      amortissementParUnite: _parseDouble(_amortissementUniteCtrl.text),
      electriciteKwhParUnite:
          _isExpert ? _parseDouble(_electriciteKwhCtrl.text) : 0,
      tarifElectriciteKwh:
          _isExpert ? _parseDouble(_tarifElectriciteCtrl.text) : 0,
      eauM3ParUnite: _isExpert ? _parseDouble(_eauM3Ctrl.text) : 0,
      tarifEauM3: _isExpert ? _parseDouble(_tarifEauCtrl.text) : 0,
      transportParUnite: _isExpert ? _parseDouble(_transportCtrl.text) : 0,
      autresCoutsParUnite:
          _isExpert ? _parseDouble(_autresCoutsCtrl.text) : 0,
      regionCode: _isExpert ? _regionCode : '',
    );
  }

  double _chargeFixeUnitaire() {
    final charges = _parseDouble(_chargesMensCtrl.text);
    final vol = math.max(_parseInt(_objetsMensCtrl.text), 1);
    return charges / vol;
  }

  String _amortizationPreview() {
    final total = _parseDouble(_materielCtrl.text);
    final share = _parseDouble(_amortissementUniteCtrl.text);
    if (total <= 0) return 'Aucun matériel à amortir.';
    if (share <= 0) {
      return "Indique la part d'amortissement incluse dans chaque unité.";
    }
    final units = (total / share).ceil();
    return '$units unités nécessaires pour amortir ${_money(total)} €.';
  }

  Future<void> _loadRegionalTariffs() async {
    if (_loadingTariffs) return;
    setState(() {
      _loadingTariffs = true;
      _tariffStatus = null;
    });
    try {
      final tariffs =
          await PricingRegionalTariffRepository().load(_regionCode);
      if (!mounted) return;
      if (tariffs == null) {
        setState(() {
          _tariffStatus =
              'Aucun tarif publié pour ce territoire : conserve les valeurs de ta facture.';
        });
        return;
      }
      setState(() {
        if (tariffs.electricityPerKwh != null) {
          _tarifElectriciteCtrl.text =
              _money(tariffs.electricityPerKwh!);
        }
        if (tariffs.waterPerM3 != null) {
          _tarifEauCtrl.text = _money(tariffs.waterPerM3!);
        }
        _tariffStatus = tariffs.updatedAt == null
            ? 'Tarifs régionaux chargés.'
            : 'Tarifs mis à jour le ${_formatDate(tariffs.updatedAt!)}.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tariffStatus =
            'Tarifs indisponibles : les valeurs restent modifiables manuellement.';
      });
    } finally {
      if (mounted) setState(() => _loadingTariffs = false);
    }
  }
}

// ---------------------------
// UI COMPONENTS
// ---------------------------
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

// ---------------------------
// HELPERS
// ---------------------------
String _money(double v) {
  final fixed = v.isFinite ? v.toStringAsFixed(2) : '0.00';
  return fixed.replaceAll('.', ',');
}

double _jsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _jsonInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}
