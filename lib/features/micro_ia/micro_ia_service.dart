import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../utils/crashlytics_context.dart';
import '../../utils/retry.dart';

class MicroIaService {
  MicroIaService._();

  static final _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Process audio and optionally generate a draft in a single round-trip.
  /// When [generateDraft] is true, the CF merges STT + OpenAI draft
  /// to eliminate one network round-trip (~1-2s saved).
  static Future<Map<String, dynamic>> processAudio({
    required String storagePath,
    String? languageCode,
    bool generateDraft = false,
    String? draftCity,
    String? draftCategory,
  }) async {
    final callable = _functions.httpsCallable(
      'microIaProcessAudio',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 75)),
    );

    try {
      final res = await retry(
        () => callable.call(<String, dynamic>{
          'storagePath': storagePath,
          if (languageCode != null) 'languageCode': languageCode,
          if (generateDraft) 'generateDraft': true,
          if (generateDraft && draftCity != null) 'draftCity': draftCity,
          if (generateDraft && draftCategory != null)
            'draftCategory': draftCategory,
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
          'generateDraft': generateDraft.toString(),
        },
      );
      rethrow;
    }
  }
}
