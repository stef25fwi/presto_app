import 'package:flutter/material.dart';

import 'admin/widgets/admin_contact_mail_widget.dart';
import 'admin_space_page.dart';

/// Point d’entrée stable vers l’espace administrateur complet.
///
/// L’accès depuis le compte ouvre directement le dashboard admin, sans passer
/// par le hub intermédiaire de pilotage. La boîte contact est superposée juste
/// sous l’AppBar afin de rester visible sans modifier la structure historique
/// du dashboard.
class AdminSpaceLoader extends StatelessWidget {
  const AdminSpaceLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 10;
    return Stack(
      children: [
        const AdminSpacePage(),
        Positioned(
          top: top,
          right: 12,
          child: const AdminContactMailWidget(),
        ),
      ],
    );
  }
}
