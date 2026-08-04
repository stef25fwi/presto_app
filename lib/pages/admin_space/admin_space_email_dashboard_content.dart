// Contenu du tableau de bord e-mail et feuilles de détail.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _EmailDashboardContent extends StatelessWidget {
  final _EmailDashboardWindow window;

  const _EmailDashboardContent({required this.window});

  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    final threshold =
        DateTime.now().subtract(window.duration).millisecondsSinceEpoch;
    final logsStream = FirebaseFirestore.instance
        .collection('email_logs')
        .where('created_at', isGreaterThanOrEqualTo: threshold)
        .orderBy('created_at', descending: true)
        .limit(1000)
        .get()
        .asStream();
    final jobsStream = FirebaseFirestore.instance
        .collection('email_jobs')
        .where('updated_at', isGreaterThanOrEqualTo: threshold)
        .orderBy('updated_at', descending: true)
        .limit(60)
        .get()
        .asStream();
    final ticketsStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .orderBy('updated_at', descending: true)
        .limit(60)
        .get()
        .asStream();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, logsSnapshot) {
        if (logsSnapshot.hasError) {
          return _AdminInfoState(
            icon: Icons.warning_amber_rounded,
            title: 'Lecture impossible',
            message:
                'Les logs email ne sont pas accessibles. Vérifie les droits admin ou les index Firestore.',
            color: Colors.red.shade700,
          );
        }

        if (logsSnapshot.connectionState == ConnectionState.waiting &&
            !logsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = _EmailDashboardStats.fromLogs(
          logsSnapshot.data?.docs ?? [],
        );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: jobsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AdminInfoState(
                icon: Icons.warning_amber_rounded,
                title: 'Lecture impossible',
                message:
                    'Les jobs email ne sont pas accessibles. Vérifie les droits admin ou les index Firestore.',
                color: Colors.red.shade700,
              );
            }

            final deadLetters = (snapshot.data?.docs ?? [])
                .where(
                  (doc) =>
                      (doc.data()['status'] ?? '').toString() == 'dead_letter',
                )
                .toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ticketsStream,
              builder: (context, ticketsSnapshot) {
                if (ticketsSnapshot.hasError) {
                  return _AdminInfoState(
                    icon: Icons.warning_amber_rounded,
                    title: 'Lecture impossible',
                    message:
                        'Les tickets support ne sont pas accessibles. Vérifie les droits admin.',
                    color: Colors.red.shade700,
                  );
                }

                final tickets = (ticketsSnapshot.data?.docs ?? [])
                    .where(
                      (doc) => _toInt(doc.data()['updated_at']) >= threshold,
                    )
                    .toList();
                final openTickets = tickets
                    .where(
                      (doc) =>
                          (doc.data()['status'] ?? 'open').toString() == 'open',
                    )
                    .length;
                final hasAlert = deadLetters.isNotEmpty ||
                    stats.failed > 0 ||
                    stats.bounceRate >= 0.05 ||
                    stats.complaintRate >= 0.01;

                final providerEntries = stats.byProvider.entries.toList()
                  ..sort((a, b) {
                    return (b.value['sent'] ?? 0).compareTo(
                      a.value['sent'] ?? 0,
                    );
                  });
                final templateEntries = stats.byTemplate.entries.toList()
                  ..sort((a, b) {
                    return (b.value['sent'] ?? 0).compareTo(
                      a.value['sent'] ?? 0,
                    );
                  });

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardShell(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          (hasAlert ? Colors.red : prestoBlue)
                                              .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      hasAlert
                                          ? Icons.warning_amber_rounded
                                          : Icons.verified_rounded,
                                      color: hasAlert
                                          ? Colors.red.shade700
                                          : prestoBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hasAlert
                                              ? 'Livrabilité à surveiller'
                                              : 'Cockpit email temps réel',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fenêtre ${window.label} • ${stats.sampledLogs} logs • maj ${_formatAdminTimestamp(DateTime.now().millisecondsSinceEpoch)}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _DashboardPill(
                                    label: 'Taux délivré',
                                    value:
                                        '${(stats.deliveryRate * 100).toStringAsFixed(1)}%',
                                    color: Colors.green.shade700,
                                  ),
                                  _DashboardPill(
                                    label: 'Bounce',
                                    value:
                                        '${(stats.bounceRate * 100).toStringAsFixed(1)}%',
                                    color: stats.bounceRate >= 0.05
                                        ? Colors.red.shade700
                                        : prestoBlue,
                                  ),
                                  _DashboardPill(
                                    label: 'Plaintes',
                                    value:
                                        '${(stats.complaintRate * 100).toStringAsFixed(1)}%',
                                    color: stats.complaintRate >= 0.01
                                        ? Colors.red.shade700
                                        : prestoBlue,
                                  ),
                                  _DashboardPill(
                                    label: 'Dead letters',
                                    value: '${deadLetters.length}',
                                    color: deadLetters.isNotEmpty
                                        ? Colors.red.shade700
                                        : prestoOrange,
                                  ),
                                  _DashboardPill(
                                    label: 'Tickets ouverts',
                                    value: '$openTickets',
                                    color: openTickets > 0
                                        ? prestoOrange
                                        : prestoBlue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.warning_rounded,
                              title: 'Dead letters',
                              subtitle:
                                  '${deadLetters.length} job(s) en échec terminal',
                              color: Colors.red.shade700,
                              onTap: () =>
                                  _showDeadLettersSheet(context, deadLetters),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.support_agent_rounded,
                              title: 'Tickets support',
                              subtitle:
                                  '$openTickets ouvert(s) sur ${tickets.length}',
                              color: prestoBlue,
                              onTap: () =>
                                  _showSupportTicketsSheet(context, tickets),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        children: [
                          _MetricCard(
                            label: 'Envoyés',
                            value: '${stats.sent}',
                            icon: Icons.send_rounded,
                            color: prestoBlue,
                          ),
                          _MetricCard(
                            label: 'Délivrés',
                            value: '${stats.delivered}',
                            icon: Icons.mark_email_read_rounded,
                            color: Colors.green.shade700,
                          ),
                          _MetricCard(
                            label: 'Bounces',
                            value: '${stats.bounced}',
                            icon: Icons.report_gmailerrorred_rounded,
                            color: Colors.red.shade700,
                          ),
                          _MetricCard(
                            label: 'Plaintes',
                            value: '${stats.complained}',
                            icon: Icons.feedback_rounded,
                            color: Colors.amber.shade800,
                          ),
                          _MetricCard(
                            label: 'Échecs',
                            value: '${stats.failed}',
                            icon: Icons.error_outline_rounded,
                            color: Colors.red.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Par provider',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (providerEntries.isEmpty)
                        const _SimpleAdminEmpty(
                          message: 'Aucun provider remonté sur cette fenêtre.',
                        )
                      else
                        ...providerEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BreakdownCard(
                              title: entry.key,
                              data: entry.value,
                              accent: prestoBlue,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Top templates',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (templateEntries.isEmpty)
                        const _SimpleAdminEmpty(
                          message: 'Aucun template remonté sur cette fenêtre.',
                        )
                      else
                        ...templateEntries.take(8).map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _BreakdownCard(
                                  title: entry.key,
                                  data: entry.value,
                                  accent: prestoOrange,
                                ),
                              ),
                            ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

void _showDeadLettersSheet(
  BuildContext context,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> deadLetters,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BottomSheetScaffold(
      title: 'Dead letters',
      child: deadLetters.isEmpty
          ? const _SimpleAdminEmpty(
              message: 'Aucun dead letter sur la fenêtre sélectionnée.',
            )
          : Column(
              children: deadLetters
                  .map(
                    (doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminListTile(
                        title:
                            (doc.data()['template_code'] ?? doc.id).toString(),
                        subtitle:
                            'Raison: ${(doc.data()['dead_letter_reason'] ?? 'indisponible').toString()}\nMaj: ${_formatAdminTimestamp(_toInt(doc.data()['updated_at']))}',
                        trailing: _StatusBadge(
                          label: 'dead_letter',
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}

void _showSupportTicketsSheet(
  BuildContext context,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> tickets,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BottomSheetScaffold(
      title: 'Tickets support',
      child: tickets.isEmpty
          ? const _SimpleAdminEmpty(
              message: 'Aucun ticket support sur la fenêtre sélectionnée.',
            )
          : Column(
              children: tickets
                  .take(20)
                  .map(
                    (doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminListTile(
                        title: (doc.data()['ticket_number'] ??
                                doc.data()['subject'] ??
                                doc.id)
                            .toString(),
                        subtitle:
                            '${(doc.data()['subject'] ?? 'Sans sujet').toString()}\n${(doc.data()['category'] ?? 'general_support').toString()} • ${_formatAdminTimestamp(_toInt(doc.data()['updated_at']))}',
                        trailing: _StatusBadge(
                          label: (doc.data()['status'] ?? 'open').toString(),
                          color: (doc.data()['status'] ?? 'open').toString() ==
                                  'open'
                              ? const Color(0xFFFF6600)
                              : const Color(0xFF1A73E8),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}
