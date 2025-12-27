import 'package:cloud_functions/cloud_functions.dart';

class MicroIaService {
  MicroIaService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<Map<String, dynamic>> processAudio({
    required String storagePath,
    String? languageCode,
  }) async {
    final callable = _functions.httpsCallable('microIaProcessAudio');
    final res = await callable.call(<String, dynamic>{
      'storagePath': storagePath,
      if (languageCode != null) 'languageCode': languageCode,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
