import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../utils/crashlytics_context.dart';
import '../../utils/retry.dart';

class MicroIaService {
  MicroIaService._();

  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<Map<String, dynamic>> processAudio({
    required String storagePath,
    String? languageCode,
  }) async {
    final callable = _functions.httpsCallable(
      'microIaProcessAudio',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    try {
      final res = await retry(
        () => callable.call(<String, dynamic>{
          'storagePath': storagePath,
          if (languageCode != null) 'languageCode': languageCode,
        }),
        maxAttempts: 3,
        retryIf: (e) {
          if (e is TimeoutException) return true;
          if (e is FirebaseFunctionsException) {
            return e.code == 'unavailable' ||
                e.code == 'deadline-exceeded' ||
                e.code == 'internal' ||
                e.code == 'resource-exhausted';
          }
          return false;
        },
      );

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
