import 'package:cloud_functions/cloud_functions.dart';

class AiDraftService {
    final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

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
}
