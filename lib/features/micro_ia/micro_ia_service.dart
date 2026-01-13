import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class MicroIaService {
  static Future<Map<String, dynamic>> processAudio({
    required String storagePath,
    String languageCode = 'fr-FR',
    bool streamingMode = false, // ✅ Nouveau paramètre
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'microIaProcessAudio',
        options: HttpsCallableOptions(
          timeout: streamingMode
              ? const Duration(seconds: 10) // ✅ Timeout plus court en streaming
              : const Duration(seconds: 60),
        ),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'storagePath': storagePath,
        'languageCode': languageCode,
        'streamingMode': streamingMode, // ✅ Passer le mode au backend
      });

      return result.data;
    } catch (e) {
      debugPrint('[MicroIA] Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
