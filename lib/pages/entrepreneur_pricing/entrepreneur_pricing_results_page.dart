import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'entrepreneur_pricing_models.dart';
import 'entrepreneur_pricing_pdf.dart';
import 'entrepreneur_pricing_results_widgets.dart';
import 'entrepreneur_pricing_storage.dart';

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
      appBar: PricingAppBar(
        color: _expert ? pricingExpertBlue : pricingBlue,
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
            PricingDecisionCard(calculation: calculation),
            const SizedBox(height: 12),
            PricingPanel(
              title: 'Synthèse du prix',
              icon: Icons.price_check_rounded,
              children: [
                PricingResultRow(
                  'Coût de revient',
                  '${pricingMoney(calculation.costPrice)} €',
                ),
                PricingResultRow(
                  'Prix minimum rentable TTC',
                  '${pricingMoney(calculation.minimumPriceTtc)} €',
                ),
                PricingResultRow(
                  'Prix conseillé TTC',
                  '${pricingMoney(calculation.suggestedPriceTtc)} €',
                  emphasized: true,
                ),
                PricingResultRow(
                  'Marge au prix conseillé',
                  '${pricingMoney(calculation.suggestedUnitProfit)} €',
                ),
                PricingResultRow(
                  'Seuil de rentabilité',
                  calculation.breakEvenUnits == 0
                      ? 'Non calculable'
                      : '${calculation.breakEvenUnits} unités / mois',
                ),
              ],
            ),
            const SizedBox(height: 12),
            PricingPanel(
              title: 'Coût exact de production',
              icon: Icons.account_tree_outlined,
              children: _costRows(calculation),
            ),
            if (_expert && widget.draft.machines.isNotEmpty) ...[
              const SizedBox(height: 12),
              PricingPanel(
                title: 'Machines prises en compte',
                icon: Icons.precision_manufacturing_outlined,
                children: widget.draft.machines
                    .map(
                      (machine) => PricingResultRow(
                        '${machine.name} • '
                        '${pricingNumber(machine.watts, 0)} W × '
                        '${pricingNumber(machine.minutesPerUnit, 1)} min × '
                        '${machine.quantity}',
                        '${pricingMoney(machine.costPerUnit(widget.draft.electricityRate))} €',
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_expert && widget.draft.accessories.isNotEmpty) ...[
              const SizedBox(height: 12),
              PricingPanel(
                title: 'Accessoires pris en compte',
                icon: Icons.construction_outlined,
                children: widget.draft.accessories
                    .map(
                      (accessory) => PricingResultRow(
                        '${accessory.name} • '
                        '${pricingNumber(accessory.quantityPerUnit, 2)} × '
                        '${pricingMoney(accessory.unitPrice)} €',
                        '${pricingMoney(accessory.costPerUnit)} €',
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_expert) ...[
              const SizedBox(height: 12),
              _ScenarioPanel(draft: widget.draft),
              const SizedBox(height: 14),
              PricingActionButton(
                text: _saving
                    ? 'Sauvegarde et vérification…'
                    : 'Sauvegarder cette analyse',
                icon: Icons.save_outlined,
                color: pricingBlue,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 10),
              PricingActionButton(
                text: _exporting
                    ? 'Génération de la fiche PDF…'
                    : 'Générer la fiche PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: pricingExpertBlue,
                onPressed: _exporting ? null : _exportPdf,
              ),
            ],
            const SizedBox(height: 10),
            PricingActionButton(
              text: 'Ajuster mes hypothèses',
              icon: Icons.tune_rounded,
              color: pricingOrange,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _costRows(EntrepreneurPricingCalculation calculation) {
    return [
      PricingResultRow(
        'Matières et consommables',
        '${pricingMoney(calculation.materialCost)} €',
      ),
      if (_expert) ...[
        PricingResultRow(
          'Accessoires',
          '${pricingMoney(calculation.accessoryCost)} €',
        ),
        PricingResultRow(
          'Machines (${pricingNumber(calculation.machineKwh, 4)} kWh)',
          '${pricingMoney(calculation.machineElectricityCost)} €',
        ),
        PricingResultRow('Eau', '${pricingMoney(calculation.waterCost)} €'),
        PricingResultRow(
          'Transport et autres',
          '${pricingMoney(calculation.transportAndOtherCost)} €',
        ),
      ],
      PricingResultRow(
        'Main-d’œuvre',
        '${pricingMoney(calculation.laborCost)} €',
      ),
      PricingResultRow(
        'Charges fixes',
        '${pricingMoney(calculation.fixedCostPerUnit)} €',
      ),
      PricingResultRow(
        'Amortissement',
        '${pricingMoney(calculation.amortizationPerUnit)} €',
      ),
    ];
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
    return PricingPanel(
      title: 'Scénarios mensuels',
      icon: Icons.insights_outlined,
      children: scenarios
          .map(
            (item) => PricingResultRow(
              '${item.label} • ${item.volume} unités',
              '${pricingMoney(item.monthlyProfit)} €',
              emphasized: item.label == 'Cible',
            ),
          )
          .toList(),
    );
  }
}