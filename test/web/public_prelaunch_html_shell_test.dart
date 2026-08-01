import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web public prelaunch shell', () {
    late String html;
    late String bootstrap;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
      bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    });

    test('expose le contenu essentiel sans dépendre du rendu Flutter', () {
      expect(html, contains('id="prelaunch-seo-shell"'));
      expect(
        html,
        contains(
          'Trouvez rapidement un particulier ou un professionnel disponible près de chez vous',
        ),
      );
      expect(html, contains('Annonces assistées par IA'));
      expect(html, contains('0 % de commission'));
      expect(
        html,
        contains(
          'Ouverture prochaine en Guadeloupe, Martinique et Guyane.',
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
      expect(html, contains('"@type": "WebSite"'));
      expect(html, contains('"@type": "Organization"'));
    });

    test('retire la coquille après la première frame Flutter', () {
      expect(html, contains("window.addEventListener('flutter-first-frame'"));
      expect(html, contains('shell.remove();'));
    });

    test('prévoit un retrait de secours après le démarrage Flutter', () {
      expect(bootstrap, contains('removePrelaunchSeoShell'));
      expect(bootstrap, contains('onEntrypointLoaded'));
      expect(bootstrap, contains('await appRunner.runApp();'));
      expect(bootstrap, contains('window.requestAnimationFrame'));
      expect(
        bootstrap,
        contains("document.getElementById('prelaunch-seo-shell')"),
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
