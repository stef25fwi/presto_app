import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/public_landing_config_service.dart';

class _FakePublicLandingRemoteConfigAdapter
    implements PublicLandingRemoteConfigAdapter {
  _FakePublicLandingRemoteConfigAdapter({
    this.enabled = true,
    this.badge = 'Ouverture imminente',
    this.title = 'Titre distant',
    this.description = 'Description distante',
    this.launchMessage = 'Message distant',
  });

  bool enabled;
  String badge;
  String title;
  String description;
  String launchMessage;

  Map<String, dynamic>? defaults;
  RemoteConfigSettings? settings;
  int fetchCount = 0;

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    this.defaults = defaults;
  }

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<bool> fetchAndActivate() async {
    fetchCount += 1;
    return true;
  }

  @override
  bool getBool(String key) {
    expect(key, PublicLandingConfigService.enabledKey);
    return enabled;
  }

  @override
  String getString(String key) {
    return switch (key) {
      PublicLandingConfigService.badgeKey => badge,
      PublicLandingConfigService.titleKey => title,
      PublicLandingConfigService.descriptionKey => description,
      PublicLandingConfigService.launchMessageKey => launchMessage,
      _ => '',
    };
  }
}

void main() {
  group('PublicLandingConfigService', () {
    test('publie le positionnement IA et 0 % de commission par défaut', () {
      expect(
        PublicLandingConfigService.defaultTitle,
        'La solution à tout moment pour tous vos besoins du quotidien',
      );
      expect(
        PublicLandingConfigService.defaultDescription,
        'Publiez une annonce assistée par IA à partir d’un texte ou de votre voix pour vos besoins du quotidien. iliprestō ne prélève aucune commission sur vos prestations et ne collecte ni ne gère les paiements entre utilisateurs. Vous échangez et convenez directement des conditions de la mission.',
      );
      expect(
        PublicLandingConfigService.defaultLaunchMessage,
        'Site national en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.',
      );
    });

    test('est actif par défaut uniquement sur le domaine public', () {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(),
      );

      expect(
        service.shouldShowFor(
          Uri.parse('https://ilipresto.fr/'),
          isWeb: true,
        ),
        isTrue,
      );
      expect(
        service.shouldShowFor(
          Uri.parse('https://preview-channel.web.app/'),
          isWeb: true,
        ),
        isFalse,
      );
      expect(
        service.shouldShowFor(
          Uri.parse('https://ilipresto.fr/'),
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('n’exempte que les mentions légales et les CGU', () {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(),
      );

      for (final path in <String>['/mentions-legales', '/cgu']) {
        expect(
          service.shouldShowFor(
            Uri.parse('https://ilipresto.fr$path'),
            isWeb: true,
          ),
          isFalse,
          reason: '$path doit rester accessible',
        );
      }

      for (final path in <String>[
        '/admin',
        '/admin/users',
        '/auth/callback',
        '/login',
        '/register',
        '/forgot-password',
        '/verify-email',
        '/reset-password-success',
        '/__/auth/handler',
        '/confidentialite',
        '/suppression-compte',
        '/offers/123',
      ]) {
        expect(
          service.shouldShowFor(
            Uri.parse('https://ilipresto.fr$path'),
            isWeb: true,
          ),
          isTrue,
          reason: '$path doit rester bloqué par la préouverture',
        );
      }
    });

    test('applique aussi le verrou aux routes dans le fragment URL', () {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(),
      );

      for (final uri in <String>[
        'https://ilipresto.fr/#/mentions-legales',
        'https://ilipresto.fr/#/cgu',
      ]) {
        expect(
          service.shouldShowFor(Uri.parse(uri), isWeb: true),
          isFalse,
          reason: '$uri doit rester accessible',
        );
      }

      for (final uri in <String>[
        'https://ilipresto.fr/#/admin',
        'https://ilipresto.fr/#/admin/users?tab=active',
        'https://ilipresto.fr/#/login',
        'https://ilipresto.fr/#register',
        'https://ilipresto.fr/#/offers/123',
      ]) {
        expect(
          service.shouldShowFor(Uri.parse(uri), isWeb: true),
          isTrue,
          reason: '$uri doit afficher la page publique',
        );
      }
    });

    test('charge le toggle et les textes depuis Remote Config', () async {
      final adapter = _FakePublicLandingRemoteConfigAdapter(enabled: false);
      final service = PublicLandingConfigService(adapter: adapter);

      await service.initialize();

      expect(service.initialized, isTrue);
      expect(service.enabled, isFalse);
      expect(service.badge, 'Ouverture imminente');
      expect(service.title, 'Titre distant');
      expect(service.description, 'Description distante');
      expect(service.launchMessage, 'Message distant');
      expect(adapter.fetchCount, 1);
      expect(
        adapter.defaults?[PublicLandingConfigService.enabledKey],
        PublicLandingConfigService.defaultEnabled,
      );
      expect(adapter.settings, isNotNull);
      expect(
        service.shouldShowFor(
          Uri.parse('https://ilipresto.fr/annonces/123'),
          isWeb: true,
        ),
        isFalse,
      );
    });

    test('actualise le toggle et les textes sans redéploiement', () async {
      final adapter = _FakePublicLandingRemoteConfigAdapter(enabled: true);
      final service = PublicLandingConfigService(adapter: adapter);

      await service.initialize();
      expect(service.enabled, isTrue);

      adapter
        ..enabled = false
        ..badge = 'Site ouvert'
        ..title = 'Bienvenue sur iliprestō'
        ..description = 'Le site est maintenant accessible.'
        ..launchMessage = 'Les inscriptions sont ouvertes.';

      await service.refresh();

      expect(adapter.fetchCount, 2);
      expect(service.enabled, isFalse);
      expect(service.badge, 'Site ouvert');
      expect(service.title, 'Bienvenue sur iliprestō');
      expect(service.description, 'Le site est maintenant accessible.');
      expect(service.launchMessage, 'Les inscriptions sont ouvertes.');
    });

    test('migre l’ancien positionnement instantané vers le nouveau texte',
        () async {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(
          title:
              'La solution instantanée pour trouver un service près de chez vous',
          description:
              'iliprestō est un site de petites annonces de services et micro-services du quotidien. Publiez votre besoin, indiquez votre prix ou votre budget et trouvez un particulier, un indépendant ou un professionnel disponible à l’instant près de chez vous. Les personnes disponibles peuvent vous contacter immédiatement, avec 0 % de commission.',
          launchMessage:
              'Plateforme nationale en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.',
        ),
      );

      await service.initialize();

      expect(service.title, PublicLandingConfigService.defaultTitle);
      expect(
        service.description,
        PublicLandingConfigService.defaultDescription,
      );
      expect(
        service.launchMessage,
        PublicLandingConfigService.defaultLaunchMessage,
      );
    });

    test('migre aussi les valeurs historiques Remote Config', () async {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(
          title:
              'Trouvez rapidement un particulier ou un professionnel près de chez vous',
          description:
              'iliprestō met en relation particuliers, indépendants et professionnels pour répondre rapidement à vos besoins en services et microservices du quotidien, avec des annonces assistées par IA et 0 % de commission.',
          launchMessage:
              'Ouverture prochaine en Guadeloupe, Martinique et Guyane.',
        ),
      );

      await service.initialize();

      expect(service.title, PublicLandingConfigService.defaultTitle);
      expect(
        service.description,
        PublicLandingConfigService.defaultDescription,
      );
      expect(
        service.launchMessage,
        PublicLandingConfigService.defaultLaunchMessage,
      );
    });

    test('remplace les valeurs distantes vides par les textes par défaut',
        () async {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(
          badge: ' ',
          title: '',
          description: '\n',
          launchMessage: '',
        ),
      );

      await service.initialize();

      expect(service.badge, PublicLandingConfigService.defaultBadge);
      expect(service.title, PublicLandingConfigService.defaultTitle);
      expect(
        service.description,
        PublicLandingConfigService.defaultDescription,
      );
      expect(
        service.launchMessage,
        PublicLandingConfigService.defaultLaunchMessage,
      );
    });
  });
}
