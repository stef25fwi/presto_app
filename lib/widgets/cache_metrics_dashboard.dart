import 'package:flutter/material.dart';
import 'package:presto_app/services/cache_monitoring_service.dart';

/// Dashboard pour visualiser les metrics du cache en temps réel
class CacheMetricsDashboard extends StatefulWidget {
  const CacheMetricsDashboard({super.key});

  @override
  State<CacheMetricsDashboard> createState() => _CacheMetricsDashboardState();
}

class _CacheMetricsDashboardState extends State<CacheMetricsDashboard> {
  final _monitoring = CacheMonitoringService();
  late Future<Map<String, dynamic>?> _stats24h;

  @override
  void initState() {
    super.initState();
    _stats24h = _monitoring.getLast24hStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Metrics'),
        elevation: 0,
        backgroundColor: const Color(0xFFFF6600),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Session actuelle
          _buildSessionCard(),
          const SizedBox(height: 16),

          // Stats dernières 24h
          _buildLast24hCard(),
          const SizedBox(height: 16),

          // Actions
          _buildActionsCard(),
        ],
      ),
    );
  }

  Widget _buildSessionCard() {
    final m = _monitoring.metrics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session actuelle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _metricRow('Total requêtes', m.totalRequests.toString()),
            _metricRow('Hits (cache)', m.cacheHits.toString(),
                color: Colors.green),
            _metricRow('Misses (générés)', m.cacheMisses.toString(),
                color: Colors.orange),
            _metricRow('Erreurs', m.cacheErrors.toString(), color: Colors.red),
            const Divider(height: 20),
            _metricRow(
              'Hit rate',
              '${m.hitRate.toStringAsFixed(1)}%',
              color: m.hitRate >= 50 ? Colors.green : Colors.orange,
              bold: true,
            ),
            _metricRow(
              'Miss rate',
              '${m.missRate.toStringAsFixed(1)}%',
              color: m.missRate >= 50 ? Colors.orange : Colors.green,
              bold: true,
            ),
            _metricRow('Temps moyen', '${m.avgAccessTime.inMilliseconds}ms'),
          ],
        ),
      ),
    );
  }

  Widget _buildLast24hCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _stats24h,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pas de données disponibles',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        final stats = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dernières 24h',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _metricRow('Total requêtes', '${stats['total_requests']}'),
                _metricRow('Hits', '${stats['total_hits']}',
                    color: Colors.green),
                _metricRow('Misses', '${stats['total_misses']}',
                    color: Colors.orange),
                _metricRow('Erreurs', '${stats['total_errors']}',
                    color: Colors.red),
                const Divider(height: 20),
                _metricRow(
                  'Hit rate',
                  '${(stats['hit_rate'] as double).toStringAsFixed(1)}%',
                  color: stats['hit_rate'] >= 50 ? Colors.green : Colors.orange,
                  bold: true,
                ),
                _metricRow('Samples', '${stats['samples']}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _monitoring.printMetrics();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Metrics affichées en console')),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('Afficher en console'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _monitoring.saveMetricsToFirestore();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Metrics sauvegardées')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Sauvegarder en Firestore'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _monitoring.reset();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Metrics réinitialisées')),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
