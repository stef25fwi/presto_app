part of '../pricing_calculator_page.dart';

class PricingPdfExporter {
  static Future<Uint8List> build({
    required String projectName,
    required PricingInput input,
    required PricingResult result,
    required List<PricingScenarioResult> scenarios,
    required MarketEval market,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

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
