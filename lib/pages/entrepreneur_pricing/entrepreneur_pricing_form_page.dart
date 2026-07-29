import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entrepreneur_pricing_form_widgets.dart';
import 'entrepreneur_pricing_models.dart';
import 'entrepreneur_pricing_resource_widgets.dart';
import 'entrepreneur_pricing_results_page.dart';

class EntrepreneurPricingFormPage extends StatefulWidget {
  const EntrepreneurPricingFormPage({super.key, required this.mode});

  final EntrepreneurPricingMode mode;

  @override
  State<EntrepreneurPricingFormPage> createState() =>
      _EntrepreneurPricingFormPageState();
}

class _EntrepreneurPricingFormPageState
    extends State<EntrepreneurPricingFormPage> {
  late final Map<String, TextEditingController> _c = {
    'project': TextEditingController(text: 'Mon produit ou service'),
    'price': TextEditingController(text: '50'),
    'materials': TextEditingController(text: '12,50'),
    'packaging': TextEditingController(text: '1,20'),
    'consumables': TextEditingController(text: '0,80'),
    'minutes': TextEditingController(text: '45'),
    'hourly': TextEditingController(text: '25'),
    'fixed': TextEditingController(text: '300'),
    'volume': TextEditingController(text: '30'),
    'investment': TextEditingController(text: '300'),
    'share': TextEditingController(text: '10'),
    'feePct': TextEditingController(text: '12'),
    'feeFixed': TextEditingController(text: '0'),
    'margin': TextEditingController(text: '35'),
    'vat': TextEditingController(text: '0'),
    'electricity': TextEditingController(text: '0,25'),
    'waterVolume': TextEditingController(text: '0,02'),
    'waterRate': TextEditingController(text: '4,50'),
    'transport': TextEditingController(text: '2'),
    'other': TextEditingController(text: '0'),
    'marketLow': TextEditingController(text: '39'),
    'marketMid': TextEditingController(text: '55'),
    'marketHigh': TextEditingController(text: '79'),
    'prudent': TextEditingController(text: '15'),
    'high': TextEditingController(text: '45'),
  };

  bool _percentFees = true;
  String _region = '971';
  List<ProductionMachineUsage> _machines = const [];
  List<ProductionAccessoryUsage> _accessories = const [];

  bool get _expert => widget.mode == EntrepreneurPricingMode.expert;
  TextEditingController ctrl(String key) => _c[key]!;
  double number(String key) => pricingParseNumber(ctrl(key).text);
  int integer(String key) => pricingParseInteger(ctrl(key).text);

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _expert ? formExpertBlue : formBlue;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: PricingHeader(
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
            PricingSection(
              number: 1,
              title: 'Produit, service et prix envisagé',
              icon: Icons.sell_outlined,
              color: formOrange,
              children: [
                TextField(
                  key: const ValueKey('pricing-project-name'),
                  controller: ctrl('project'),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: pricingTextDecoration(
                    'Nom du produit ou service',
                    Icons.edit_note_rounded,
                  ),
                ),
                field('price', 'Prix TTC envisagé', '€'),
              ],
            ),
            section(
              2,
              'Coûts directs par unité',
              Icons.inventory_2_outlined,
              formOrange,
              [
                field('materials', 'Matières', '€'),
                field('packaging', 'Emballage', '€'),
                field('consumables', 'Consommables', '€'),
              ],
            ),
            section(
              3,
              'Temps et main-d’œuvre',
              Icons.timer_outlined,
              formBlue,
              [
                field('minutes', 'Temps par unité', 'min', integer: true),
                field('hourly', 'Taux horaire', '€/h'),
              ],
            ),
            section(
              4,
              'Charges fixes et volume cible',
              Icons.home_work_outlined,
              formBlue,
              [
                field('fixed', 'Charges / mois', '€'),
                field('volume', 'Unités / mois', 'nb', integer: true),
                PricingInfoPill(
                  text:
                      'Charge estimée : ${pricingFormMoney(fixedCostPerUnit)} € par unité',
                ),
              ],
            ),
            section(
              5,
              'Amortissement du matériel',
              Icons.precision_manufacturing_outlined,
              formOrange,
              [
                field('investment', 'Matériel à amortir', '€'),
                field('share', 'Part par unité', '€'),
                PricingInfoPill(text: amortizationPreview),
              ],
            ),
            if (_expert) ...[
              PricingSection(
                number: 6,
                title: 'Machines et accessoires utilisés',
                subtitle:
                    'Calcul exact : puissance × durée × tarif électrique',
                icon: Icons.settings_suggest_outlined,
                color: formExpertBlue,
                children: [
                  field('electricity', 'Tarif électricité', '€/kWh'),
                  ProductionResourcesEditor(
                    machines: _machines,
                    accessories: _accessories,
                    electricityRate: number('electricity'),
                    onMachinesChanged: (value) => setState(
                      () => _machines = List.unmodifiable(value),
                    ),
                    onAccessoriesChanged: (value) => setState(
                      () => _accessories = List.unmodifiable(value),
                    ),
                  ),
                ],
              ),
              PricingSection(
                number: 7,
                title: 'Eau, transport et territoire',
                icon: Icons.public_outlined,
                color: formExpertBlue,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('pricing-region'),
                    initialValue: _region,
                    decoration: pricingTextDecoration(
                      'Territoire tarifaire',
                      Icons.location_on_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: '971', child: Text('Guadeloupe (971)')),
                      DropdownMenuItem(value: '972', child: Text('Martinique (972)')),
                      DropdownMenuItem(value: '973', child: Text('Guyane (973)')),
                      DropdownMenuItem(value: '974', child: Text('La Réunion (974)')),
                      DropdownMenuItem(value: '976', child: Text('Mayotte (976)')),
                      DropdownMenuItem(value: 'HEX', child: Text('France hexagonale')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _region = value);
                    },
                  ),
                  field('waterVolume', 'Eau par unité', 'm³'),
                  field('waterRate', 'Tarif eau', '€/m³'),
                  field('transport', 'Transport par unité', '€'),
                  field('other', 'Autres coûts par unité', '€'),
                ],
              ),
            ],
            PricingSection(
              number: _expert ? 8 : 6,
              title: 'Frais, marge et fiscalité',
              icon: Icons.tune_rounded,
              color: formOrange,
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
                field(
                  _percentFees ? 'feePct' : 'feeFixed',
                  _percentFees
                      ? 'Frais de vente externes'
                      : 'Frais fixes par vente',
                  _percentFees ? '%' : '€',
                ),
                field('margin', 'Marge souhaitée', '%'),
                field('vat', 'TVA applicable', '%'),
                const PricingInfoPill(
                  text: 'iliprestō ajoute 0 % de commission.',
                ),
              ],
            ),
            if (_expert)
              section(
                9,
                'Marché et scénarios',
                Icons.query_stats_outlined,
                formExpertBlue,
                [
                  field('marketLow', 'Prix marché bas', '€'),
                  field('marketMid', 'Prix marché moyen', '€'),
                  field('marketHigh', 'Prix marché haut', '€'),
                  field('prudent', 'Volume prudent', 'nb', integer: true),
                  field('high', 'Volume haut', 'nb', integer: true),
                ],
              ),
            PricingPrimaryButton(
              text: _expert
                  ? 'Calculer mon coût exact'
                  : 'Calculer mon prix conseillé',
              icon: Icons.calculate_rounded,
              color: formOrange,
              onPressed: valid ? calculate : null,
            ),
            if (!valid) ...[
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

  Widget field(String key, String label, String suffix, {bool integer = false}) {
    return PricingNumberField(
      label: label,
      controller: ctrl(key),
      suffix: suffix,
      integer: integer,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget section(
    int number,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return PricingSection(
      number: number,
      title: title,
      icon: icon,
      color: color,
      children: children,
    );
  }

  bool get valid {
    final volume = integer('volume');
    final investment = number('investment');
    final share = number('share');
    final standard = integer('minutes') > 0 &&
        number('hourly') > 0 &&
        volume > 0 &&
        investment >= 0 &&
        (investment == 0 || share > 0) &&
        number('margin') >= 0 &&
        number('vat') >= 0;
    if (!standard || !_expert) return standard;
    return number('electricity') >= 0 &&
        number('marketLow') > 0 &&
        number('marketLow') <= number('marketMid') &&
        number('marketMid') <= number('marketHigh') &&
        integer('prudent') > 0 &&
        integer('prudent') <= volume &&
        integer('high') >= volume;
  }

  double get fixedCostPerUnit =>
      number('fixed') / math.max(integer('volume'), 1).toDouble();

  String get amortizationPreview {
    final total = number('investment');
    final share = number('share');
    if (total <= 0) return 'Aucun matériel à amortir.';
    if (share <= 0) return 'Indique une part d’amortissement par unité.';
    return '${(total / share).ceil()} unités nécessaires pour amortir '
        '${pricingFormMoney(total)} €.';
  }

  void calculate() {
    final volume = math.max(integer('volume'), 1);
    final draft = EntrepreneurPricingDraft(
      projectName: ctrl('project').text.trim().isEmpty
          ? 'Calcul sans nom'
          : ctrl('project').text.trim(),
      mode: widget.mode,
      expectedPriceTtc: number('price'),
      materials: number('materials'),
      packaging: number('packaging'),
      consumables: number('consumables'),
      workMinutes: integer('minutes'),
      hourlyRate: number('hourly'),
      monthlyFixedCosts: number('fixed'),
      monthlyVolume: volume,
      equipmentInvestment: number('investment'),
      equipmentSharePerUnit: number('share'),
      externalFeePercent: _percentFees ? number('feePct') : 0,
      externalFixedFee: _percentFees ? 0 : number('feeFixed'),
      marginPercent: number('margin'),
      vatPercent: number('vat'),
      regionCode: _expert ? _region : '',
      electricityRate: _expert ? number('electricity') : 0,
      waterM3PerUnit: _expert ? number('waterVolume') : 0,
      waterRate: _expert ? number('waterRate') : 0,
      transportPerUnit: _expert ? number('transport') : 0,
      otherCostsPerUnit: _expert ? number('other') : 0,
      machines: _expert ? _machines : const [],
      accessories: _expert ? _accessories : const [],
      marketLow: _expert ? number('marketLow') : 0,
      marketMid: _expert ? number('marketMid') : 0,
      marketHigh: _expert ? number('marketHigh') : 0,
      prudentVolume: _expert ? math.max(integer('prudent'), 1) : volume,
      highVolume: _expert ? math.max(integer('high'), 1) : volume,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntrepreneurPricingResultsPage(
          draft: draft,
          calculation: EntrepreneurPricingEngine.compute(draft),
        ),
      ),
    );
  }
}