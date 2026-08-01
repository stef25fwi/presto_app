import 'package:flutter/foundation.dart' show TargetPlatform;

/// Blocs publicitaires AdMob.
///
/// Les blocs réels ne doivent servir **qu'en release**. Charger une publicité
/// depuis un build de développement génère du trafic invalide sur le compte
/// AdMob : c'est un motif de suspension, et cela fausse les statistiques de
/// diffusion. Les blocs de démonstration Google existent exactement pour ça et
/// sont donc utilisés partout ailleurs.
class AdConfig {
  /// Bloc bannière réel — compte `ca-app-pub-1792076968124623`, celui déclaré
  /// dans `AndroidManifest.xml` et `Info.plist`.
  static const String androidBannerId =
      'ca-app-pub-1792076968124623/1951540793';
  static const String iosBannerId =
      'ca-app-pub-1792076968124623/4960847514';

  /// Blocs de démonstration publiés par Google : ils renvoient toujours une
  /// publicité de test et ne créditent aucun revenu.
  static const String androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Valeur sentinelle pour les plateformes sans régie : le web, où
  /// `google_mobile_ads` ne diffuse pas, et les cibles desktop.
  static const String unsupportedAdUnitId = 'unsupported';

  /// Bloc bannière à utiliser pour une plateforme donnée.
  ///
  /// `releaseMode` est un paramètre plutôt qu'une lecture directe de
  /// `kReleaseMode` pour que les deux branches soient vérifiables en test —
  /// la suite de tests s'exécute toujours en mode debug.
  static String bannerIdFor(
    TargetPlatform platform, {
    required bool releaseMode,
  }) {
    switch (platform) {
      case TargetPlatform.android:
        return releaseMode ? androidBannerId : androidTestBannerId;
      case TargetPlatform.iOS:
        return releaseMode ? iosBannerId : iosTestBannerId;
      default:
        return unsupportedAdUnitId;
    }
  }
}
