import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web public prelaunch shell', () {
    late String html;
    late String bootstrap;
    late String publicRouteSeo;
    late String webBridge;
    late String appChrome;
    late Map<String, dynamic> structuredData;
    late List<Map<String, dynamic>> structuredNodes;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
      bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      publicRouteSeo = File('web/public-route-seo.js').readAsStringSync();
      webBridge = File(
        'lib/platform/public_prelaunch_shell_web.dart',
      ).readAsStringSync();
      appChrome = File('lib/app/presto_app_chrome.dart').readAsStringSync();

      final jsonLdMatch = RegExp(
        r'<script\s+type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
      ).firstMatch(html);
      if (jsonLdMatch == null) {
        throw StateError('Le bloc JSON-LD public est absent de web/index.html.');
      }

      final decoded = jsonDecode(jsonLdMatch.group(1)!);
      if (decoded is! Map) {
        throw StateError('Le bloc JSON-LD public doit contenir un objet JSON.');
      }
      structuredData = decoded.cast<String, dynamic>();

      final graph = structuredData['@graph'];
      final rawNodes = graph is List ? graph : <dynamic>[structuredData];
      structuredNodes = rawNodes
          .whereType<Map>()
          .map((node) => node.cast<String, dynamic>())
          .toList(growable: false);
    });

    test('expose le contenu essentiel sans dépendre du rendu Flutter', () {
      expect(html, contains('id="prelaunch-seo-shell"'));
      expect(
        html,
        contains(
          'La solution à tout moment pour tous vos besoins du quotidien',
        ),
      );
      expect(html, contains('Annonces assistées par IA'));
      expect(html, contains('Publication par texte ou par voix'));
      expect(html, contains('Échanges directs entre utilisateurs'));
      expect(html, contains('0 % de commission'));
      expect(
        html,
        contains('ne collecte ni ne gère les paiements entre utilisateurs'),
      );
    });

    test('déclare les métadonnées SEO et sociales canoniques', () {
      expect(html, contains('<html lang="fr">'));
      expect(
        html,
        contains('<link rel="canonical" href="https://ilipresto.fr/">'),
      );
      expect(html, contains('<meta name="robots" content="index,follow'));
      expect(html, contains('property="og:title"'));
      expect(html, contains('name="twitter:title"'));
      expect(html, contains('type="application/ld+json"'));
    });

    test('déclare un graphe JSON-LD national valide', () {
      expect(structuredData['@context'], 'https://schema.org');
      final types = structuredNodes.map((node) => node['@type']).toSet();
      expect(
        types,
        containsAll(<String>{'Organization', 'WebSite', 'WebPage', 'Service'}),
      );
    });

    test('ne charge pas Flutter avant le déverrouillage de la racine publique',
        () {
      expect(bootstrap, contains('const deferredPublicPrelaunch ='));
      expect(
        bootstrap,
        contains(
          'useFlutterPrelaunchOnly && '
          '!window.iliprestoHasPrelaunchAccess()',
        ),
      );
      expect(
        bootstrap,
        contains(
          'if (deferredPublicPrelaunch) {\n'
          '    armHiddenDeveloperAccess();\n'
          '    return;\n'
          '  }',
        ),
      );
    });

    test('conserve huit taps invisibles avec remise à zéro après huit secondes',
        () {
      expect(bootstrap, contains('const developerAccessTapCount = 8;'));
      expect(bootstrap, contains('const tapSequenceTimeoutMs = 8000;'));
      expect(
        bootstrap,
        contains("shell.querySelector('.prelaunch-card')"),
      );
      expect(bootstrap, contains("trigger.addEventListener('click'"));
      expect(bootstrap, contains('tapCount >= developerAccessTapCount'));
      expect(bootstrap, isNot(contains('tapCount.toString')));
      expect(bootstrap, isNot(contains('Compteur')));
    });

    test('mémorise le déverrouillage dans l’onglet et ouvre directement Home',
        () {
      expect(
        bootstrap,
        contains("const prelaunchAccessStorageKey = 'ilipresto-prelaunch-access'"),
      );
      expect(bootstrap, contains('window.iliprestoHasPrelaunchAccess'));
      expect(bootstrap, contains('persistPrelaunchAccess();'));
      expect(webBridge, contains("@JS('iliprestoHasPrelaunchAccess')"));
      expect(webBridge, contains('bool hasPublicPrelaunchAccess()'));
      expect(
        appChrome,
        contains(
          '_temporaryDeveloperAccessGranted || hasPublicPrelaunchAccess()',
        ),
      );
    });

    test('masque tous les liens publics sauf accueil, mentions légales et CGU',
        () {
      expect(
        publicRouteSeo,
        contains(
          '.prelaunch-public-links a:not([href="/"]):not([href="/mentions-legales"]):not([href="/cgu"]){display:none!important}',
        ),
      );
      expect(
        publicRouteSeo,
        contains('<a href="/mentions-legales">Mentions légales</a>'),
      );
      expect(publicRouteSeo, contains('<a href="/cgu">CGU</a>'));
      expect(
        publicRouteSeo,
        isNot(contains("'/confidentialite': {")),
      );
      expect(
        publicRouteSeo,
        isNot(contains("'/suppression-compte': {")),
      );
    });
  });
}
