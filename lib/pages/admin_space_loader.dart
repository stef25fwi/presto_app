import 'package:flutter/material.dart';

import 'admin_space_page.dart';

/// Point d’entrée stable vers l’espace admin.
///
/// `admin_space_page.dart` est déjà importé normalement par `main.dart`. Le
/// charger également avec `deferred as` créait deux modes de chargement pour
/// la même bibliothèque et pouvait provoquer une `DeferredLoadException` sur
/// Flutter web après un déploiement. Ce chargeur reste utilisable par les
/// autres points d’entrée, sans créer de fragment JavaScript différé ambigu.
class AdminSpaceLoader extends StatelessWidget {
  const AdminSpaceLoader({super.key});

  @override
  Widget build(BuildContext context) => const AdminSpacePage();
}
