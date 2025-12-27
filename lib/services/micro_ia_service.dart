import 'package:cloud_functions/cloud_functions.dart';

import '../utils/crashlytics_context.dart';

class MicroIaService {
  MicroIaService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<Map<String, dynamic>> processAudio({
    required String storagePath,
    String? languageCode,
  }) async {
    final callable = _functions.httpsCallable('microIaProcessAudio');
    try {
      final res = await callable.call(<String, dynamic>{
        'storagePath': storagePath,
        if (languageCode != null) 'languageCode': languageCode,
      });
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e, st) {
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'microIaProcessAudio failed',
        fatal: false,
        keys: {
          'component': 'MicroIaService',
          'function': 'microIaProcessAudio',
          'storagePath': storagePath,
          'languageCode': languageCode ?? '',
        },
      );
      rethrow;
    }
  }
}
