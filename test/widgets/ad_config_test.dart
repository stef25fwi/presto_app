import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ad_banner.dart';

/// Préfixe du compte de démonstration publié par Google. Tout bloc qui le
/// porte renvoie une publicité de test et ne rapporte rien.
const String _googleDemoAccount = 'ca-app-pub-3940256099942544';

/// Compte AdMob d'iliprestō, celui déclaré dans le manifeste Android et dans
/// l'Info.plist iOS.
const String _realAccount = 'ca-app-pub-1792076968124623';

void main() {
  group('sélection du bloc bannière', () {
    test('une release sert les blocs réels', () {
      expect(
        AdConfig.bannerIdFor(TargetPlatform.android, releaseMode: true),
        AdConfig.androidBannerId,
      );
      expect(
        AdConfig.bannerIdFor(TargetPlatform.iOS, releaseMode: true),
        AdConfig.iosBannerId,
      );
    });

    test('hors release, les blocs de démonstration sont servis', () {
      // Charger une publicité réelle depuis un build de développement génère
      // du trafic invalide : motif de suspension du compte AdMob.
      expect(
        AdConfig.bannerIdFor(TargetPlatform.android, releaseMode: false),
        AdConfig.androidTestBannerId,
      );
      expect(
        AdConfig.bannerIdFor(TargetPlatform.iOS, releaseMode: false),
        AdConfig.iosTestBannerId,
      );
    });

    test('les plateformes sans régie renvoient un identifiant neutre', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          AdConfig.bannerIdFor(platform, releaseMode: true),
          AdConfig.unsupportedAdUnitId,
          reason: '$platform ne doit charger aucune publicité',
        );
      }
    });
  });

  group('cloisonnement des comptes AdMob', () {
    test('aucun bloc de démonstration ne peut être servi en release', () {
      // Le défaut corrigé : des blocs du compte de démonstration Google
      // étaient déclarés comme identifiants de production.
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        final id = AdConfig.bannerIdFor(platform, releaseMode: true);
        expect(
          id.startsWith(_googleDemoAccount),
          isFalse,
          reason: '$platform sert un bloc de démonstration en release',
        );
        expect(id.startsWith(_realAccount), isTrue, reason: '$platform');
      }
    });

    test('aucun bloc réel ne peut être servi hors release', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        final id = AdConfig.bannerIdFor(platform, releaseMode: false);
        expect(
          id.startsWith(_realAccount),
          isFalse,
          reason: '$platform sert un bloc réel hors release',
        );
        expect(id.startsWith(_googleDemoAccount), isTrue, reason: '$platform');
      }
    });

    test('les blocs réels appartiennent au compte déclaré aux manifestes', () {
      expect(AdConfig.androidBannerId, startsWith('$_realAccount/'));
      expect(AdConfig.iosBannerId, startsWith('$_realAccount/'));
    });

    test('le web ne se voit proposer aucun bloc', () {
      // `google_mobile_ads` ne diffuse pas sur le web, et AdMob non plus : une
      // bannière web relèverait d'AdSense, avec un identifiant `ca-pub-…` et
      // un emplacement numérique qui n'existent nulle part ici.
      expect(
        AdConfig.bannerIdFor(TargetPlatform.android, releaseMode: true),
        isNot(AdConfig.unsupportedAdUnitId),
      );
      expect(AdConfig.unsupportedAdUnitId, 'unsupported');
    });

    test('release et développement ne partagent jamais un bloc', () {
      expect(AdConfig.androidBannerId, isNot(AdConfig.androidTestBannerId));
      expect(AdConfig.iosBannerId, isNot(AdConfig.iosTestBannerId));
    });
  });
}
