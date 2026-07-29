part of '../pricing_calculator_page.dart';

class _PricingHistoryPage extends StatefulWidget {
  const _PricingHistoryPage();

  @override
  State<_PricingHistoryPage> createState() => _PricingHistoryPageState();
}

class _PricingHistoryPageState extends State<_PricingHistoryPage> {
  late Future<List<PricingProjectRecord>> _projects;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _projects = PricingProjectStorage.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _PrestoTopBar(
        title: 'Mes calculs',
        background: kPrestoBlue,
        showBack: true,
      ),
      body: FutureBuilder<List<PricingProjectRecord>>(
        future: _projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snapshot.data ?? const [];
          if (projects.isEmpty) {
            return const _EmptyHistory();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kPrestoBlue.withValues(alpha: 0.12),
                    foregroundColor: kPrestoBlue,
                    child: const Icon(Icons.calculate_outlined),
                  ),
                  title: Text(
                    project.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${project.mode.label} • ${_formatDate(project.createdAt)}\n'
                    'Prix conseillé : ${_money(project.result.prixTTC)} € TTC',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await PricingProjectStorage.delete(project.id);
                      if (!mounted) return;
                      setState(_reload);
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ResultsPage(
                          mode: project.mode,
                          projectName: project.name,
                          input: project.input,
                          result: project.result,
                          marketLow: project.marketLow,
                          marketMid: project.marketMid,
                          marketHigh: project.marketHigh,
                          volumePrudent: project.volumePrudent,
                          volumeHaut: project.volumeHaut,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              'Aucun calcul enregistré',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Les analyses Expert sauvegardées apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

