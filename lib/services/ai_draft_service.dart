import 'package:cloud_functions/cloud_functions.dart';

class AiDraftService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Génère un brouillon simple (compatible ancien format)
  Future<Map<String, dynamic>> generateOfferDraft({required String text}) async {
    try {
      final callable = _functions.httpsCallable('generateOfferDraft');
      final res = await callable.call<dynamic>(<String, dynamic>{
        'hint': text, // Cloud Function attend 'hint'
      });

      final data = (res.data as Map<dynamic, dynamic>);
      
      return {
        'title': (data['title'] ?? '').toString(),
        'category': (data['category'] ?? '').toString(),
        'description': (data['description'] ?? '').toString(),
        'location': (data['city'] ?? '').toString(), // Cloud Function retourne 'city'
        'postalCode': (data['postalCode'] ?? '').toString(),
        'success': true,
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Erreur lors de l\'appel à la fonction',
        'code': e.code,
      };
    } catch (e) {
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
      final callable = _functions.httpsCallable('generateOfferDraft');
      final res = await callable.call<dynamic>(<String, dynamic>{
        'hint': text,
        if (city != null) 'city': city,
        if (category != null) 'category': category,
      });

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
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Erreur lors de l\'appel à la fonction',
        'code': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Convertit une liste dynamique en List<String>
  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => (item ?? '').toString()).toList();
    }
    return [];
  }

  /// Convertit le budget en Map structuré
  Map<String, dynamic> _toBudgetMap(dynamic value) {
    if (value == null) {
      return {
        'type': null,
        'min': null,
        'max': null,
        'devise': 'EUR',
      };
    }
    if (value is Map) {
      return {
        'type': value['type']?.toString(),
        'min': value['min'] is num ? value['min'] : null,
        'max': value['max'] is num ? value['max'] : null,
        'devise': (value['devise'] ?? 'EUR').toString(),
      };
    }
    return {
      'type': null,
      'min': null,
      'max': null,
      'devise': 'EUR',
    };
  }

  /// Convertit le matériel en Map structuré
  Map<String, List<String>> _toMaterielMap(dynamic value) {
    if (value == null) {
      return {
        'fourni_par_demandeur': [],
        'a_prevoir_par_prestataire': [],
      };
    }
    if (value is Map) {
      return {
        'fourni_par_demandeur': _toStringList(value['fourni_par_demandeur']),
        'a_prevoir_par_prestataire': _toStringList(value['a_prevoir_par_prestataire']),
      };
    }
    return {
      'fourni_par_demandeur': [],
      'a_prevoir_par_prestataire': [],
    };
  }
}
