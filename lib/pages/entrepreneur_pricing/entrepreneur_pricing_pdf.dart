import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'entrepreneur_pricing_models.dart';

class EntrepreneurPricingPdfExporter {
  const EntrepreneurPricingPdfExporter._();

  static Future<Uint8List> build({
    required EntrepreneurPricingDraft draft,
    required EntrepreneurPricingCalculation calculation,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    final scenarios = draft.mode == EntrepreneurPricingMode.expert
        ? <EntrepreneurPricingScenario>[
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
          ]
        : const <EntrepreneurPricingScenario>[];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'iliprestō • page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.Text(
            'iliprestō',
            style: pw.TextStyle(
              fontSize: 25,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#FF6600'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            "Fiche de calcul du prix — Mode ${draft.mode.label}",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 18),
          _title(draft.projectName.isEmpty ? 'Calcul sans nom' : draft.projectName),
          _rows([
            ['Prix TTC envisagé', '${_money(draft.expectedPriceTtc)} €'],
            ['Coût de revient', '${_money(calculation.costPrice)} €'],
            ['Prix minimum rentable TTC', '${_money(calculation.minimumPriceTtc)} €'],
            ['Prix conseillé TTC', '${_money(calculation.suggestedPriceTtc)} €'],
            [
              'Marge au prix envisagé',
              '${_money(calculation.expectedUnitProfit)} € / unité',
            ],
            [
              'Décision',
              calculation.expectedPriceIsProfitable
                  ? 'Prix envisagé rentable'
                  : 'Prix envisagé insuffisant',
            ],
          ]),
          pw.SizedBox(height: 16),
          _title('Décomposition du coût par unité'),
          _rows([
            ['Matières, emballage, consommables', '${_money(calculation.materialCost)} €'],
            ['Accessoires', '${_money(calculation.accessoryCost)} €'],
            ['Électricité machines', '${_money(calculation.machineElectricityCost)} €'],
            ['Consommation machines', '${_number(calculation.machineKwh, 4)} kWh'],
            ['Eau', '${_money(calculation.waterCost)} €'],
            ['Transport et autres', '${_money(calculation.transportAndOtherCost)} €'],
            ['Main-d’œuvre', '${_money(calculation.laborCost)} €'],
            ['Charges fixes', '${_money(calculation.fixedCostPerUnit)} €'],
            ['Amortissement', '${_money(calculation.amortizationPerUnit)} €'],
          ]),
          if (draft.mode == EntrepreneurPricingMode.expert &&
              draft.machines.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Machines utilisées'),
            pw.TableHelper.fromTextArray(
              headers: const ['Machine', 'Qté', 'Puissance', 'Durée', 'kWh', 'Coût'],
              data: draft.machines
                  .map(
                    (machine) => [
                      machine.name,
                      '${machine.quantity}',
                      '${_number(machine.watts, 0)} W',
                      '${_number(machine.minutesPerUnit, 1)} min',
                      _number(machine.kwhPerUnit, 4),
                      '${_money(machine.costPerUnit(draft.electricityRate))} €',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ],
          if (draft.mode == EntrepreneurPricingMode.expert &&
              draft.accessories.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Accessoires et fournitures'),
            pw.TableHelper.fromTextArray(
              headers: const ['Accessoire', 'Qté / unité', 'Prix unitaire', 'Coût / unité'],
              data: draft.accessories
                  .map(
                    (accessory) => [
                      accessory.name,
                      _number(accessory.quantityPerUnit, 2),
                      '${_money(accessory.unitPrice)} €',
                      '${_money(accessory.costPerUnit)} €',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange50),
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ],
          pw.SizedBox(height: 16),
          _title('Rentabilité'),
          _rows([
            [
              'Unités pour amortir le matériel',
              calculation.unitsToAmortize == 0
                  ? 'Non applicable'
                  : '${calculation.unitsToAmortize}',
            ],
            [
              'Seuil de rentabilité',
              calculation.breakEvenUnits == 0
                  ? 'Non calculable'
                  : '${calculation.breakEvenUnits} unités / mois',
            ],
          ]),
          if (scenarios.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _title('Scénarios mensuels'),
            pw.TableHelper.fromTextArray(
              headers: const ['Scénario', 'Volume', 'CA TTC', 'Résultat'],
              data: scenarios
                  .map(
                    (scenario) => [
                      scenario.label,
                      '${scenario.volume}',
                      '${_money(scenario.revenueTtc)} €',
                      '${_money(scenario.monthlyProfit)} €',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
              cellPadding: const pw.EdgeInsets.all(7),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Text(
            'Cette fiche est une simulation indicative fondée sur les données saisies. '
            'Les frais iliprestō sont fixés à 0 %. Vérifie tes obligations fiscales, '
            'sociales et réglementaires auprès des organismes compétents.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _title(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1A73E8'),
        ),
      ),
    );
  }

  static pw.Widget _rows(List<List<String>> rows) {
    return pw.Column(
      children: rows
          .map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Text(row[0])),
                  pw.SizedBox(width: 12),
                  pw.Text(row[1], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static String _money(double value) => _number(value, 2);

  static String _number(double value, int digits) {
    final safe = value.isFinite ? value : 0.0;
    return safe.toStringAsFixed(digits).replaceAll('.', ',');
  }
}