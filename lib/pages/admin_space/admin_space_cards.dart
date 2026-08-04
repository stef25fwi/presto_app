// Cartes d'entrée messagerie, badges et tuiles d'indicateurs.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _AdminMessagingEntryCard extends StatelessWidget {
  final AdminAccessState? accessState;

  const _AdminMessagingEntryCard({required this.accessState});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AdminMessagingDashboardPage(accessState: accessState),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF0F766E),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion messagerie',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Accès direct au dashboard, aux signalements, à l’audit et aux réglages.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF0F766E),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _EmailSummaryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _EmailSummaryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('system_settings')
        .doc('email_dashboard_current')
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final metrics = _stringKeyMap(data?['metrics']);
        final sent = _toInt(metrics['sent']);
        final failed = _toInt(metrics['failed']);
        final deadLetters = _toInt(data?['recent_dead_letters']);
        final hours = _toInt(data?['window_hours']);

        final subtitle = snapshot.hasError
            ? 'Accès snapshot\nà vérifier'
            : data == null
                ? 'Aucun snapshot\ndisponible'
                : '${hours > 0 ? hours : 1} h\nEnvoyés: $sent\nÉchecs: $failed\nDL: $deadLetters';

        return _KpiTile(
          icon: Icons.mark_email_unread_rounded,
          title: 'Emails',
          subtitle: subtitle,
          badge: null,
          iconColor: const Color(0xFFFF6600),
          onTap: onTap,
        );
      },
    );
  }
}

class _DashboardPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final Color accent;

  const _BreakdownCard({
    required this.title,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final sent = _toInt(data['sent']);
    final delivered = _toInt(data['delivered']);
    final bounced = _toInt(data['bounced']);
    final complained = _toInt(data['complained']);
    final failed = _toInt(data['failed']);

    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DashboardPill(label: 'sent', value: '$sent', color: accent),
                _DashboardPill(
                  label: 'delivered',
                  value: '$delivered',
                  color: Colors.green.shade700,
                ),
                _DashboardPill(
                  label: 'bounced',
                  value: '$bounced',
                  color: Colors.red.shade700,
                ),
                _DashboardPill(
                  label: 'complained',
                  value: '$complained',
                  color: Colors.amber.shade800,
                ),
                _DashboardPill(
                  label: 'failed',
                  value: '$failed',
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color iconColor;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              if (badge != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 28, color: iconColor),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      subtitle,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
