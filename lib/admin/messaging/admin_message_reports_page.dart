import 'package:flutter/material.dart';

import '../../models/admin_access_state.dart';
import 'admin_messaging_center_page.dart';

class AdminMessageReportsPage extends StatelessWidget {
  final AdminAccessState? accessState;

  const AdminMessageReportsPage({
    super.key,
    this.accessState,
  });

  @override
  Widget build(BuildContext context) {
    return AdminMessagingCenterPage(
      initialSection: AdminMessagingSection.reports,
      accessState: accessState,
    );
  }
}