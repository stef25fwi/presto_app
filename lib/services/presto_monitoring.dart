import 'package:flutter/foundation.dart';

import 'admin_web_debug_store.dart';

/// Lightweight compatibility facade used by legacy screens while monitoring
/// responsibilities are progressively moved out of `main.dart`.
class PrestoMonitoring {
  PrestoMonitoring._();

  static final PrestoMonitoring I = PrestoMonitoring._();

  void trackOtherStream({required String key, required int docsCount}) {
    if (kDebugMode) {
      debugPrint('[monitoring] stream=$key count=$docsCount');
    }
    AdminWebDebugStore.instance.recordEvent(
      area: 'monitoring',
      message: 'stream',
      detail: 'key=$key count=$docsCount',
    );
  }

  void trackOffersSnapshot(int docsCount) {
    trackOtherStream(key: 'offers.snapshot', docsCount: docsCount);
  }

  void trackFunctionsCall({required String name, required int ms}) {
    if (kDebugMode) {
      debugPrint('[monitoring] function=$name ms=$ms');
    }
    AdminWebDebugStore.instance.recordEvent(
      area: 'monitoring',
      message: 'function',
      detail: 'name=$name ms=$ms',
    );
  }

  void trackError(String key, Object error) {
    if (kDebugMode) {
      debugPrint('[monitoring] error=$key $error');
    }
    AdminWebDebugStore.instance.recordError(
      'monitoring',
      error,
      message: key,
    );
  }
}
