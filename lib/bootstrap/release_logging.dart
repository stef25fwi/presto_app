import 'package:flutter/foundation.dart';

/// Neutralise `debugPrint` dans les builds release.
///
/// Sur Android, `debugPrint` écrit dans logcat. Toute application disposant de
/// la permission de lecture des journaux, et toute personne branchant
/// l'appareil, peut donc lire ce que l'application journalise. Le code client
/// compte plus de trois cents appels, dont les plus nombreux se trouvent dans
/// les services de notification, de compte et d'authentification sociale :
/// autant de chemins qui manipulent des données personnelles.
///
/// Plutôt que de reprendre chaque appel, on remplace l'implémentation de
/// `debugPrint` — que Flutter expose précisément comme un point d'extension
/// réassignable. Un seul point de contrôle, aucun appelant à modifier, et
/// aucune régression possible sur le comportement de débogage : en debug et en
/// profil, la sortie reste inchangée.
///
/// Le backend applique déjà cette discipline côté Cloud Functions, où le smoke
/// test de production échoue si une clé sensible apparaît dans les journaux.
/// Cette fonction donne au client l'équivalent.
void silenceDebugPrintInRelease() {
  if (!kReleaseMode) return;
  debugPrint = _silentDebugPrint;
}

void _silentDebugPrint(String? message, {int? wrapWidth}) {}
