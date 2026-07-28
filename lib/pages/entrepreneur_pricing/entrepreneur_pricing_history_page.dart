import 'package:flutter/material.dart';

import 'entrepreneur_pricing_results_page.dart';
import 'entrepreneur_pricing_results_widgets.dart';
import 'entrepreneur_pricing_storage.dart';

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
    _reload();
  }

  void _reload() {
    _future = EntrepreneurPricingStorage.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: PricingAppBar(
        color: pricingOrange,
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
                  leading: const Icon(
                    Icons.calculate_outlined,
                    color: pricingBlue,
                  ),
                  title: Text(
                    record.draft.projectName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${pricingDate(record.createdAt)} • '
                    '${pricingMoney(record.calculation.suggestedPriceTtc)} € conseillé',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
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
                      if (!mounted) return;
                      setState(_reload);
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