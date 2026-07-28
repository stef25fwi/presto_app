part of '../pricing_calculator_page.dart';

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

