import 'package:flutter/material.dart';

import 'admin_space_page.dart' deferred as admin_space;

/// Charge l'espace admin en différé (split de bundle sur le web).
///
/// L'espace admin ne concerne qu'une poignée d'utilisateurs : le différer
/// évite d'embarquer son code dans le bundle initial téléchargé par tous
/// les visiteurs. Sur mobile, `loadLibrary()` complète immédiatement.
class AdminSpaceLoader extends StatefulWidget {
  const AdminSpaceLoader({super.key});

  @override
  State<AdminSpaceLoader> createState() => _AdminSpaceLoaderState();
}

class _AdminSpaceLoaderState extends State<AdminSpaceLoader> {
  late final Future<void> _library = admin_space.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _library,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Espace admin')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Le module admin n\'a pas pu être chargé. '
                  'Vérifiez votre connexion puis réessayez.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return admin_space.AdminSpacePage();
      },
    );
  }
}
