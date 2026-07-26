import 'package:flutter/material.dart';

import 'admin_space_page.dart';

/// Point d’entrée stable vers l’espace administrateur complet.
///
/// L’accès depuis le compte ouvre directement le dashboard admin, sans passer
/// par le hub intermédiaire de pilotage.
class AdminSpaceLoader extends StatelessWidget {
  const AdminSpaceLoader({super.key});

  @override
  Widget build(BuildContext context) => const AdminSpacePage();
}
