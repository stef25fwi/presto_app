import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../micro_ia/micro_ia_service.dart';
import '../../services/firebase_functions_region.dart';
import '../../utils/crashlytics_context.dart';
import '../../utils/retry.dart';

typedef AiDraftSessionPreparer = Future<void> Function();
typedef AiDraftCallable = Future<Map<dynamic, dynamic>> Function(
  Map<String, dynamic> parameters,
);

class AiDraftService {
  AiDraftService({
    @visibleForTesting AiDraftSessionPreparer? sessionPreparer,
    @visibleForTesting AiDraftCallable? callable,
  })  : _sessionPreparer = sessionPreparer,
        _callable = callable;

  final AiDraftSessionPreparer? _sessionPreparer;
  final AiDraftCallable? _callable;

  FirebaseFunctions get _functions => prestoFirebaseFunctions;

  Future<void> _prepareAuthenticatedCallableSession() async {
    final override = _sessionPreparer;
    if (override != null) {
      await override();
      return;
    }
    await MicroIaService.prepareSecureCallableContext();
    await FirebaseAuth.instance.currentUser?.getIdToken(false);
  }

  Future<Map<dynamic, dynamic>> _callGenerateOfferDraft(
    Map<String, dynamic> parameters,
  ) async {
    final override = _callable;
    if (override != null) return override(parameters);
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'generateOfferDraft',
      timeout: const Duration(seconds: 45),
      parameters: parameters,
    );
    return result.data as Map<dynamic, dynamic>;
  }

  /// Génère un brouillon enrichi avec format JSON riche.
  ///
  /// Les retries sont volontairement limités aux erreurs de transport sûres :
  /// le backend gère désormais les retries OpenAI et l'idempotence.
  Future<Map<String, dynamic>> generateOfferDraftV2({
    required String text,
    String? city,
    String? category,
  }) async {
    final clientRequestId =
        'text_${DateTime.now().microsecondsSinceEpoch}_${text.hashCode}';
    try {
      await _prepareAuthenticatedCallableSession();
      final data = await retry(
        () => _callGenerateOfferDraft(<String, dynamic>{
          'hint': text,
          if (city != null) 'city': city,
          if (category != null) 'category': category,
          'clientRequestId': clientRequestId,
        }),
        maxAttempts: 2,
        retryIf: (e) {
          if (e is FirebaseFunctionsException) {
            return e.code == 'unavailable' ||
                e.code == 'deadline-exceeded';
          }
          return false;
        },
      );

      return {
        // Ancien format (compatibilité)
        'title': (data['title'] ?? '').toString(),
        'category':
            (data['category'] ?? data['categorie'] ?? data['catégorie'] ?? '')
                .toString(),
        'description': (data['description'] ?? '').toString(),
        'location': (data['city'] ??
                data['ville'] ??
                data['commune'] ??
                data['location'] ??
                '')
            .toString(),
        'postalCode': (data['postalCode'] ??
                data['codePostal'] ??
                data['code_postal'] ??
                data['postal_code'] ??
                data['cp'] ??
                '')
            .toString(),

        // Nouveau format riche
        'titre': (data['titre'] ?? '').toString(),
        'suggestions_titres': _toStringList(data['suggestions_titres'] ?? []),
        'description_courte': (data['description_courte'] ?? '').toString(),
        'categorie': (data['categorie'] ?? '').toString(),
        'sous_categorie': (data['sous_categorie'] ?? '').toString(),
        'ville': (data['ville'] ?? '').toString(),
        'secteur': (data['secteur'] ?? '').toString(),
        'budget': _toBudgetMap(data['budget']),
        'urgence': (data['urgence'] ?? '').toString(),
        'details': _toStringList(data['details'] ?? []),
        'competences_requises':
            _toStringList(data['competences_requises'] ?? []),
        'materiel': _toMaterielMap(data['materiel']),
        'disponibilites': (data['disponibilites'] ?? '').toString(),
        'questions_a_poser': _toStringList(data['questions_a_poser'] ?? []),

        'success': true,
      };
    } on FirebaseFunctionsException catch (e, st) {
      await CrashlyticsContext.recordError(
        e,
        st,
        reason: 'generateOfferDraftV2 failed',
        fatal: false,
        keys: {
          'component': 'AiDraftService',
          'function': 'generateOfferDraft',
          'code': e.code,
        },
      );
      return {
        'success': false,
        'error': _friendlyFirebaseError(e),
        'code': e.code,
      };
    } catch (e, st) {
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'generateOfferDraftV2 failed (unknown)',
        fatal: false,
        keys: {
          'component': 'AiDraftService',
          'function': 'generateOfferDraft',
        },
      );
      return {
        'success': false,
        'error': 'Le brouillon automatique est indisponible. Réessaie dans un instant.',
      };
    }
  }

  String _friendlyFirebaseError(FirebaseFunctionsException error) {
    final providerCode = (error.message ?? '').trim();
    switch (providerCode) {
      case 'AI_TIMEOUT':
        return 'Le service IA met trop de temps à répondre. Réessaie dans un instant.';
      case 'AI_RATE_LIMITED':
        return 'Trop de demandes successives. Attends quelques secondes puis réessaie.';
      case 'AI_QUOTA_EXHAUSTED':
        return 'Le service IA est temporairement indisponible. Réessaie plus tard.';
      case 'AI_PROVIDER_UNAVAILABLE':
        return 'Le service IA est momentanément indisponible. Réessaie dans un instant.';
      case 'AI_OUTPUT_INVALID':
      case 'AI_OUTPUT_EMPTY':
      case 'AI_OUTPUT_INCOMPLETE':
        return 'Le texte a été compris, mais le brouillon n’a pas pu être structuré. Réessaie.';
      case 'AI_REFUSAL':
        return 'Le contenu ne peut pas être traité automatiquement. Reformule puis réessaie.';
      case 'AI_REQUEST_IN_PROGRESS':
        return 'La demande est encore en cours de traitement. Attends un instant.';
    }

    switch (error.code) {
      case 'deadline-exceeded':
        return 'Connexion lente avec le service IA. Réessaie.';
      case 'resource-exhausted':
        return 'Trop de demandes successives. Attends quelques secondes puis réessaie.';
      case 'unavailable':
        return 'Le service IA est momentanément indisponible. Réessaie dans un instant.';
      case 'unauthenticated':
        return 'Ta session a expiré. Reconnecte-toi puis réessaie.';
      default:
        return 'Le brouillon automatique est indisponible. Réessaie dans un instant.';
    }
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  Map<String, dynamic> _toBudgetMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _toMaterielMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
