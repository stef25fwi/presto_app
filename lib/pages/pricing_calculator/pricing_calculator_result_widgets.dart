part of '../pricing_calculator_page.dart';

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

