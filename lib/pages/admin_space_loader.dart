import 'package:flutter/material.dart';

import 'admin_space_hub_page.dart';

/// Point d’entrée stable vers l’espace admin.
///
/// Le hub organise les domaines de pilotage sous forme de tuiles cliquables,
/// tout en conservant l’accès au tableau admin complet et à ses outils.
class AdminSpaceLoader extends StatelessWidget {
  const AdminSpaceLoader({super.key});

  @override
  Widget build(BuildContext context) => const AdminSpaceHubPage();
}
