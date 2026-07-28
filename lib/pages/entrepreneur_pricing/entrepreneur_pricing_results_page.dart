import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants.dart';
import 'entrepreneur_pricing_models.dart';
import 'entrepreneur_pricing_pdf.dart';
import 'entrepreneur_pricing_storage.dart';

const _orange = Color(0xFFFF6600);
const _blue = Color(0xFF1A73E8);
const _expertBlue = Color(0xFF0F4C81);

class EntrepreneurPricingResultsPage extends StatefulWidget {
  const EntrepreneurPricingResultsPage({
    super.key,
    required this.draft,
    required this.calculation,
  });

  final EntrepreneurPricingDraft draft;
  final EntrepreneurPricingCalculation calculation;

  @override
  State<EntrepreneurPricingResultsPage> createState() =>
      _EntrepreneurPricingResultsPageState();
}

class _EntrepreneurPricingResultsPageState
    extends State<EntrepreneurPricingResultsPage> {
  bool _saving = false;
  bool _exporting = false;

  bool get _expert => widget.draft.mode == EntrepreneurPricingMode.expert;

  @override
  Widget build(BuildContext context) {
    final calculation = widget.calculation;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _PricingAppBar(
        color: _expert ? _expertBlue : _blue,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 24),
          children: [
            Text(
              _expert ? 'Analyse experte' : 'Résultats Standard',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              widget.draft.projectName,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _DecisionCard(calculation: calculation),
            const SizedBox(height: 12),
            _Panel(
              title: 'Synthèse du prix',
              icon: Icons.price_check_rounded,
              children: [
                _ResultRow('Coût de revient', '${_money(calculation.costPrice)} €'),
                _ResultRow(
                  'Prix minimum rentable TTC',
                  '${_money(calculation.minimumPriceTtc)} €',
                ),
                _ResultRow(
                  'Prix conseillé TTC',
                  '${_money(calculation.suggestedPriceTtc)} €',
                  emphasized: true,
                ),
                _ResultRow(
                  'Marge au prix conseillé',
                  '${_money(calculation.suggestedUnitProfit)} €',
                ),
                _ResultRow(
                  'Seuil de rentabilité',
                  calculation.breakEvenUnits == 0
                      ? 'Non calculable'
                      : '${calculation.breakEvenUnits} unités / mois',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Panel(
              title: 'Coût exact de production',
              icon: Icons.account_tree_outlined,
              children: [
                _ResultRow(
                  'Matières et consommables',
                  '${_money(calculation.materialCost)} €',
                ),
                if (_expert) ...[
                  _ResultRow(
                    'Accessoires',
                    '${_money(calculation.accessoryCost)} €',
                  ),
                  _ResultRow(
                    'Machines (${_number(calculation.machineKwh, 4)} kWh)',
                    '${_money(calculation.machineElectricityCost)} €',
                  ),
                  _ResultRow('Eau', '${_money(calculation.waterCost)} €'),
                  _ResultRow(
                    'Transport et autres',
                    '${_money(calculation.transportAndOtherCost)} €',
                  ),
                ],
                _ResultRow(
                  'Main-d’œuvre',
                  '${_money(calculation.laborCost)} €',
                ),
                _ResultRow(
                  'Charges fixes',
                  '${_money(calculation.fixedCostPerUnit)} €',
                ),
                _ResultRow(
                  'Amortissement',
                  '${_money(calculation.amortizationPerUnit)} €',
                ),
              ],
            ),
            if (_expert && widget.draft.machines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Panel(
                title: 'Machines prises en compte',
                icon: Icons.precision_manufacturing_outlined,
                children: widget.draft.machines
                    .map(
                      (machine) => _ResultRow(
                        '${machine.name} • ${_number(machine.watts, 0)} W × '
                        '${_number(machine.minutesPerUnit, 1)} min × '
                        '${machine.quantity}',
                        '${_money(machine.costPerUnit(widget.draft.electricityRate))} €',
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_expert && widget.draft.accessories.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Panel(
                title: 'Accessoires pris en compte',
                icon: Icons.construction_outlined,
                children: widget.draft.accessories
                    .map(
                      (accessory) => _ResultRow(
                        '${accessory.name} • '
                        '${_number(accessory.quantityPerUnit, 2)} × '
                        '${_money(accessory.unitPrice)} €',
                        '${_money(accessory.costPerUnit)} €',
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_expert) ...[
              const SizedBox(height: 12),
              _ScenarioPanel(draft: widget.draft),
              const SizedBox(height: 14),
              _ActionButton(
                text: _saving
                    ? 'Sauvegarde et vérification…'
                    : 'Sauvegarder cette analyse',
                icon: Icons.save_outlined,
                color: _blue,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                text: _exporting
                    ? 'Génération de la fiche PDF…'
                    : 'Générer la fiche PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: _expertBlue,
                onPressed: _exporting ? null : _exportPdf,
              ),
            ],
            const SizedBox(height: 10),
            _ActionButton(
              text: 'Ajuster mes hypothèses',
              icon: Icons.tune_rounded,
              color: _orange,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await EntrepreneurPricingStorage.save(
        EntrepreneurPricingRecord(
          id: now.microsecondsSinceEpoch.toString(),
          createdAt: now,
          draft: widget.draft,
          calculation: widget.calculation,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analyse enregistrée et vérifiée sur cet appareil.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La sauvegarde n’a pas pu être vérifiée. Réessaie.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final bytes = await EntrepreneurPricingPdfExporter.build(
        draft: widget.draft,
        calculation: widget.calculation,
      );
      final safeName = widget.draft.projectName
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
                'ilipresto-fiche-prix-${safeName.isEmpty ? 'calcul' : safeName}.pdf',
          ),
        ],
        subject: 'Fiche de calcul du prix iliprestō',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La génération de la fiche PDF a échoué.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class EntrepreneurPricingHistoryPage extends StatefulWidget {
  const EntrepreneurPricingHistoryPage({super.key});

  @override
  State<EntrepreneurPricingHistoryPage> createState() =>
      _EntrepreneurPricingHistoryPageState();
}

class _EntrepreneurPricingHistoryPageState
    extends State<EntrepreneurPricingHistoryPage> {
  late Future<List<EntrepreneurPricingRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = EntrepreneurPricingStorage.load();
  }

  void _reload() => setState(() => _future = EntrepreneurPricingStorage.load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _PricingAppBar(
        color: _orange,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: FutureBuilder<List<EntrepreneurPricingRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun calcul enregistré. Les analyses Expert sauvegardées '
                  'apparaîtront ici.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.calculate_outlined, color: _blue),
                  title: Text(
                    record.draft.projectName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_date(record.createdAt)} • '
                    '${_money(record.calculation.suggestedPriceTtc)} € conseillé',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EntrepreneurPricingResultsPage(
                        draft: record.draft,
                        calculation: record.calculation,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Supprimer',
                    onPressed: () async {
                      await EntrepreneurPricingStorage.delete(record.id);
                      if (mounted) _reload();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.calculation});

  final EntrepreneurPricingCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final profitable = calculation.expectedPriceIsProfitable;
    final color = profitable ? const Color(0xFF15803D) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            profitable ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              profitable
                  ? 'Ton prix envisagé est rentable\n'
                      'Résultat : ${_money(calculation.expectedUnitProfit)} € / unité'
                  : 'À ce prix, tu perds de l’argent\n'
                      'Résultat : ${_money(calculation.expectedUnitProfit)} € / unité',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioPanel extends StatelessWidget {
  const _ScenarioPanel({required this.draft});

  final EntrepreneurPricingDraft draft;

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      EntrepreneurPricingEngine.computeScenario(
        draft,
        label: 'Prudent',
        volume: draft.prudentVolume,
      ),
      EntrepreneurPricingEngine.computeScenario(
        draft,
        label: 'Cible',
        volume: draft.monthlyVolume,
      ),
      EntrepreneurPricingEngine.computeScenario(
        draft,
        label: 'Haut',
        volume: draft.highVolume,
      ),
    ];
    return _Panel(
      title: 'Scénarios mensuels',
      icon: Icons.insights_outlined,
      children: scenarios
          .map(
            (item) => _ResultRow(
              '${item.label} • ${item.volume} unités',
              '${_money(item.monthlyProfit)} €',
              emphasized: item.label == 'Cible',
            ),
          )
          .toList(),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: _blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasized ? _blue : Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      height: 54,
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
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _PricingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PricingAppBar({required this.color, required this.onBack});

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

String _money(double value) => _number(value, 2);

String _number(double value, int digits) =>
    (value.isFinite ? value : 0).toStringAsFixed(digits).replaceAll('.', ',');

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}