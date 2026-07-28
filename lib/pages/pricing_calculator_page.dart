import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../constants.dart';

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
// RESULTS (Screen 3)
// ---------------------------
class _ResultsPage extends StatefulWidget {
  final PricingMode mode;
  final String projectName;
  final PricingInput input;
  final PricingResult result;
  final double marketLow;
  final double marketMid;
  final double marketHigh;
  final int volumePrudent;
  final int volumeHaut;

  const _ResultsPage({
    required this.mode,
    required this.projectName,
    required this.input,
    required this.result,
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
    required this.volumePrudent,
    required this.volumeHaut,
  });

  @override
  State<_ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<_ResultsPage> {
  bool _saving = false;
  bool _exporting = false;

  bool get _isExpert => widget.mode == PricingMode.expert;

  @override
  Widget build(BuildContext context) {
    final market = MarketPositioning.evaluate(
      price: widget.result.prixTTC,
      low: widget.marketLow,
      mid: widget.marketMid,
      high: widget.marketHigh,
    );
    final scenarios = _isExpert
        ? [
            PricingEngine.computeScenario(
              widget.input,
              name: 'Prudent',
              volume: widget.volumePrudent,
            ),
            PricingEngine.computeScenario(
              widget.input,
              name: 'Cible',
              volume: widget.input.volumeMensuel,
            ),
            PricingEngine.computeScenario(
              widget.input,
              name: 'Haut',
              volume: widget.volumeHaut,
            ),
          ]
        : const <PricingScenarioResult>[];

    return Scaffold(
      appBar: _PrestoTopBar(
        title: 'iliprestō',
        background: _isExpert ? const Color(0xFF0F4C81) : kPrestoBlue,
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            Text(
              _isExpert ? 'Analyse experte' : 'Résultats Standard',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            if (widget.projectName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.projectName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),

            _ResultSummaryCard(result: widget.result),
            const SizedBox(height: 14),
            _ViabilityCard(result: widget.result),
            const SizedBox(height: 14),
            _AmortizationCard(result: widget.result),

            if (_isExpert) ...[
              const SizedBox(height: 14),
              _CostBreakdownCard(result: widget.result),
              const SizedBox(height: 14),
              _MarketCard(
                marketLow: widget.marketLow,
                marketMid: widget.marketMid,
                marketHigh: widget.marketHigh,
                price: widget.result.prixTTC,
                label: market.label,
                hint: market.hint,
                levelColor: market.color,
              ),
              const SizedBox(height: 14),
              _ScenarioCard(
                scenarios: scenarios,
                breakEvenUnits: widget.result.seuilRentabiliteUnites,
              ),
              const SizedBox(height: 16),
              _PrestoPrimaryButton(
                text: _saving ? 'Sauvegarde…' : 'Sauvegarder cette analyse',
                background: kPrestoBlue,
                onTap: _saving ? null : _saveAnalysis,
                icon: Icons.save_outlined,
              ),
              const SizedBox(height: 10),
              _PrestoPrimaryButton(
                text: _exporting ? 'Préparation du PDF…' : 'Exporter en PDF',
                background: const Color(0xFF0F4C81),
                onTap: _exporting ? null : _exportPdf,
                icon: Icons.picture_as_pdf_outlined,
              ),
            ],

            const SizedBox(height: 10),
            _PrestoPrimaryButton(
              text: 'Ajuster mes hypothèses',
              background: kPrestoOrange,
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAnalysis() async {
    setState(() => _saving = true);
    try {
      final record = PricingProjectRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        name: widget.projectName.isEmpty
            ? 'Calcul sans nom'
            : widget.projectName,
        mode: widget.mode,
        input: widget.input,
        result: widget.result,
        marketLow: widget.marketLow,
        marketMid: widget.marketMid,
        marketHigh: widget.marketHigh,
        volumePrudent: widget.volumePrudent,
        volumeHaut: widget.volumeHaut,
      );
      await PricingProjectStorage.save(record);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyse enregistrée sur cet appareil.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("L'analyse n'a pas pu être enregistrée."),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final scenarios = [
        PricingEngine.computeScenario(
          widget.input,
          name: 'Prudent',
          volume: widget.volumePrudent,
        ),
        PricingEngine.computeScenario(
          widget.input,
          name: 'Cible',
          volume: widget.input.volumeMensuel,
        ),
        PricingEngine.computeScenario(
          widget.input,
          name: 'Haut',
          volume: widget.volumeHaut,
        ),
      ];
      final bytes = await PricingPdfExporter.build(
        projectName: widget.projectName,
        input: widget.input,
        result: widget.result,
        scenarios: scenarios,
        market: MarketPositioning.evaluate(
          price: widget.result.prixTTC,
          low: widget.marketLow,
          mid: widget.marketMid,
          high: widget.marketHigh,
        ),
      );
      final safeName = widget.projectName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name:
                'ilipresto-calcul-${safeName.isEmpty ? 'prix' : safeName}.pdf',
          ),
        ],
        subject: "Calcul de prix iliprestō",
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'export PDF a échoué.")),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
  final double prixVenteTtcEnvisage;
  final double materielAAmortir;
  final double amortissementParUnite;
  final double electriciteKwhParUnite;
  final double tarifElectriciteKwh;
  final double eauM3ParUnite;
  final double tarifEauM3;
  final double transportParUnite;
  final double autresCoutsParUnite;
  final String regionCode;

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
    this.prixVenteTtcEnvisage = 0,
    this.materielAAmortir = 0,
    this.amortissementParUnite = 0,
    this.electriciteKwhParUnite = 0,
    this.tarifElectriciteKwh = 0,
    this.eauM3ParUnite = 0,
    this.tarifEauM3 = 0,
    this.transportParUnite = 0,
    this.autresCoutsParUnite = 0,
    this.regionCode = '',
  });

  Map<String, dynamic> toJson() => {
        'matieres': matieres,
        'emballage': emballage,
        'consommables': consommables,
        'tempsFabricationMin': tempsFabricationMin,
        'tauxHoraire': tauxHoraire,
        'chargesMensuelles': chargesMensuelles,
        'volumeMensuel': volumeMensuel,
        'fraisVentePct': fraisVentePct,
        'fraisVenteFixe': fraisVenteFixe,
        'margePctSurCout': margePctSurCout,
        'tvaPct': tvaPct,
        'prixVenteTtcEnvisage': prixVenteTtcEnvisage,
        'materielAAmortir': materielAAmortir,
        'amortissementParUnite': amortissementParUnite,
        'electriciteKwhParUnite': electriciteKwhParUnite,
        'tarifElectriciteKwh': tarifElectriciteKwh,
        'eauM3ParUnite': eauM3ParUnite,
        'tarifEauM3': tarifEauM3,
        'transportParUnite': transportParUnite,
        'autresCoutsParUnite': autresCoutsParUnite,
        'regionCode': regionCode,
      };

  factory PricingInput.fromJson(Map<String, dynamic> json) {
    return PricingInput(
      matieres: _jsonDouble(json['matieres']),
      emballage: _jsonDouble(json['emballage']),
      consommables: _jsonDouble(json['consommables']),
      tempsFabricationMin: _jsonInt(json['tempsFabricationMin']),
      tauxHoraire: _jsonDouble(json['tauxHoraire']),
      chargesMensuelles: _jsonDouble(json['chargesMensuelles']),
      volumeMensuel: math.max(_jsonInt(json['volumeMensuel']), 1),
      fraisVentePct: _jsonDouble(json['fraisVentePct']),
      fraisVenteFixe: _jsonDouble(json['fraisVenteFixe']),
      margePctSurCout: _jsonDouble(json['margePctSurCout']),
      tvaPct: _jsonDouble(json['tvaPct']),
      prixVenteTtcEnvisage:
          _jsonDouble(json['prixVenteTtcEnvisage']),
      materielAAmortir: _jsonDouble(json['materielAAmortir']),
      amortissementParUnite:
          _jsonDouble(json['amortissementParUnite']),
      electriciteKwhParUnite:
          _jsonDouble(json['electriciteKwhParUnite']),
      tarifElectriciteKwh:
          _jsonDouble(json['tarifElectriciteKwh']),
      eauM3ParUnite: _jsonDouble(json['eauM3ParUnite']),
      tarifEauM3: _jsonDouble(json['tarifEauM3']),
      transportParUnite: _jsonDouble(json['transportParUnite']),
      autresCoutsParUnite:
          _jsonDouble(json['autresCoutsParUnite']),
      regionCode: json['regionCode']?.toString() ?? '',
    );
  }
}

class PricingResult {
  final double coutDirect;
  final double coutEnergieEau;
  final double coutTransportAutres;
  final double coutMainOeuvre;
  final double chargeFixeUnitaire;
  final double amortissementUnitaire;
  final double coutDeRevient; // CR (hors frais % sur prix)
  final double prixMinimumRentable;
  final double prixMinimumRentableTtc;
  final double prixConseille;
  final double prixTTC;
  final double margeUnitaireEnvisagee;
  final double margeUnitaireConseillee;
  final int unitesPourAmortir;
  final int seuilRentabiliteUnites;
  final bool prixEnvisageRentable;

  const PricingResult({
    required this.coutDirect,
    required this.coutEnergieEau,
    required this.coutTransportAutres,
    required this.coutMainOeuvre,
    required this.chargeFixeUnitaire,
    required this.amortissementUnitaire,
    required this.coutDeRevient,
    required this.prixMinimumRentable,
    required this.prixMinimumRentableTtc,
    required this.prixConseille,
    required this.prixTTC,
    required this.margeUnitaireEnvisagee,
    required this.margeUnitaireConseillee,
    required this.unitesPourAmortir,
    required this.seuilRentabiliteUnites,
    required this.prixEnvisageRentable,
  });

  Map<String, dynamic> toJson() => {
        'coutDirect': coutDirect,
        'coutEnergieEau': coutEnergieEau,
        'coutTransportAutres': coutTransportAutres,
        'coutMainOeuvre': coutMainOeuvre,
        'chargeFixeUnitaire': chargeFixeUnitaire,
        'amortissementUnitaire': amortissementUnitaire,
        'coutDeRevient': coutDeRevient,
        'prixMinimumRentable': prixMinimumRentable,
        'prixMinimumRentableTtc': prixMinimumRentableTtc,
        'prixConseille': prixConseille,
        'prixTTC': prixTTC,
        'margeUnitaireEnvisagee': margeUnitaireEnvisagee,
        'margeUnitaireConseillee': margeUnitaireConseillee,
        'unitesPourAmortir': unitesPourAmortir,
        'seuilRentabiliteUnites': seuilRentabiliteUnites,
        'prixEnvisageRentable': prixEnvisageRentable,
      };

  factory PricingResult.fromJson(Map<String, dynamic> json) {
    return PricingResult(
      coutDirect: _jsonDouble(json['coutDirect']),
      coutEnergieEau: _jsonDouble(json['coutEnergieEau']),
      coutTransportAutres:
          _jsonDouble(json['coutTransportAutres']),
      coutMainOeuvre: _jsonDouble(json['coutMainOeuvre']),
      chargeFixeUnitaire:
          _jsonDouble(json['chargeFixeUnitaire']),
      amortissementUnitaire:
          _jsonDouble(json['amortissementUnitaire']),
      coutDeRevient: _jsonDouble(json['coutDeRevient']),
      prixMinimumRentable:
          _jsonDouble(json['prixMinimumRentable']),
      prixMinimumRentableTtc:
          _jsonDouble(json['prixMinimumRentableTtc']),
      prixConseille: _jsonDouble(json['prixConseille']),
      prixTTC: _jsonDouble(json['prixTTC']),
      margeUnitaireEnvisagee:
          _jsonDouble(json['margeUnitaireEnvisagee']),
      margeUnitaireConseillee:
          _jsonDouble(json['margeUnitaireConseillee']),
      unitesPourAmortir: _jsonInt(json['unitesPourAmortir']),
      seuilRentabiliteUnites:
          _jsonInt(json['seuilRentabiliteUnites']),
      prixEnvisageRentable:
          json['prixEnvisageRentable'] == true,
    );
  }
}

class PricingScenarioResult {
  final String name;
  final int volume;
  final double chiffreAffairesTtc;
  final double beneficeMensuel;
  final double beneficeParUnite;

  const PricingScenarioResult({
    required this.name,
    required this.volume,
    required this.chiffreAffairesTtc,
    required this.beneficeMensuel,
    required this.beneficeParUnite,
  });
}

class PricingEngine {
  static PricingResult compute(PricingInput i) {
    final coutEnergie =
        (i.electriciteKwhParUnite * i.tarifElectriciteKwh) +
            (i.eauM3ParUnite * i.tarifEauM3);
    final transportAutres = i.transportParUnite + i.autresCoutsParUnite;
    final coutDirect = i.matieres +
        i.emballage +
        i.consommables +
        coutEnergie +
        transportAutres;
    final coutMO = (i.tempsFabricationMin / 60.0) * i.tauxHoraire;
    final chargeFixe = i.chargesMensuelles / math.max(i.volumeMensuel, 1);
    final amortissement = math.max(i.amortissementParUnite, 0);
    final crHorsFraisPct =
        coutDirect + coutMO + chargeFixe + amortissement;

    final prixMin = _applyFeesToReachNet(
      targetNet: crHorsFraisPct + i.fraisVenteFixe,
      fraisPct: i.fraisVentePct,
    );
    final netCible =
        (crHorsFraisPct * (1 + i.margePctSurCout)) + i.fraisVenteFixe;
    final prixConseille = _applyFeesToReachNet(
      targetNet: netCible,
      fraisPct: i.fraisVentePct,
    );

    final prixMinTtc = prixMin * (1 + i.tvaPct);
    final prixTTC = prixConseille * (1 + i.tvaPct);
    final prixEnvisageHt =
        i.prixVenteTtcEnvisage / (1 + math.max(i.tvaPct, 0));
    final fraisEnvisages =
        (prixEnvisageHt * i.fraisVentePct.clamp(0.0, 0.999)) +
            i.fraisVenteFixe;
    final margeEnvisagee =
        prixEnvisageHt - crHorsFraisPct - fraisEnvisages;
    final fraisConseilles =
        (prixConseille * i.fraisVentePct.clamp(0.0, 0.999)) +
            i.fraisVenteFixe;
    final margeConseillee =
        prixConseille - crHorsFraisPct - fraisConseilles;

    final unitesPourAmortir =
        i.materielAAmortir > 0 && amortissement > 0
            ? (i.materielAAmortir / amortissement).ceil()
            : 0;

    final prixReferenceTtc =
        i.prixVenteTtcEnvisage > 0 ? i.prixVenteTtcEnvisage : prixTTC;
    final prixReferenceHt =
        prixReferenceTtc / (1 + math.max(i.tvaPct, 0));
    final fraisReference =
        (prixReferenceHt * i.fraisVentePct.clamp(0.0, 0.999)) +
            i.fraisVenteFixe;
    final coutVariable =
        coutDirect + coutMO + amortissement;
    final contribution =
        prixReferenceHt - fraisReference - coutVariable;
    final seuilRentabilite = i.chargesMensuelles <= 0
        ? 0
        : contribution > 0
            ? (i.chargesMensuelles / contribution).ceil()
            : 0;

    return PricingResult(
      coutDirect: coutDirect,
      coutEnergieEau: coutEnergie,
      coutTransportAutres: transportAutres,
      coutMainOeuvre: coutMO,
      chargeFixeUnitaire: chargeFixe,
      amortissementUnitaire: amortissement,
      coutDeRevient: crHorsFraisPct,
      prixMinimumRentable: prixMin,
      prixMinimumRentableTtc: prixMinTtc,
      prixConseille: prixConseille,
      prixTTC: prixTTC,
      margeUnitaireEnvisagee: margeEnvisagee,
      margeUnitaireConseillee: margeConseillee,
      unitesPourAmortir: unitesPourAmortir,
      seuilRentabiliteUnites: seuilRentabilite,
      prixEnvisageRentable:
          i.prixVenteTtcEnvisage > 0 && margeEnvisagee >= 0,
    );
  }

  static PricingScenarioResult computeScenario(
    PricingInput input, {
    required String name,
    required int volume,
  }) {
    final safeVolume = math.max(volume, 1);
    final result = compute(input);
    final priceTtc = input.prixVenteTtcEnvisage > 0
        ? input.prixVenteTtcEnvisage
        : result.prixTTC;
    final priceHt = priceTtc / (1 + math.max(input.tvaPct, 0));
    final coutEnergie =
        (input.electriciteKwhParUnite * input.tarifElectriciteKwh) +
            (input.eauM3ParUnite * input.tarifEauM3);
    final coutVariable = input.matieres +
        input.emballage +
        input.consommables +
        coutEnergie +
        input.transportParUnite +
        input.autresCoutsParUnite +
        ((input.tempsFabricationMin / 60.0) * input.tauxHoraire) +
        input.amortissementParUnite;
    final fraisUnitaire =
        (priceHt * input.fraisVentePct.clamp(0.0, 0.999)) +
            input.fraisVenteFixe;
    final beneficeMensuel =
        ((priceHt - coutVariable - fraisUnitaire) * safeVolume) -
            input.chargesMensuelles;

    return PricingScenarioResult(
      name: name,
      volume: safeVolume,
      chiffreAffairesTtc: priceTtc * safeVolume,
      beneficeMensuel: beneficeMensuel,
      beneficeParUnite: beneficeMensuel / safeVolume,
    );
  }

  static double _applyFeesToReachNet({
    required double targetNet,
    required double fraisPct,
  }) {
    final p = fraisPct.clamp(0.0, 0.999);
    return targetNet / (1.0 - p);
  }
}

class PricingRegionalTariffs {
  final double? electricityPerKwh;
  final double? waterPerM3;
  final DateTime? updatedAt;

  const PricingRegionalTariffs({
    required this.electricityPerKwh,
    required this.waterPerM3,
    required this.updatedAt,
  });
}

class PricingRegionalTariffRepository {
  final FirebaseFirestore? firestore;

  const PricingRegionalTariffRepository({this.firestore});

  Future<PricingRegionalTariffs?> load(String regionCode) async {
    if (firestore == null && Firebase.apps.isEmpty) return null;
    final database = firestore ?? FirebaseFirestore.instance;
    final snapshots = await Future.wait([
      database.collection('tarifs_electricite').doc(regionCode).get(),
      database.collection('tarifs_eau').doc(regionCode).get(),
    ]);
    final electricity = snapshots[0].data();
    final water = snapshots[1].data();
    if (electricity == null && water == null) return null;

    final electricityRate = _firstNumber(
      electricity,
      const ['prixKwh', 'pricePerKwh', 'tarifKwh', 'value'],
    );
    final waterRate = _firstNumber(
      water,
      const ['prixM3', 'pricePerM3', 'tarifM3', 'value'],
    );
    if (electricityRate == null && waterRate == null) return null;

    final electricityDate = _firstDate(electricity);
    final waterDate = _firstDate(water);
    final dates = [
      if (electricityDate != null) electricityDate,
      if (waterDate != null) waterDate,
    ]..sort();

    return PricingRegionalTariffs(
      electricityPerKwh: electricityRate,
      waterPerM3: waterRate,
      updatedAt: dates.isEmpty ? null : dates.last,
    );
  }

  static double? _firstNumber(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _firstDate(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in const ['updatedAt', 'effectiveAt', 'date']) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }
}

// ---------------------------
// LOCAL HISTORY + PDF EXPORT
// ---------------------------
class PricingProjectRecord {
  final String id;
  final DateTime createdAt;
  final String name;
  final PricingMode mode;
  final PricingInput input;
  final PricingResult result;
  final double marketLow;
  final double marketMid;
  final double marketHigh;
  final int volumePrudent;
  final int volumeHaut;

  const PricingProjectRecord({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.mode,
    required this.input,
    required this.result,
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
    required this.volumePrudent,
    required this.volumeHaut,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        'mode': mode.name,
        'input': input.toJson(),
        'result': result.toJson(),
        'marketLow': marketLow,
        'marketMid': marketMid,
        'marketHigh': marketHigh,
        'volumePrudent': volumePrudent,
        'volumeHaut': volumeHaut,
      };

  factory PricingProjectRecord.fromJson(Map<String, dynamic> json) {
    return PricingProjectRecord(
      id: json['id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      name: json['name']?.toString() ?? 'Calcul sans nom',
      mode: json['mode'] == PricingMode.expert.name
          ? PricingMode.expert
          : PricingMode.standard,
      input: PricingInput.fromJson(
        Map<String, dynamic>.from(json['input'] as Map? ?? const {}),
      ),
      result: PricingResult.fromJson(
        Map<String, dynamic>.from(json['result'] as Map? ?? const {}),
      ),
      marketLow: _jsonDouble(json['marketLow']),
      marketMid: _jsonDouble(json['marketMid']),
      marketHigh: _jsonDouble(json['marketHigh']),
      volumePrudent: math.max(_jsonInt(json['volumePrudent']), 1),
      volumeHaut: math.max(_jsonInt(json['volumeHaut']), 1),
    );
  }
}

class PricingProjectStorage {
  static const _storageKey = 'ilipresto_pricing_projects_v2';
  static const _maxProjects = 30;

  static Future<List<PricingProjectRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <PricingProjectRecord>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PricingProjectRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => PricingProjectRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return <PricingProjectRecord>[];
    }
  }

  static Future<void> save(PricingProjectRecord record) async {
    final projects = await load();
    projects.removeWhere((item) => item.id == record.id);
    projects.insert(0, record);
    if (projects.length > _maxProjects) {
      projects.removeRange(_maxProjects, projects.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(projects.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> delete(String id) async {
    final projects = await load();
    projects.removeWhere((item) => item.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(projects.map((item) => item.toJson()).toList()),
    );
  }
}

class PricingPdfExporter {
  static Future<Uint8List> build({
    required String projectName,
    required PricingInput input,
    required PricingResult result,
    required List<PricingScenarioResult> scenarios,
    required MarketEval market,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(
            'iliprestō',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.deepOrange,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            "Calculatrice de l'entrepreneur — Analyse Expert",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 18),
          _pdfSectionTitle(projectName.isEmpty ? 'Calcul sans nom' : projectName),
          _pdfRows([
            ['Prix TTC envisagé', '${_money(input.prixVenteTtcEnvisage)} €'],
            ['Coût de revient', '${_money(result.coutDeRevient)} €'],
            [
              'Prix minimum rentable TTC',
              '${_money(result.prixMinimumRentableTtc)} €'
            ],
            ['Prix conseillé TTC', '${_money(result.prixTTC)} €'],
            [
              'Marge du prix envisagé',
              '${_money(result.margeUnitaireEnvisagee)} € / unité'
            ],
          ]),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Détail des coûts par unité'),
          _pdfRows([
            ['Coûts directs', '${_money(result.coutDirect)} €'],
            ['Énergie et eau', '${_money(result.coutEnergieEau)} €'],
            [
              'Transport et autres',
              '${_money(result.coutTransportAutres)} €'
            ],
            ['Main-d’œuvre', '${_money(result.coutMainOeuvre)} €'],
            ['Charges fixes', '${_money(result.chargeFixeUnitaire)} €'],
            [
              'Amortissement',
              '${_money(result.amortissementUnitaire)} €'
            ],
          ]),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Rentabilité'),
          _pdfRows([
            [
              'Unités pour amortir le matériel',
              result.unitesPourAmortir == 0
                  ? 'Non applicable'
                  : '${result.unitesPourAmortir}'
            ],
            [
              'Seuil de rentabilité',
              result.seuilRentabiliteUnites == 0
                  ? 'Non calculable'
                  : '${result.seuilRentabiliteUnites} unités / mois'
            ],
            ['Positionnement marché', market.label],
          ]),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Scénarios mensuels'),
          pw.TableHelper.fromTextArray(
            headers: const ['Scénario', 'Volume', 'CA TTC', 'Résultat'],
            data: scenarios
                .map(
                  (scenario) => [
                    scenario.name,
                    '${scenario.volume}',
                    '${_money(scenario.chiffreAffairesTtc)} €',
                    '${_money(scenario.beneficeMensuel)} €',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
            cellPadding: const pw.EdgeInsets.all(7),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Simulation indicative fondée sur les informations saisies. '
            'Vérifie tes obligations fiscales, sociales et réglementaires '
            'auprès des organismes compétents.',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue,
        ),
      ),
    );
  }

  static pw.Widget _pdfRows(List<List<String>> rows) {
    return pw.Column(
      children: rows
          .map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text(row[0])),
                  pw.Text(
                    row[1],
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PricingHistoryPage extends StatefulWidget {
  const _PricingHistoryPage();

  @override
  State<_PricingHistoryPage> createState() => _PricingHistoryPageState();
}

class _PricingHistoryPageState extends State<_PricingHistoryPage> {
  late Future<List<PricingProjectRecord>> _projects;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _projects = PricingProjectStorage.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _PrestoTopBar(
        title: 'Mes calculs',
        background: kPrestoBlue,
        showBack: true,
      ),
      body: FutureBuilder<List<PricingProjectRecord>>(
        future: _projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snapshot.data ?? const [];
          if (projects.isEmpty) {
            return const _EmptyHistory();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kPrestoBlue.withValues(alpha: 0.12),
                    foregroundColor: kPrestoBlue,
                    child: const Icon(Icons.calculate_outlined),
                  ),
                  title: Text(
                    project.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${project.mode.label} • ${_formatDate(project.createdAt)}\n'
                    'Prix conseillé : ${_money(project.result.prixTTC)} € TTC',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await PricingProjectStorage.delete(project.id);
                      if (!mounted) return;
                      setState(_reload);
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ResultsPage(
                          mode: project.mode,
                          projectName: project.name,
                          input: project.input,
                          result: project.result,
                          marketLow: project.marketLow,
                          marketMid: project.marketMid,
                          marketHigh: project.marketHigh,
                          volumePrudent: project.volumePrudent,
                          volumeHaut: project.volumeHaut,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              'Aucun calcul enregistré',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Les analyses Expert sauvegardées apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
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
class _ModeScopeBanner extends StatelessWidget {
  final PricingMode mode;

  const _ModeScopeBanner({required this.mode});

  @override
  Widget build(BuildContext context) {
    final expert = mode == PricingMode.expert;
    final color = expert ? const Color(0xFF0F4C81) : kPrestoBlue;
    final items = expert
        ? const [
            'Tous les calculs Standard',
            'Énergie, eau, transport et territoire',
            'Marché, scénarios, historique et PDF',
          ]
        : const [
            'Coûts directs et temps de travail',
            'Charges fixes et amortissement',
            'Prix minimum, prix conseillé et alerte de perte',
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expert ? 'Ce mode ajoute' : 'Ce mode comprend',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 17, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineHelp extends StatelessWidget {
  final String text;

  const _InlineHelp({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 17, color: Colors.black45),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

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
              value: '${_money(result.prixMinimumRentableTtc)} € TTC'),
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
                  '${_money(result.prixTTC)} €',
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

class _ViabilityCard extends StatelessWidget {
  final PricingResult result;

  const _ViabilityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final profitable = result.prixEnvisageRentable;
    final color =
        profitable ? const Color(0xFF168A50) : const Color(0xFFC62828);
    final title = profitable
        ? 'Ton prix envisagé est rentable'
        : 'À ce prix, tu perds de l’argent';
    final message = profitable
        ? 'Marge estimée : ${_money(result.margeUnitaireEnvisagee)} € par unité.'
        : 'Écart estimé : ${_money(result.margeUnitaireEnvisagee.abs())} € à récupérer par unité.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            profitable
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _AmortizationCard extends StatelessWidget {
  final PricingResult result;

  const _AmortizationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasAmortization = result.unitesPourAmortir > 0;
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amortissement & seuil',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ResultRow(
            label: 'Part amortissement',
            value: '${_money(result.amortissementUnitaire)} € / unité',
          ),
          const SizedBox(height: 10),
          _ResultRow(
            label: 'Matériel amorti après',
            value: hasAmortization
                ? '${result.unitesPourAmortir} unités'
                : 'Non applicable',
          ),
          const SizedBox(height: 10),
          _ResultRow(
            label: 'Seuil mensuel',
            value: result.seuilRentabiliteUnites > 0
                ? '${result.seuilRentabiliteUnites} unités'
                : 'Non calculable',
          ),
        ],
      ),
    );
  }
}

class _CostBreakdownCard extends StatelessWidget {
  final PricingResult result;

  const _CostBreakdownCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Décomposition experte des coûts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ResultRow(
            label: 'Coûts directs totaux',
            value: '${_money(result.coutDirect)} €',
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'dont énergie et eau',
            value: '${_money(result.coutEnergieEau)} €',
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'dont transport et autres',
            value: '${_money(result.coutTransportAutres)} €',
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: "Main-d'œuvre",
            value: '${_money(result.coutMainOeuvre)} €',
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Charges fixes / unité',
            value: '${_money(result.chargeFixeUnitaire)} €',
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Marge au prix conseillé',
            value: '${_money(result.margeUnitaireConseillee)} €',
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final List<PricingScenarioResult> scenarios;
  final int breakEvenUnits;

  const _ScenarioCard({
    required this.scenarios,
    required this.breakEvenUnits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simulation mensuelle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            breakEvenUnits > 0
                ? 'Seuil de rentabilité : $breakEvenUnits unités / mois'
                : 'Le seuil ne peut pas être atteint avec le prix actuel.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...scenarios.map(
            (scenario) {
              final positive = scenario.beneficeMensuel >= 0;
              final color =
                  positive ? const Color(0xFF168A50) : const Color(0xFFC62828);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scenario.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${scenario.volume} unités • CA ${_money(scenario.chiffreAffairesTtc)} € TTC',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_money(scenario.beneficeMensuel)} €',
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
