import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminMonitoringHealthPage extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? eventsStream;

  const AdminMonitoringHealthPage({
    super.key,
    this.eventsStream,
  });

  Stream<List<Map<String, dynamic>>> _watchEvents() {
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();

    return FirebaseFirestore.instance
        .collection('app_monitoring_events')
        .where('createdAtClient', isGreaterThan: since)
        .orderBy('createdAtClient', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => document.data())
              .toList(growable: false),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Santé app'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: eventsStream ?? _watchEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erreur monitoring : ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!;

          final errors = events
              .where((event) =>
                  event['level'] == 'error' || event['level'] == 'critical')
              .length;

          final criticals =
              events.where((event) => event['level'] == 'critical').length;

          final warnings =
              events.where((event) => event['level'] == 'warning').length;

          final appCheckRefused = events
              .where((event) =>
                  event['scope'] == 'app_check' &&
                  event['action'] == 'refused')
              .length;

          final adminConnections = events
              .where((event) =>
                  event['scope'] == 'admin' &&
                  event['action'] == 'admin_connected')
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HealthCard(
                    label: 'Événements 24h',
                    value: events.length.toString(),
                    icon: Icons.monitor_heart,
                  ),
                  _HealthCard(
                    label: 'Erreurs',
                    value: errors.toString(),
                    icon: Icons.error_outline,
                  ),
                  _HealthCard(
                    label: 'Critiques',
                    value: criticals.toString(),
                    icon: Icons.warning_amber,
                  ),
                  _HealthCard(
                    label: 'Warnings',
                    value: warnings.toString(),
                    icon: Icons.report_problem_outlined,
                  ),
                  _HealthCard(
                    label: 'App Check refusé',
                    value: appCheckRefused.toString(),
                    icon: Icons.security,
                  ),
                  _HealthCard(
                    label: 'Admin connecté',
                    value: adminConnections.toString(),
                    icon: Icons.admin_panel_settings,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Derniers événements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const Text('Aucun événement monitoring sur les dernières 24h.'),
              for (final event in events)
                Card(
                  child: ListTile(
                    leading: Icon(_iconForLevel(event['level']?.toString())),
                    title: Text(
                      '${event['scope'] ?? '-'} / ${event['action'] ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${event['level'] ?? '-'} · ${event['message'] ?? ''}\n'
                      'Build ${event['appBuild'] ?? '-'} · Commit ${event['gitCommit'] ?? '-'}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static IconData _iconForLevel(String? level) {
    switch (level) {
      case 'critical':
        return Icons.warning_amber;
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.report_problem_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
