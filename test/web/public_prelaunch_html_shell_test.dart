import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web public prelaunch shell', () {
    late String html;
    late String bootstrap;
    late Map<String, dynamic> structuredData;
    late List<Map<String, dynamic>> structuredNodes;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
      bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

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
          'Trouvez rapidement un particulier, un indépendant ou un professionnel près de chez vous',
        ),
      );
      expect(html, contains('Annonces assistées par IA'));
      expect(html, contains('0 % de commission'));
      expect(
        html,
        contains(
          'Plateforme nationale en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.',
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
      expect(html, contains('<title>iliprestō – Trouvez un service près de chez vous</title>'));
      expect(
        html,
        contains(
          '<meta name="description" content="Trouvez rapidement un particulier, un indépendant ou un professionnel partout en France. Publiez une annonce assistée par IA et échangez directement, avec 0 % de commission.">',
        ),
      );
      expect(
        html,
        isNot(contains('Ouverture prochaine en Guadeloupe, Martinique et Guyane.')),
      );
    });

    test('déclare un graphe JSON-LD national valide sans dépendre des espaces', () {
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
      expect(website['publisher'], equals(<String, dynamic>{
        '@id': 'https://ilipresto.fr/#organization',
      }));

      final service = structuredNodes.firstWhere(
        (node) => node['@type'] == 'Service',
      );
      expect(service['provider'], equals(<String, dynamic>{
        '@id': 'https://ilipresto.fr/#organization',
      }));
      expect(
        service['areaServed'],
        equals(<String, dynamic>{'@type': 'Country', 'name': 'France'}),
      );
    });

    test('masque la coquille HTML sur la racine publique', () {
      expect(bootstrap, contains('useFlutterPrelaunchOnly'));
      expect(bootstrap, contains("shell.style.visibility = 'hidden';"));
      expect(bootstrap, contains("shell.style.pointerEvents = 'none';"));
      expect(bootstrap, contains("shell.setAttribute('aria-hidden', 'true')"));
      expect(
        bootstrap.indexOf('preparePrelaunchSeoShellForFlutter();'),
        lessThan(bootstrap.indexOf('_flutter.loader.load({')),
      );
      expect(bootstrap, isNot(contains('shellRemovalScheduled')));
      expect(bootstrap, isNot(contains('window.setTimeout(function ()')));
    });

    test('retire la coquille dès la première frame Flutter', () {
      expect(html, contains("window.addEventListener('flutter-first-frame'"));
      expect(html, contains('shell.remove();'));
      expect(bootstrap, contains("window.addEventListener('flutter-first-frame'"));
      expect(bootstrap, contains('removePrelaunchSeoShell'));
      expect(bootstrap, contains('window.requestAnimationFrame(removePrelaunchSeoShell);'));
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
