import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_functions_region.dart';

/// Result returned by the [broadcastTestNotification] cloud function.
class BroadcastResult {
  const BroadcastResult({
    required this.userCount,
    required this.tokenCount,
    required this.successCount,
    required this.failureCount,
  });

  final int userCount;
  final int tokenCount;
  final int successCount;
  final int failureCount;

  factory BroadcastResult.fromMap(Map<String, dynamic> map) {
    int asInt(Object? value) =>
        value is int ? value : (value is num ? value.toInt() : 0);
    return BroadcastResult(
      userCount: asInt(map['userCount']),
      tokenCount: asInt(map['tokenCount']),
      successCount: asInt(map['successCount']),
      failureCount: asInt(map['failureCount']),
    );
  }
}

/// Sends admin broadcast notifications to every user with a registered device.
class AdminBroadcastService {
  AdminBroadcastService({FirebaseFunctions? functions})
      : _functions = functions ?? prestoFirebaseFunctions;

  final FirebaseFunctions _functions;

  /// Sends a test push notification to all users (admin only, enforced
  /// server-side). Returns delivery counts for display.
  Future<BroadcastResult> sendTestNotificationToAllUsers({
    String? title,
    String? body,
  }) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'broadcastTestNotification',
      timeout: const Duration(seconds: 120),
      parameters: <String, dynamic>{
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      },
      area: 'admin_broadcast',
    );

    final data = (result.data is Map)
        ? Map<String, dynamic>.from(result.data as Map)
        : <String, dynamic>{};
    return BroadcastResult.fromMap(data);
  }
}
