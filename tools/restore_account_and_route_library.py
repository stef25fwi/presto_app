from pathlib import Path
import subprocess

# Le tableau de bord historique ne doit pas être modifié : la carte Mes crédits
# y est déjà injectée par SubscriptionSection, qui est un composant externe.
Path("lib/pages/account_page.dart").write_bytes(
    subprocess.check_output(["git", "show", "origin/main:lib/pages/account_page.dart"])
)

# Le nom public historique est conservé, mais route vers la bibliothèque V2.
Path("lib/pages/account/mon_entreprise_parcours_page.dart").write_text(
    """import 'package:flutter/material.dart';

import 'mon_entreprise_parcours_library_page.dart';

/// Alias de compatibilité vers la bibliothèque cloud multi-parcours.
class MonEntrepriseParcoursPage extends StatelessWidget {
  const MonEntrepriseParcoursPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonEntrepriseParcoursLibraryPage();
  }
}
""",
    encoding="utf-8",
)

print("account restored and journey library routed")
