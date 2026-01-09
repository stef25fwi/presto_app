import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class StreamingMonitoringPage extends StatefulWidget {
  const StreamingMonitoringPage({super.key});

  @override
  State<StreamingMonitoringPage> createState() => _StreamingMonitoringPageState();
}

class _StreamingMonitoringPageState extends State<StreamingMonitoringPage> {
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  bool _loading = true;
  Map<String, dynamic>? _metrics;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final callable = _functions.httpsCallable(
        'adminGetStreamingMetrics',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final res = await callable.call<dynamic>({});
      final data = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _metrics = data;
        _lastRefresh = DateTime.now();
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erreur metrics streaming')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur metrics: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRequests = (_metrics?['totalRequests'] as num?)?.toInt() ?? 0;
    final successRate = (_metrics?['successRate'] as num?)?.toDouble() ?? 0.0;
    final avgLatency = (_metrics?['avgLatency'] as num?)?.toInt() ?? 0;
    final estCost = (_metrics?['estimatedDailyCost'] as num?)?.toDouble() ?? 0.0;
    final activeStreams = (_metrics?['activeStreams'] as num?)?.toInt() ?? 0;
    final errorCount = (_metrics?['errorCount'] as num?)?.toInt() ?? 0;

    final refreshTime = _lastRefresh != null
        ? '${_lastRefresh!.hour.toString().padLeft(2, '0')}:${_lastRefresh!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Retour',
        ),
        title: const Text(
          'Streaming WebSocket — Monitoring',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadMetrics,
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading && _metrics == null
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(prestoOrange),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Métriques en direct',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                        ),
                        Text(
                          'Mis à jour: $refreshTime',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // KPI Grid
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 140,
                      ),
                      children: [
                        _MetricCard(
                          icon: Icons.cloud_upload_rounded,
                          title: 'Requêtes',
                          value: totalRequests.toString(),
                          subtitle: 'Total streaming',
                          color: prestoBlue,
                        ),
                        _MetricCard(
                          icon: Icons.check_circle_rounded,
                          title: 'Succès',
                          value: '${(successRate * 100).toStringAsFixed(1)}%',
                          subtitle: 'Taux de réussite',
                          color: Colors.green,
                        ),
                        _MetricCard(
                          icon: Icons.speed_rounded,
                          title: 'Latence',
                          value: '${avgLatency}ms',
                          subtitle: 'Temps moyen',
                          color: prestoOrange,
                        ),
                        _MetricCard(
                          icon: Icons.attach_money_rounded,
                          title: 'Coût',
                          value: '\$${estCost.toStringAsFixed(2)}',
                          subtitle: 'Coût estimé/jour',
                          color: Colors.orange,
                        ),
                        _MetricCard(
                          icon: Icons.router_rounded,
                          title: 'Actifs',
                          value: activeStreams.toString(),
                          subtitle: 'Connexions en cours',
                          color: Colors.blue.shade600,
                        ),
                        _MetricCard(
                          icon: Icons.error_rounded,
                          title: 'Erreurs',
                          value: errorCount.toString(),
                          subtitle: 'Erreurs détectées',
                          color: Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Backend status
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Backend Cloud Run',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              const Chip(
                                label: Text('Opérationnel'),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                backgroundColor: Color(0xFFE8F5E9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'wss://presto-microia-stream-151421230024.us-east1.run.app/stream',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.place_rounded, size: 16, color: Colors.black54),
                              const SizedBox(width: 6),
                              const Text(
                                'Région: us-east1 (Virginia)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Performance chart placeholder
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tendances (24h)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Graphique à implémenter',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Info box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_rounded, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Coût estimé basé sur le nombre de requêtes (Google STT + Gemini API)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
