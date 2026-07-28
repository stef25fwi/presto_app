import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_resource_widgets.dart';
import 'entrepreneur_pricing/entrepreneur_pricing_results_page.dart';

const _pricingOrange = Color(0xFFFF6600);
const _pricingBlue = Color(0xFF1A73E8);
const _pricingExpertBlue = Color(0xFF0F4C81);

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
      appBar: _PricingHeader(
        color: _pricingOrange,
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
            _ModeCard(
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
            _ModeCard(
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
            _PrimaryButton(
              text: 'Commencer',
              icon: Icons.play_arrow_rounded,
              color: _pricingOrange,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _EntrepreneurPricingFormPage(mode: _mode),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
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

class _EntrepreneurPricingFormPage extends StatefulWidget {
  const _EntrepreneurPricingFormPage({required this.mode});

  final EntrepreneurPricingMode mode;

  @override
  State<_EntrepreneurPricingFormPage> createState() =>
      _EntrepreneurPricingFormPageState();
}

class _EntrepreneurPricingFormPageState
    extends State<_EntrepreneurPricingFormPage> {
  final _project = TextEditingController(text: 'Mon produit ou service');
  final _expectedPrice = TextEditingController(text: '50');
  final _materials = TextEditingController(text: '12,50');
  final _packaging = TextEditingController(text: '1,20');
  final _consumables = TextEditingController(text: '0,80');
  final _workMinutes = TextEditingController(text: '45');
  final _hourlyRate = TextEditingController(text: '25');
  final _monthlyFixedCosts = TextEditingController(text: '300');
  final _monthlyVolume = TextEditingController(text: '30');
  final _equipmentInvestment = TextEditingController(text: '300');
  final _equipmentShare = TextEditingController(text: '10');
  final _externalFeePercent = TextEditingController(text: '12');
  final _externalFixedFee = TextEditingController(text: '0');
  final _marginPercent = TextEditingController(text: '35');
  final _vatPercent = TextEditingController(text: '0');
  final _electricityRate = TextEditingController(text: '0,25');
  final _waterM3 = TextEditingController(text: '0,02');
  final _waterRate = TextEditingController(text: '4,50');
  final _transport = TextEditingController(text: '2');
  final _otherCosts = TextEditingController(text: '0');
  final _marketLow = TextEditingController(text: '39');
  final _marketMid = TextEditingController(text: '55');
  final _marketHigh = TextEditingController(text: '79');
  final _prudentVolume = TextEditingController(text: '15');
  final _highVolume = TextEditingController(text: '45');

  String _regionCode = '971';
  bool _percentFees = true;
  List<ProductionMachineUsage> _machines = const [];
  List<ProductionAccessoryUsage> _accessories = const [];

  bool get _expert => widget.mode == EntrepreneurPricingMode.expert;

  Iterable<TextEditingController> get _controllers => [
        _project,
        _expectedPrice,
        _materials,
        _packaging,
        _consumables,
        _workMinutes,
        _hourlyRate,
        _monthlyFixedCosts,
        _monthlyVolume,
        _equipmentInvestment,
        _equipmentShare,
        _externalFeePercent,
        _externalFixedFee,
        _marginPercent,
        _vatPercent,
        _electricityRate,
        _waterM3,
        _waterRate,
        _transport,
        _otherCosts,
        _marketLow,
        _marketMid,
        _marketHigh,
        _prudentVolume,
        _highVolume,
      ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _expert ? _pricingExpertBlue : _pricingBlue;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _PricingHeader(
        color: modeColor,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 24),
          children: [
            Text(
              'Mode ${widget.mode.label}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              _expert
                  ? 'Calcule le coût exact de chaque machine et accessoire utilisé.'
                  : 'Calcule rapidement un prix rentable avec les coûts essentiels.',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              number: 1,
              title: 'Produit, service et prix envisagé',
              icon: Icons.sell_outlined,
              color: _pricingOrange,
              children: [
                TextField(
                  key: const ValueKey('pricing-project-name'),
                  controller: _project,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _textDecoration(
                    'Nom du produit ou service',
                    Icons.edit_note_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                _NumberField(
                  label: 'Prix TTC envisagé',
                  controller: _expectedPrice,
                  suffix: '€',
                  onChanged: _refresh,
                ),
              ],
            ),
            _Section(
              number: 2,
              title: 'Coûts directs par unité',
              icon: Icons.inventory_2_outlined,
              color: _pricingOrange,
              children: [
                _NumberField(
                  label: 'Matières',
                  controller: _materials,
                  suffix: '€',
                  onChanged: _refresh,
                ),
                _NumberField(
                  label: 'Emballage',
                  controller: _packaging,
                  suffix: '€',
                  onChanged: _refresh,
                ),
                _NumberField(
                  label: 'Consommables',
                  controller: _consumables,
                  suffix: '€',
                  onChanged: _refresh,
                ),
              ],
            ),
            _Section(
              number: 3,
              title: 'Temps et main-d’œuvre',
              icon: Icons.timer_outlined,
              color: _pricingBlue,
              children: [
                _NumberField(
                  label: 'Temps par unité',
                  controller: _workMinutes,
                  suffix: 'min',
                  integer: true,
                  onChanged: _refresh,
                ),
                _NumberField(
                  label: 'Taux horaire',
                  controller: _hourlyRate,
                  suffix: '€/h',
                  onChanged: _refresh,
                ),
              ],
            ),
            _Section(
              number: 4,
              title: 'Charges fixes et volume cible',
              icon: Icons.home_work_outlined,
              color: _pricingBlue,
              children: [
                _NumberField(
                  label: 'Charges / mois',
                  controller: _monthlyFixedCosts,
                  suffix: '€',
                  onChanged: _refresh,
                ),
                _NumberField(
                  label: 'Unités / mois',
                  controller: _monthlyVolume,
                  suffix: 'nb',
                  integer: true,
                  onChanged: _refresh,
                ),
                _InfoPill(
                  text:
                      'Charge estimée : ${_money(_fixedCostPerUnit)} € par unité',
                ),
              ],
            ),
            _Section(
              number: 5,
              title: 'Amortissement du matériel',
              icon: Icons.precision_manufacturing_outlined,
              color: _pricingOrange,
              children: [
                _NumberField(
                  label: 'Matériel à amortir',
                  controller: _equipmentInvestment,
                  suffix: '€',
                  onChanged: _refresh,
                ),
                _NumberField(
                  label: 'Part par unité',
                  controller: _equipmentShare,
                  suffix: '€',
                  onChanged: _refresh,
                ),
                _InfoPill(text: _amortizationPreview),
              ],
            ),
            if (_expert) ...[
              _Section(
                number: 6,
                title: 'Machines et accessoires utilisés',
                icon: Icons.settings_suggest_outlined,
                color: _pricingExpertBlue,
                subtitle:
                    'Calcul exact : puissance × durée × tarif électrique',
                children: [
                  _NumberField(
                    label: 'Tarif électricité',
                    controller: _electricityRate,
                    suffix: '€/kWh',
                    onChanged: _refresh,
                  ),
                  ProductionResourcesEditor(
                    machines: _machines,
                    accessories: _accessories,
                    electricityRate: _number(_electricityRate.text),
                    onMachinesChanged: (value) => setState(
                      () => _machines = List.unmodifiable(value),
                    ),
                    onAccessoriesChanged: (value) => setState(
                      () => _accessories = List.unmodifiable(value),
                    ),
                  ),
                ],
              ),
              _Section(
                number: 7,
                title: 'Eau, transport et territoire',
                icon: Icons.public_outlined,
                color: _pricingExpertBlue,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('pricing-region'),
                    initialValue: _regionCode,
                    decoration: _textDecoration(
                      'Territoire tarifaire',
                      Icons.location_on_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '971',
                        child: Text('Guadeloupe (971)'),
                      ),
                      DropdownMenuItem(
                        value: '972',
                        child: Text('Martinique (972)'),
                      ),
                      DropdownMenuItem(
                        value: '973',
                        child: Text('Guyane (973)'),
                      ),
                      DropdownMenuItem(
                        value: '974',
                        child: Text('La Réunion (974)'),
                      ),
                      DropdownMenuItem(
                        value: '976',
                        child: Text('Mayotte (976)'),
                      ),
                      DropdownMenuItem(
                        value: 'HEX',
                        child: Text('France hexagonale'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _regionCode = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _NumberField(
                    label: 'Eau par unité',
                    controller: _waterM3,
                    suffix: 'm³',
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Tarif eau',
                    controller: _waterRate,
                    suffix: '€/m³',
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Transport par unité',
                    controller: _transport,
                    suffix: '€',
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Autres coûts par unité',
                    controller: _otherCosts,
                    suffix: '€',
                    onChanged: _refresh,
                  ),
                ],
              ),
            ],
            _Section(
              number: _expert ? 8 : 6,
              title: 'Frais, marge et fiscalité',
              icon: Icons.tune_rounded,
              color: _pricingOrange,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Frais en %')),
                    ButtonSegment(value: false, label: Text('Frais en €')),
                  ],
                  selected: {_percentFees},
                  onSelectionChanged: (value) => setState(
                    () => _percentFees = value.first,
                  ),
                ),
                const SizedBox(height: 10),
                if (_percentFees)
                  _NumberField(
                    label: 'Frais de vente externes',
                    controller: _externalFeePercent,
                    suffix: '%',
                    onChanged: _refresh,
                  )
                else
                  _NumberField(
                    label: 'Frais fixes par vente',
                    controller: _externalFixedFee,
                    suffix: '€',
                    onChanged: _refresh,
                  ),
                _NumberField(
                  label: 'Marge souhaitée',
                  controller: _marginPercent,
                  suffix: '%',
                  onChanged: _refresh,
                ),
                _NumberField(
                  label: 'TVA applicable',
                  controller: _vatPercent,
                  suffix: '%',
                  onChanged: _refresh,
                ),
                const _InfoPill(
                  text:
                      'Les frais saisis sont tes frais externes réels. '
                      'iliprestō ajoute 0 % de commission.',
                ),
              ],
            ),
            if (_expert) ...[
              _Section(
                number: 9,
                title: 'Marché et scénarios',
                icon: Icons.query_stats_outlined,
                color: _pricingExpertBlue,
                children: [
                  _NumberField(
                    label: 'Prix marché bas',
                    controller: _marketLow,
                    suffix: '€',
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Prix marché moyen',
                    controller: _marketMid,
                    suffix: '€',
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Prix marché haut',
                    controller: _marketHigh,
                    suffix: '€',
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Volume prudent',
                    controller: _prudentVolume,
                    suffix: 'nb',
                    integer: true,
                    onChanged: _refresh,
                  ),
                  _NumberField(
                    label: 'Volume haut',
                    controller: _highVolume,
                    suffix: 'nb',
                    integer: true,
                    onChanged: _refresh,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 5),
            _PrimaryButton(
              text: _expert
                  ? 'Calculer mon coût exact'
                  : 'Calculer mon prix conseillé',
              icon: Icons.calculate_rounded,
              color: _pricingOrange,
              onPressed: _valid ? _calculate : null,
            ),
            if (!_valid) ...[
              const SizedBox(height: 8),
              Text(
                _expert
                    ? 'Vérifie les valeurs, le marché et l’ordre des volumes.'
                    : 'Vérifie les valeurs obligatoires et l’amortissement.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _refresh(String _) => setState(() {});

  bool get _valid {
    final volume = _integer(_monthlyVolume.text);
    final equipment = _number(_equipmentInvestment.text);
    final share = _number(_equipmentShare.text);
    final standardValid = _integer(_workMinutes.text) > 0 &&
        _number(_hourlyRate.text) > 0 &&
        volume > 0 &&
        equipment >= 0 &&
        (equipment == 0 || share > 0) &&
        _number(_marginPercent.text) >= 0 &&
        _number(_vatPercent.text) >= 0;
    if (!standardValid || !_expert) return standardValid;

    final low = _number(_marketLow.text);
    final mid = _number(_marketMid.text);
    final high = _number(_marketHigh.text);
    final prudent = _integer(_prudentVolume.text);
    final highVolume = _integer(_highVolume.text);
    return _number(_electricityRate.text) >= 0 &&
        _number(_waterM3.text) >= 0 &&
        _number(_waterRate.text) >= 0 &&
        low > 0 &&
        low <= mid &&
        mid <= high &&
        prudent > 0 &&
        prudent <= volume &&
        highVolume >= volume;
  }

  double get _fixedCostPerUnit =>
      _number(_monthlyFixedCosts.text) /
      math.max(_integer(_monthlyVolume.text), 1);

  String get _amortizationPreview {
    final total = _number(_equipmentInvestment.text);
    final share = _number(_equipmentShare.text);
    if (total <= 0) return 'Aucun matériel à amortir.';
    if (share <= 0) return 'Indique une part d’amortissement par unité.';
    return '${(total / share).ceil()} unités nécessaires pour amortir '
        '${_money(total)} €.';
  }

  void _calculate() {
    final draft = EntrepreneurPricingDraft(
      projectName: _project.text.trim().isEmpty
          ? 'Calcul sans nom'
          : _project.text.trim(),
      mode: widget.mode,
      expectedPriceTtc: _number(_expectedPrice.text),
      materials: _number(_materials.text),
      packaging: _number(_packaging.text),
      consumables: _number(_consumables.text),
      workMinutes: _integer(_workMinutes.text),
      hourlyRate: _number(_hourlyRate.text),
      monthlyFixedCosts: _number(_monthlyFixedCosts.text),
      monthlyVolume: math.max(_integer(_monthlyVolume.text), 1),
      equipmentInvestment: _number(_equipmentInvestment.text),
      equipmentSharePerUnit: _number(_equipmentShare.text),
      externalFeePercent:
          _percentFees ? _number(_externalFeePercent.text) : 0,
      externalFixedFee:
          _percentFees ? 0 : _number(_externalFixedFee.text),
      marginPercent: _number(_marginPercent.text),
      vatPercent: _number(_vatPercent.text),
      regionCode: _expert ? _regionCode : '',
      electricityRate: _expert ? _number(_electricityRate.text) : 0,
      waterM3PerUnit: _expert ? _number(_waterM3.text) : 0,
      waterRate: _expert ? _number(_waterRate.text) : 0,
      transportPerUnit: _expert ? _number(_transport.text) : 0,
      otherCostsPerUnit: _expert ? _number(_otherCosts.text) : 0,
      machines: _expert ? _machines : const [],
      accessories: _expert ? _accessories : const [],
      marketLow: _expert ? _number(_marketLow.text) : 0,
      marketMid: _expert ? _number(_marketMid.text) : 0,
      marketHigh: _expert ? _number(_marketHigh.text) : 0,
      prudentVolume: _expert
          ? math.max(_integer(_prudentVolume.text), 1)
          : math.max(_integer(_monthlyVolume.text), 1),
      highVolume: _expert
          ? math.max(_integer(_highVolume.text), 1)
          : math.max(_integer(_monthlyVolume.text), 1),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntrepreneurPricingResultsPage(
          draft: draft,
          calculation: EntrepreneurPricingEngine.compute(draft),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.chips,
    required this.onTap,
  });

  final EntrepreneurPricingMode mode;
  final bool selected;
  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final List<String> chips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = mode == EntrepreneurPricingMode.expert
        ? _pricingExpertBlue
        : _pricingBlue;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? color : Colors.black38,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _Chip(label: badge, color: color),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: chips
                        .map((label) => _Chip(label: label, color: color))
                        .toList(),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.subtitle,
  });

  final int number;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$number. $title',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: _spaced(children)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> widgets) {
    final result = <Widget>[];
    for (var index = 0; index < widgets.length; index++) {
      result.add(widgets[index]);
      if (index < widgets.length - 1) result.add(const SizedBox(height: 10));
    }
    return result;
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
    this.integer = false,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final ValueChanged<String> onChanged;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 125,
          child: TextField(
            controller: controller,
            keyboardType: integer
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              suffixText: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _PricingHeader extends StatelessWidget implements PreferredSizeWidget {
  const _PricingHeader({required this.color, required this.onBack});

  final Color color;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: color,
      foregroundColor: Colors.white,
      leading: IconButton(
        key: const ValueKey('pricing-header-back'),
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(
        'iliprestō',
        style: kPrestoAppBarTitleStyle.copyWith(color: Colors.white),
      ),
    );
  }
}

InputDecoration _textDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF3F4F6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

double _number(String value) => double.tryParse(
      value.trim().replaceAll(' ', '').replaceAll(',', '.'),
    ) ??
    0;

int _integer(String value) => int.tryParse(value.trim().replaceAll(' ', '')) ?? 0;

String _money(double value) =>
    (value.isFinite ? value : 0).toStringAsFixed(2).replaceAll('.', ',');