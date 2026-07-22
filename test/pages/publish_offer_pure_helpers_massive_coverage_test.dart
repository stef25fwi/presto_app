import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/micro_ia_service.dart';
import 'package:presto_app/pages/publish_offer_page.dart';
import 'package:presto_app/services/geo_api_gouv_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUpAll(() async {
    setupFirebaseCoreMocks();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async => null);
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  dynamic createState() => const PublishOfferPage().createState();

  test('traduit toutes les familles d erreurs du parcours vocal', () {
    final state = createState();

    expect(
      state.formatMicroIaRuntimeError(
        const MicroIaClientAuthException(
          code: 'unauthenticated',
          message: 'Session requise.',
        ),
      ),
      'Session requise.',
    );

    final functionCases = <FirebaseFunctionsException, String>{
      FirebaseFunctionsException(code: 'unauthenticated', message: ''):
          'Connecte-toi pour utiliser la dictée.',
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: '',
      ): 'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.',
      FirebaseFunctionsException(
        code: 'not-found',
        message: '',
      ): 'Service vocal temporairement indisponible. Réessaie dans quelques instants.',
      FirebaseFunctionsException(code: 'unavailable', message: ''):
          'Serveur vocal occupé. Réessaie dans quelques secondes.',
      FirebaseFunctionsException(code: 'deadline-exceeded', message: ''):
          'Serveur vocal occupé. Réessaie dans quelques secondes.',
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Audio file is empty.',
      ): 'Le micro n\'a capté aucun son exploitable. Réessaie en parlant plus près du micro.',
      FirebaseFunctionsException(code: 'custom-code', message: ''):
          'custom-code',
    };
    for (final entry in functionCases.entries) {
      expect(
        state.formatMicroIaRuntimeError(entry.key),
        entry.value,
        reason: entry.key.code,
      );
    }

    final firebaseCases = <FirebaseException, String>{
      FirebaseException(
        plugin: 'storage',
        code: 'network-error',
      ): "Erreur réseau lors de l'envoi de l'audio. Vérifie ta connexion puis réessaie.",
      FirebaseException(
        plugin: 'storage',
        code: 'retry-limit-exceeded',
      ): "Erreur réseau lors de l'envoi de l'audio. Vérifie ta connexion puis réessaie.",
      FirebaseException(
        plugin: 'storage',
        code: 'unknown',
      ): "Erreur réseau lors de l'envoi de l'audio. Vérifie ta connexion puis réessaie.",
      FirebaseException(plugin: 'storage', code: 'unauthorized'):
          'Accès au stockage refusé. Recharge la page puis réessaie.',
      FirebaseException(plugin: 'storage', code: 'permission-denied'):
          'Accès au stockage refusé. Recharge la page puis réessaie.',
      FirebaseException(plugin: 'storage', code: 'object-not-found'):
          'Erreur de stockage (object-not-found). Réessaie.',
    };
    for (final entry in firebaseCases.entries) {
      expect(
        state.formatMicroIaRuntimeError(entry.key),
        entry.value,
        reason: entry.key.code,
      );
    }

    final genericCases = <Object, String>{
      StateError('recorder not started'):
          'Le micro a été interrompu. Réessaie.',
      Exception(
        'unable to decode audio data',
      ): "Le navigateur n'a pas pu lire l'audio. Réessaie ou recharge la page.",
      Exception(
        'unknown content type',
      ): "Le navigateur n'a pas pu lire l'audio. Réessaie ou recharge la page.",
      Exception(
        'format not supported',
      ): "Le navigateur n'a pas pu lire l'audio. Réessaie ou recharge la page.",
      Exception('network fetch failed'):
          'Problème de connexion réseau. Vérifie ta connexion puis réessaie.',
      Exception('403 forbidden'):
          'Vérification de sécurité échouée. Recharge la page puis réessaie.',
      Exception('AppCheck rejected'):
          'Vérification de sécurité échouée. Recharge la page puis réessaie.',
      Exception('Aucun texte reconnu'): 'Veuillez ré-enregistrer votre audio.',
      Exception('transcription vide'): 'Veuillez ré-enregistrer votre audio.',
      Exception('erreur métier brute'): 'erreur métier brute',
    };
    for (final entry in genericCases.entries) {
      expect(
        state.formatMicroIaRuntimeError(entry.key),
        entry.value,
        reason: entry.key.toString(),
      );
    }
  });

  test('normalise les délais et détecte budget et urgence', () {
    final state = createState();

    final normalizedDelays = <String?, String?>{
      'immediat': 'Urgent',
      '24h': 'Dans la journée',
      'demain': 'Demain',
      '48h': 'Sous 48h',
      '7j': 'Cette semaine',
      'flexible': 'À convenir',
      'inconnu': null,
      null: null,
    };
    for (final entry in normalizedDelays.entries) {
      expect(state.normalizeDraftMissionDelay(entry.key), entry.value);
    }

    for (final transcript in <String>[
      'Budget prévu de 120 euros',
      'Le tarif reste ouvert',
      'Quel prix proposez-vous ?',
      'Le montant est à négocier',
    ]) {
      expect(state.transcriptMentionsBudget(transcript), isTrue);
    }
    expect(state.transcriptMentionsBudget('Aucun montant indiqué'), isFalse);

    for (final transcript in <String>[
      'C est urgent',
      'À faire aujourd hui',
      'Intervention demain',
      'Sous 48h',
      'Cette semaine',
      'Dès que possible',
      'Besoin immédiat',
    ]) {
      expect(state.transcriptMentionsUrgency(transcript), isTrue);
    }
    expect(
      state.transcriptMentionsUrgency('Quand vous serez disponible'),
      isFalse,
    );

    final extractedDelays = <String, String?>{
      'Intervention urgente': 'Urgent',
      "À faire aujourd'hui": 'Dans la journée',
      'Rendez-vous demain': 'Demain',
      'À terminer sous 48h': 'Sous 48h',
      'Dans la semaine': 'Cette semaine',
      'Je suis flexible': 'À convenir',
      'Aucune date précisée': null,
    };
    for (final entry in extractedDelays.entries) {
      expect(state.extractMissionDelayFromTranscript(entry.key), entry.value);
    }

    for (final transcript in <String>[
      'Prix à négocier',
      'Tarif a discuter',
      'prix flexible',
      'budget flexible',
    ]) {
      expect(state.transcriptRequestsNegotiatedBudget(transcript), isTrue);
    }
    expect(
      state.transcriptRequestsNegotiatedBudget('Budget fixe de 50 euros'),
      isFalse,
    );

    expect(state.extractBudgetAmountFromTranscript('Budget 125 euros'), 125);
    expect(state.extractBudgetAmountFromTranscript('Prix 42,50 euros'), 42.5);
    expect(state.extractBudgetAmountFromTranscript('Budget 0 euros'), isNull);
    expect(state.extractBudgetAmountFromTranscript('Sans budget'), isNull);
  });

  test('filtre les détails redondants et construit une description riche', () {
    final state = createState();

    expect(
      state.normalizeDetailText('Réparation, très soignée !').trim(),
      'reparation  tres soignee',
    );
    expect(
      state.significantDetailWords(
        'Besoin de réparer rapidement la toiture dans la commune',
      ),
      containsAll(<String>['reparer', 'rapidement', 'toiture']),
    );

    expect(state.detailWordsMatch('reparer', 'reparer'), isTrue);
    expect(state.detailWordsMatch('reparation', 'reparer'), isTrue);
    expect(state.detailWordsMatch('peinture', 'peindre'), isFalse);
    expect(state.detailWordsMatch('toiture', 'jardin'), isFalse);

    final filtered =
        state.filterRedundantDetails(
              'Je recherche une personne pour réparer la toiture rouge.',
              <String>[
                'Réparer la toiture rouge',
                'Prévoir une échelle de dix mètres',
                'Échelle de dix mètres nécessaire',
                'merci',
              ],
            )
            as List<dynamic>;
    expect(filtered, <String>['Prévoir une échelle de dix mètres']);

    expect(
      state.buildRichDraftDescription(<String, dynamic>{
        'description_courte': 'Repeindre une chambre.',
        'details': <String>[
          'Repeindre une chambre',
          'Protéger les meubles avant travaux',
          '',
        ],
        'disponibilites': 'Samedi matin',
      }),
      'Repeindre une chambre.\n- Protéger les meubles avant travaux\nDisponibilités : Samedi matin',
    );
    expect(
      state.buildRichDraftDescription(<String, dynamic>{
        'description': 'Mission simple',
        'details': 'valeur non liste',
      }),
      'Mission simple',
    );
    expect(state.buildRichDraftDescription(<String, dynamic>{}), isEmpty);

    expect(
      state.firstNonEmptyDraftValue(
        <String, dynamic>{'a': ' ', 'b': null, 'c': ' valeur '},
        <String>['a', 'b', 'c'],
      ),
      'valeur',
    );
    expect(
      state.firstNonEmptyDraftValue(
        <String, dynamic>{'a': ''},
        <String>['a', 'b'],
      ),
      isEmpty,
    );
  });

  test('normalise catégories, codes postaux et indices géographiques DROM', () {
    final state = createState();

    expect(state.extractPostalCodeFromTranscript('Mission au 97122'), '97122');
    expect(state.extractPostalCodeFromTranscript('Mission au 75001'), '75001');
    expect(state.extractPostalCodeFromTranscript('Pas de code postal'), isNull);

    expect(state.resolvePublishCategoryLabel('Bricolage'), isNotNull);
    expect(state.resolvePublishCategoryLabel(''), isNull);
    expect(
      state.resolvePublishCategoryLabel('catégorie totalement inconnue'),
      isNull,
    );

    expect(
      state.normalizeAiGeoHint('Département de la Guadeloupe'),
      'departementdelaguadeloupe',
    );
    expect(state.normalizeAiGeoHint(' Région 01 '), 'region01');

    const guadeloupe = GeoApiGouvCommune(
      name: 'Baie-Mahault',
      postalCodes: <String>['97122'],
      departmentCode: '971',
      regionCode: '01',
    );
    expect(
      state.geoCommuneMatchesAiHint(
        guadeloupe,
        departmentHint: '',
        regionHint: '',
        locationHint: '',
      ),
      isTrue,
    );
    expect(
      state.geoCommuneMatchesAiHint(
        guadeloupe,
        departmentHint: 'Guadeloupe',
        regionHint: '',
        locationHint: '',
      ),
      isTrue,
    );
    expect(
      state.geoCommuneMatchesAiHint(
        guadeloupe,
        departmentHint: '',
        regionHint: '01',
        locationHint: '',
      ),
      isTrue,
    );
    expect(
      state.geoCommuneMatchesAiHint(
        guadeloupe,
        departmentHint: '',
        regionHint: '',
        locationHint: 'Gwada',
      ),
      isTrue,
    );
    expect(
      state.geoCommuneMatchesAiHint(
        guadeloupe,
        departmentHint: 'Martinique',
        regionHint: '02',
        locationHint: '',
      ),
      isFalse,
    );
  });

  test('valide les téléphones, budgets, titres et descriptions', () {
    final state = createState();

    final phoneCases = <String, bool>{
      '': false,
      '   ': false,
      '+590690123456': true,
      '+33 612345678': true,
      '+33ABC': false,
      '690123456': true,
      '12345': false,
      '1234567890123456': false,
    };
    for (final entry in phoneCases.entries) {
      expect(state.isValidPhoneFR(entry.key), entry.value);
    }

    expect(
      state.firstNonEmptyPublishPhone(
        <String, dynamic>{'phone': ' ', 'phoneNumber': ' 0690123456 '},
        <String>['phone', 'phoneNumber'],
      ),
      '0690123456',
    );
    expect(
      state.firstNonEmptyPublishPhone(
        null,
        <String>['phone'],
        fallbackValues: <String>[' ', '+596696123456'],
      ),
      '+596696123456',
    );
    expect(
      state.firstNonEmptyPublishPhone(<String, dynamic>{}, <String>['phone']),
      isEmpty,
    );

    expect(state.parseBudget(' 1 250,50 '), 1250.5);
    expect(state.parseBudget('invalide'), isNull);

    expect(state.validatePublishTitle(null), 'Merci de saisir un titre');
    expect(
      state.validatePublishTitle('Court'),
      'Le titre doit contenir au moins 10 caractères',
    );
    expect(
      state.validatePublishTitle('x' * 121),
      'Le titre doit contenir au maximum 120 caractères',
    );
    expect(state.validatePublishTitle('Titre de mission valide'), isNull);

    expect(
      state.validatePublishDescription(''),
      'Merci de décrire votre besoin',
    );
    expect(
      state.validatePublishDescription('Description courte'),
      'La description doit contenir au moins 30 caractères',
    );
    expect(
      state.validatePublishDescription('x' * 4001),
      'La description doit contenir au maximum 4000 caractères',
    );
    expect(
      state.validatePublishDescription(
        'Description suffisamment détaillée pour publier la mission.',
      ),
      isNull,
    );
  });

  test('traduit la matrice complète des erreurs de publication', () {
    final state = createState();
    final cases = <String, String>{
      'Title must contain at least 10 characters':
          'Le titre doit contenir au moins 10 caractères.',
      'Title must contain at most 120 characters':
          'Le titre doit contenir au maximum 120 caractères.',
      'Description must contain at least 30 characters':
          'La description doit contenir au moins 30 caractères.',
      'Description must contain at most 4000 characters':
          'La description doit contenir au maximum 4000 caractères.',
      'Price must be a positive number':
          'Le budget doit être supérieur ou égal à 0.',
      'categoryId is required': 'Choisissez une catégorie valide.',
      'Category is invalid or inactive':
          "La catégorie sélectionnée n'est plus disponible. Choisissez une autre catégorie.",
      'category is invalid or inactive':
          "La catégorie sélectionnée n'est plus disponible. Choisissez une autre catégorie.",
      'cityId is required': 'Choisissez une ville valide.',
      'City is invalid or inactive':
          "La ville sélectionnée n'est plus disponible. Choisissez une ville valide dans la liste.",
      'city is invalid or inactive':
          "La ville sélectionnée n'est plus disponible. Choisissez une ville valide dans la liste.",
      'reCAPTCHA assessment rejected the listing submission':
          'La vérification anti-abus a échoué. Réessaie dans quelques secondes.',
      'Authentication required.': 'Connecte-toi pour utiliser la dictée.',
      'unauthenticated': 'Connecte-toi pour utiliser la dictée.',
      'storagePath does not belong to authenticated user.':
          'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.',
      'permission-denied':
          'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.',
      'Audio file is empty.':
          'Le micro n\'a capté aucun son exploitable. Réessaie en parlant plus près du micro.',
      'Audio trop court/faible: 2 octets':
          'L\'audio est trop court pour être transcrit. Parle un peu plus longtemps puis réessaie.',
      'Type audio invalide: text/plain':
          'Le format audio envoyé au serveur est invalide. Recharge la page puis réessaie.',
      'Too many listing submissions, please retry later':
          'Trop de tentatives de publication en peu de temps. Réessaie plus tard.',
      'Draft not found':
          'Le brouillon de publication est introuvable. Relance la publication.',
      'You do not own this draft':
          'Ce brouillon ne correspond pas à ton compte connecté.',
      'Photo #2 must be processed as WebP before submission':
          'La photo 2 doit être retraitée avant publication. Réessayez.',
      'Draft payload is invalid': 'Le formulaire de publication est invalide.',
      'message libre': 'message libre',
    };

    for (final entry in cases.entries) {
      expect(
        state.translatePublishIssue(entry.key),
        entry.value,
        reason: entry.key,
      );
    }

    expect(
      state.formatPublishError(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'fallback',
          details: <String, dynamic>{
            'issues': <String>[
              'categoryId is required',
              '',
              'cityId is required',
            ],
          },
        ),
      ),
      'Choisissez une catégorie valide. Choisissez une ville valide.',
    );
    expect(
      state.formatPublishError(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Draft payload is invalid',
        ),
      ),
      'Le formulaire de publication est invalide.',
    );
    expect(
      state.formatPublishError(StateError('erreur locale')),
      'Bad state: erreur locale',
    );
  });

  test('retourne les libellés, indicatifs et formats photo', () {
    final state = createState();

    final labels = <String, String>{
      'title': 'titre',
      'category': 'catégorie',
      'description': 'description',
      'city': 'ville',
      'phone': 'téléphone',
      'delay': 'délai',
      'budget': 'budget',
      'custom': 'custom',
    };
    for (final entry in labels.entries) {
      expect(state.publishFieldLabel(entry.key), entry.value);
    }

    final countryCodes = <String, String>{
      '971': '+590',
      '972': '+596',
      '973': '+594',
      '974': '+262',
      '976': '+262',
      '987': '+689',
      '75': '+33',
    };
    for (final entry in countryCodes.entries) {
      expect(state.countryCodeForDept(entry.key), entry.value);
    }

    final photos = <XFile, List<String>>{
      XFile('/tmp/a.bin', mimeType: 'image/webp'): <String>[
        'webp',
        'image/webp',
      ],
      XFile('/tmp/a.bin', mimeType: 'image/png'): <String>['png', 'image/png'],
      XFile('/tmp/a.bin', mimeType: 'image/heif'): <String>[
        'heic',
        'image/heif',
      ],
      XFile('/tmp/a.bin', mimeType: 'image/gif'): <String>['gif', 'image/gif'],
      XFile('/tmp/photo.webp'): <String>['webp', 'image/webp'],
      XFile('/tmp/photo.png'): <String>['png', 'image/png'],
      XFile('/tmp/photo.heic'): <String>['heic', 'image/heic'],
      XFile('/tmp/photo.heif'): <String>['heic', 'image/heic'],
      XFile('/tmp/photo.gif'): <String>['gif', 'image/gif'],
      XFile('/tmp/photo.jpeg'): <String>['jpg', 'image/jpeg'],
    };
    for (final entry in photos.entries) {
      expect(state.storageExtFromPhoto(entry.key), entry.value[0]);
      expect(state.storageContentTypeFromPhoto(entry.key), entry.value[1]);
    }

    expect(state.publishAiDebugValue(null), '-');
    expect(state.publishAiDebugValue(true), 'yes');
    expect(state.publishAiDebugValue(false), 'no');
    expect(state.publishAiDebugValue('   '), '-');
    expect(state.publishAiDebugValue(12), '12');

    expect(state.adminAudioModeLabel('GOOGLE_ONLY'), 'Google STT');
    expect(state.adminAudioModeLabel('whisper_only'), 'Whisper');
    expect(state.adminAudioModeLabel('HYBRID'), 'Hybride');
    expect(state.adminAudioModeLabel('unknown'), 'Hybride');
  });
}
