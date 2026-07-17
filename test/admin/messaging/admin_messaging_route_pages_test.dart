import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_conversations_page.dart';
import 'package:presto_app/admin/messaging/admin_message_reports_page.dart';
import 'package:presto_app/admin/messaging/admin_messaging_center_page.dart';
import 'package:presto_app/admin/messaging/admin_messaging_dashboard_page.dart';
import 'package:presto_app/admin/messaging/admin_messaging_users_page.dart';
import 'package:presto_app/models/admin_access_state.dart';

class _AdminMessagingRouteProbe extends StatelessWidget {
  const _AdminMessagingRouteProbe({
    required this.wrapper,
    required this.onBuilt,
  });

  final StatelessWidget wrapper;
  final ValueChanged<AdminMessagingCenterPage> onBuilt;

  @override
  Widget build(BuildContext context) {
    onBuilt(wrapper.build(context) as AdminMessagingCenterPage);
    return const SizedBox.shrink();
  }
}

void main() {
  final cases = <({
    String label,
    StatelessWidget wrapper,
    AdminMessagingSection section
  })>[
    (
      label: 'tableau de bord',
      wrapper: const AdminMessagingDashboardPage(),
      section: AdminMessagingSection.dashboard,
    ),
    (
      label: 'conversations',
      wrapper: const AdminConversationsPage(),
      section: AdminMessagingSection.conversations,
    ),
    (
      label: 'signalements',
      wrapper: const AdminMessageReportsPage(),
      section: AdminMessagingSection.reports,
    ),
    (
      label: 'utilisateurs',
      wrapper: const AdminMessagingUsersPage(),
      section: AdminMessagingSection.users,
    ),
  ];

  for (final testCase in cases) {
    testWidgets('la route ${testCase.label} transmet la bonne section', (
      tester,
    ) async {
      AdminMessagingCenterPage? builtPage;

      await tester.pumpWidget(
        MaterialApp(
          home: _AdminMessagingRouteProbe(
            wrapper: testCase.wrapper,
            onBuilt: (page) => builtPage = page,
          ),
        ),
      );

      expect(builtPage, isNotNull);
      expect(builtPage!.initialSection, testCase.section);
      expect(builtPage!.accessState, isNull);
    });
  }

  testWidgets('le dashboard transmet l état d accès fourni', (tester) async {
    final accessState = AdminAccessState.initial();
    AdminMessagingCenterPage? builtPage;

    await tester.pumpWidget(
      MaterialApp(
        home: _AdminMessagingRouteProbe(
          wrapper: AdminMessagingDashboardPage(accessState: accessState),
          onBuilt: (page) => builtPage = page,
        ),
      ),
    );

    expect(builtPage, isNotNull);
    expect(builtPage!.initialSection, AdminMessagingSection.dashboard);
    expect(builtPage!.accessState, same(accessState));
  });

  test('chaque section admin expose un libellé et une icône stables', () {
    final expected = <AdminMessagingSection, (String, IconData)>{
      AdminMessagingSection.dashboard: (
        'Vue d\'ensemble',
        Icons.space_dashboard_rounded,
      ),
      AdminMessagingSection.conversations: (
        'Conversations',
        Icons.forum_rounded,
      ),
      AdminMessagingSection.reports: ('Signalements', Icons.flag_rounded),
      AdminMessagingSection.risk: ('Risque', Icons.gpp_maybe_rounded),
      AdminMessagingSection.users: ('Utilisateurs', Icons.groups_rounded),
      AdminMessagingSection.attachments: (
        'Pièces jointes',
        Icons.attach_file_rounded,
      ),
      AdminMessagingSection.notifications: (
        'Notifications',
        Icons.notifications_active_rounded,
      ),
      AdminMessagingSection.settings: ('Paramètres', Icons.tune_rounded),
      AdminMessagingSection.audit: ('Audit', Icons.fact_check_rounded),
      AdminMessagingSection.analytics: ('Analytics', Icons.insights_rounded),
    };

    expect(expected.keys.toSet(), AdminMessagingSection.values.toSet());
    for (final entry in expected.entries) {
      expect(entry.key.label, entry.value.$1);
      expect(entry.key.icon, entry.value.$2);
    }
  });
}
