import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web public prelaunch shell', () {
    late String html;
    late String bootstrap;
    late String webBridge;
    late String appChrome;
    late Map<String, dynamic> structuredData;
    late List<Map<String, dynamic>> structuredNodes;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
      bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
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
          'Trouvez rapidement un particulier, un indépendant ou un '
          'professionnel près de chez vous',
        ),
      );
      expect(html, contains('Annonces assistées par IA'));
      expect(html, contains('0 % de commission'));
      expect(
        html,
        contains(
          'Plateforme nationale en cours de déploiement. Première ouverture '
          'en Guadeloupe, Martinique et Guyane.',
        ),
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
      expect(
        html,
        contains(
          '<title>iliprestō – Trouvez un service près de chez vous</title>',
        ),
      );
      expect(
        html,
        contains(
          '<meta name="description" content="Trouvez rapidement un '
          'particulier, un indépendant ou un professionnel partout en France. '
          'Publiez une annonce assistée par IA et échangez directement, avec '
          '0 % de commission.">',
        ),
      );
      expect(
        html,
        isNot(
          contains('Ouverture prochaine en Guadeloupe, Martinique et Guyane.'),
        ),
      );
    });

    test('déclare un graphe JSON-LD national valide sans dépendre des espaces',
        () {
      expect(structuredData['@context'], 'https://schema.org');

      final types = structuredNodes.map((node) => node['@type']).toSet();
      expect(
        types,
        containsAll(<String>{'Organization', 'WebSite', 'WebPage', 'Service'}),
      );

      final organization = structuredNodes.firstWhere(
        (node) => node['@type'] == 'Organization',
      );
      expect(organization['@id'], 'https://ilipresto.fr/#organization');
      expect(organization['name'], 'iliprestō');
      expect(
        organization['areaServed'],
        equals(<String, dynamic>{'@type': 'Country', 'name': 'France'}),
      );

      final website = structuredNodes.firstWhere(
        (node) => node['@type'] == 'WebSite',
      );
      expect(website['@id'], 'https://ilipresto.fr/#website');
      expect(
        website['publisher'],
        equals(<String, dynamic>{
          '@id': 'https://ilipresto.fr/#organization',
        }),
      );

      final service = structuredNodes.firstWhere(
        (node) => node['@type'] == 'Service',
      );
      expect(
        service['provider'],
        equals(<String, dynamic>{
          '@id': 'https://ilipresto.fr/#organization',
        }),
      );
      expect(
        service['areaServed'],
        equals(<String, dynamic>{'@type': 'Country', 'name': 'France'}),
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
      expect(bootstrap, contains('function startFlutterApplication()'));
      expect(bootstrap, contains('_flutter.loader.load({'));
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
      expect(bootstrap, contains('tapCount = 0;'));
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

    test('maintient une seule page visible pendant le chargement après les taps',
        () {
      expect(bootstrap, contains('createPrelaunchTransitionShell(shell)'));
      expect(
        bootstrap,
        contains(
          "prelaunchTransitionShell.id = 'prelaunch-transition-shell'",
        ),
      );
      expect(
        bootstrap,
        contains("prelaunchTransitionShell.style.pointerEvents = 'none'"),
      );
      expect(
        bootstrap,
        contains("prelaunchTransitionShell.style.zIndex = '2147483646'"),
      );
      expect(bootstrap, contains("shell.style.visibility = 'hidden';"));
      expect(
        bootstrap,
        contains('window.iliprestoOpenApplication = function ()'),
      );
    });

    test('corrige les contrastes du shell avant toute mesure Lighthouse', () {
      expect(
        bootstrap,
        contains('.prelaunch-brand-name{color:#c64700!important}'),
      );
      expect(
        bootstrap,
        contains('.prelaunch-domain{color:#5f6b78!important}'),
      );
      expect(
        bootstrap.indexOf('applyPrelaunchAccessibilityFixes();'),
        lessThan(bootstrap.indexOf('const deferredPublicPrelaunch =')),
      );
    });

    test('préserve les routes administration et authentification', () {
      for (final path in <String>[
        '/admin',
        '/auth',
        '/login',
        '/register',
        '/forgot-password',
        '/verify-email',
        '/reset-password-success',
        '/__/auth',
      ]) {
        expect(html, contains("'$path'"), reason: '$path doit être exempté');
      }
      expect(html, contains('window.location.hash'));
    });
  });
}
