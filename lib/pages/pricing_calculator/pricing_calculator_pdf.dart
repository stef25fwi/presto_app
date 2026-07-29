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
    final logoData = await rootBundle.load('assets/images/logowebp.webp');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 45, 32, 40),
        header: (_) => _pdfBrandHeader(
          logo,
          "Calculatrice de l'entrepreneur — Analyse Expert",
        ),
        footer: (context) => _pdfBrandFooter(context),
        build: (_) => [
          pw.SizedBox(height: 12),
          _pdfSectionTitle(projectName.isEmpty ? 'Calcul sans nom' : projectName),
          _pdfRows([
            ['Prix TTC envisagé', '${_money(input.prixVenteTtcEnvisage)} €'],
            ['Coût de revient', '${_money(result.coutDeRevient)} €'],
            ['Prix minimum rentable TTC', '${_money(result.prixMinimumRentableTtc)} €'],
            ['Prix conseillé TTC', '${_money(result.prixTTC)} €'],
            ['Marge du prix envisagé', '${_money(result.margeUnitaireEnvisagee)} € / unité'],
          ]),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Détail des coûts par unité'),
          _pdfRows([
            ['Coûts directs', '${_money(result.coutDirect)} €'],
            ['Énergie et eau', '${_money(result.coutEnergieEau)} €'],
            ['Transport et autres', '${_money(result.coutTransportAutres)} €'],
            ['Main-d’œuvre', '${_money(result.coutMainOeuvre)} €'],
            ['Charges fixes', '${_money(result.chargeFixeUnitaire)} €'],
            ['Amortissement', '${_money(result.amortissementUnitaire)} €'],
          ]),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Rentabilité'),
          _pdfRows([
            [
              'Unités pour amortir le matériel',
              result.unitesPourAmortir == 0
                  ? 'Non applicable'
                  : '${result.unitesPourAmortir}',
            ],
            [
              'Seuil de rentabilité',
              result.seuilRentabiliteUnites == 0
                  ? 'Non calculable'
                  : '${result.seuilRentabiliteUnites} unités / mois',
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
          _pdfDisclaimer(
            'Cette simulation repose sur les informations saisies par l’utilisateur.',
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _pdfBrandHeader(pw.ImageProvider logo, String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.7),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Image(logo, width: 30, height: 30, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 9),
          pw.Text(
            'iliprestō',
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#FF6600'),
            ),
          ),
          pw.Spacer(),
          pw.Text(
            title,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfBrandFooter(pw.Context context) => pw.Row(
        children: [
          pw.Text(
            'Document généré par iliprestō',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Spacer(),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      );

  static pw.Widget _pdfDisclaimer(String introduction) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.orange50,
          border: pw.Border.all(color: PdfColors.orange200, width: 0.7),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          '$introduction\n\nLes informations présentées dans ce document sont '
          'fournies à titre strictement indicatif et ne sauraient engager la '
          'responsabilité d’iliprestō. L’utilisateur doit, en complément, se '
          'rapprocher des organismes compétents de sa région afin de vérifier '
          'les démarches, règles, montants et obligations applicables à sa situation.',
          style: const pw.TextStyle(
            fontSize: 8.5,
            lineSpacing: 2,
            color: PdfColors.grey800,
          ),
        ),
      );

  static pw.Widget _pdfSectionTitle(String title) => pw.Padding(
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

  static pw.Widget _pdfRows(List<List<String>> rows) => pw.Column(
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
