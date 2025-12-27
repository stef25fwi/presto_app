import 'package:cloud_functions/cloud_functions.dart';

import '../../utils/crashlytics_context.dart';
import '../../utils/retry.dart';

class AiDraftService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Génère un brouillon simple (compatible ancien format)
  Future<Map<String, dynamic>> generateOfferDraft({required String text}) async {
    try {
      final callable = _functions.httpsCallable(
        'generateOfferDraft',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final res = await retry(
        () => callable.call<dynamic>(<String, dynamic>{
          'hint': text, // Cloud Function attend 'hint'
        }),
        maxAttempts: 3,
        retryIf: (e) {
          if (e is FirebaseFunctionsException) {
            return e.code == 'unavailable' ||
                e.code == 'deadline-exceeded' ||
                e.code == 'internal' ||
                e.code == 'resource-exhausted';
          }
          return false;
        },
      );

      final data = (res.data as Map<dynamic, dynamic>);

      return {
        'title': (data['title'] ?? '').toString(),
        'category': (data['category'] ?? '').toString(),
        'description': (data['description'] ?? '').toString(),
        'location': (data['city'] ?? '').toString(),
        'postalCode': (data['postalCode'] ?? '').toString(),
        'success': true,
      };
    } on FirebaseFunctionsException catch (e, st) {
      await CrashlyticsContext.recordError(
        e,
        st,
        reason: 'generateOfferDraft failed',
        fatal: false,
        keys: {
          'component': 'AiDraftService',
          'function': 'generateOfferDraft',
          'code': e.code,
        },
      );
      return {
        'success': false,
        'error': e.message ?? 'Erreur lors de l\'appel à la fonction',
        'code': e.code,
      };
    } catch (e, st) {
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'generateOfferDraft failed (unknown)',
        fatal: false,
        keys: {
          'component': 'AiDraftService',
          'function': 'generateOfferDraft',
        },
      );
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Génère un brouillon enrichi avec format JSON riche
  Future<Map<String, dynamic>> generateOfferDraftV2({
    required String text,
    String? city,
    String? category,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'generateOfferDraft',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final res = await retry(
        () => callable.call<dynamic>(<String, dynamic>{
          'hint': text,
          if (city != null) 'city': city,
          if (category != null) 'category': category,
        }),
        maxAttempts: 3,
        retryIf: (e) {
          if (e is FirebaseFunctionsException) {
            return e.code == 'unavailable' ||
                e.code == 'deadline-exceeded' ||
                e.code == 'internal' ||
                e.code == 'resource-exhausted';
          }
          return false;
        },
      );

      final data = (res.data as Map<dynamic, dynamic>);

      return {
        // Ancien format (compatibilité)
        'title': (data['title'] ?? '').toString(),
        'category': (data['category'] ?? '').toString(),
        'description': (data['description'] ?? '').toString(),
        'location': (data['city'] ?? '').toString(),
        'postalCode': (data['postalCode'] ?? '').toString(),

        // Nouveau format riche
        'titre': (data['titre'] ?? '').toString(),
        'suggestions_titres': _toStringList(data['suggestions_titres'] ?? []),
        'description_courte': (data['description_courte'] ?? '').toString(),
        'categorie': (data['categorie'] ?? '').toString(),
        'ville': (data['ville'] ?? '').toString(),
        'secteur': (data['secteur'] ?? '').toString(),
        'budget': _toBudgetMap(data['budget']),
        'urgence': (data['urgence'] ?? '').toString(),
        'details': _toStringList(data['details'] ?? []),
        'competences_requises': _toStringList(data['competences_requises'] ?? []),
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
        'error': e.message ?? 'Erreur lors de l\'appel à la fonction',
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
        'error': e.toString(),
      };
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
