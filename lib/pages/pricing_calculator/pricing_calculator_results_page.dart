part of '../pricing_calculator_page.dart';

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

