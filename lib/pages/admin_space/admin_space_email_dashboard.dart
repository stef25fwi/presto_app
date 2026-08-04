// Tableau de bord e-mail : fenêtres, statistiques et écran.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

extension _EmailDashboardWindowX on _EmailDashboardWindow {
  String get label {
    switch (this) {
      case _EmailDashboardWindow.hour1:
        return '1 h';
      case _EmailDashboardWindow.day1:
        return '24 h';
      case _EmailDashboardWindow.day7:
        return '7 j';
    }
  }

  Duration get duration {
    switch (this) {
      case _EmailDashboardWindow.hour1:
        return const Duration(hours: 1);
      case _EmailDashboardWindow.day1:
        return const Duration(hours: 24);
      case _EmailDashboardWindow.day7:
        return const Duration(days: 7);
    }
  }
}

class _EmailDashboardStats {
  final int sent;
  final int delivered;
  final int bounced;
  final int complained;
  final int failed;
  final int sampledLogs;
  final Map<String, Map<String, int>> byProvider;
  final Map<String, Map<String, int>> byTemplate;

  const _EmailDashboardStats({
    required this.sent,
    required this.delivered,
    required this.bounced,
    required this.complained,
    required this.failed,
    required this.sampledLogs,
    required this.byProvider,
    required this.byTemplate,
  });

  double get deliveryRate => sent > 0 ? delivered / sent : 0.0;
  double get bounceRate => sent > 0 ? bounced / sent : 0.0;
  double get complaintRate => sent > 0 ? complained / sent : 0.0;

  static _EmailDashboardStats fromLogs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int sent = 0;
    int delivered = 0;
    int bounced = 0;
    int complained = 0;
    int failed = 0;
    final byProvider = <String, Map<String, int>>{};
    final byTemplate = <String, Map<String, int>>{};

    void incrementBucket(
      Map<String, Map<String, int>> target,
      String key,
      String status,
    ) {
      final bucket = target.putIfAbsent(
        key,
        () => <String, int>{
          'sent': 0,
          'delivered': 0,
          'bounced': 0,
          'complained': 0,
          'failed': 0,
        },
      );
      bucket[status] = (bucket[status] ?? 0) + 1;
    }

    for (final doc in docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim();
      final provider = (data['provider'] ?? 'unknown').toString().trim();
      final template = (data['template_code'] ?? 'unknown').toString().trim();

      switch (status) {
        case 'sent':
          sent += 1;
        case 'delivered':
          delivered += 1;
        case 'bounced':
          bounced += 1;
        case 'complained':
          complained += 1;
        case 'failed':
          failed += 1;
        default:
          continue;
      }

      incrementBucket(
        byProvider,
        provider.isEmpty ? 'unknown' : provider,
        status,
      );
      incrementBucket(
        byTemplate,
        template.isEmpty ? 'unknown' : template,
        status,
      );
    }

    return _EmailDashboardStats(
      sent: sent,
      delivered: delivered,
      bounced: bounced,
      complained: complained,
      failed: failed,
      sampledLogs: docs.length,
      byProvider: byProvider,
      byTemplate: byTemplate,
    );
  }
}

class EmailDashboardPage extends StatefulWidget {
  const EmailDashboardPage({super.key});

  @override
  State<EmailDashboardPage> createState() => _EmailDashboardPageState();
}

class _EmailDashboardPageState extends State<EmailDashboardPage> {
  _EmailDashboardWindow _window = _EmailDashboardWindow.hour1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Dashboard email', style: kPrestoAppBarTitleStyle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  for (final window in _EmailDashboardWindow.values) ...[
                    _WindowChip(
                      label: window.label,
                      selected: _window == window,
                      onTap: () => setState(() => _window = window),
                    ),
                    if (window != _EmailDashboardWindow.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(child: _EmailDashboardContent(window: _window)),
          ],
        ),
      ),
    );
  }
}
