import 'package:flutter/material.dart';

import '../core/connectivity/connectivity_status.dart';
import '../widgets/cookie_consent_banner.dart';
import '../widgets/offline_banner.dart';
import 'typography_settings.dart';

/// Habillage commun à toutes les pages : réglages typographiques de
/// l'utilisateur (police, graisse, échelle) puis les bandeaux superposés —
/// consentement cookies en bas, état hors-ligne en haut.
class PrestoAppChrome extends StatelessWidget {
  final Widget child;

  const PrestoAppChrome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: typographySettings,
      builder: (ctx, _) {
        final base = Theme.of(ctx);
        final delta = typographySettings.fontWeightDelta;
        final withFamily =
            base.textTheme.apply(fontFamily: typographySettings.fontFamily);
        final withWeight = shiftTextThemeWeight(withFamily, delta);
        final primaryWithFamily = base.primaryTextTheme
            .apply(fontFamily: typographySettings.fontFamily);
        final primaryWithWeight =
            shiftTextThemeWeight(primaryWithFamily, delta);
        return Theme(
          data: base.copyWith(
            textTheme: withWeight,
            primaryTextTheme: primaryWithWeight,
            appBarTheme: base.appBarTheme.copyWith(
              titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: typographySettings.fontFamily,
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              textScaler: TextScaler.linear(typographySettings.scale),
            ),
            child: Stack(
              children: [
                child,
                // CookieConsentBanner renvoie lui-même un Positioned.fill
                // lorsque le consentement doit être affiché. Il doit donc être
                // un enfant direct du Stack. Le wrapper Positioned/Align
                // précédent cassait son ParentData et ne laissait visible que
                // le voile modal gris, sans la feuille de consentement.
                const CookieConsentBanner(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ListenableBuilder(
                    listenable: ConnectivityStatus.instance,
                    builder: (_, __) => OfflineBanner(
                      isVisible: !ConnectivityStatus.instance.isOnline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
