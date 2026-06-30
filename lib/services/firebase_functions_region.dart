import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import 'admin_web_debug_store.dart';

const kFirebaseFunctionsRegion = 'europe-west1';

FirebaseFunctions get prestoFirebaseFunctions =>
    FirebaseFunctions.instanceFor(region: kFirebaseFunctionsRegion);

Future<HttpsCallableResult<T>> callPrestoFunction<T>({
  required FirebaseFunctions functions,
  required String name,
  required Duration timeout,
  Object? parameters,
  String area = 'functions',
}) async {
  final startedAt = DateTime.now();
  final payloadSummary = _summarizeCallableData(parameters);
  AdminWebDebugStore.instance.recordEvent(
    area: area,
    message: name,
    detail: 'status=start timeoutMs=${timeout.inMilliseconds}'
        '${payloadSummary == null ? '' : ' payload=$payloadSummary'}',
    isCallable: true,
  );

  try {
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: timeout),
        )
        .call<T>(parameters);
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    final resultSummary = _summarizeCallableData(result.data);
    AdminWebDebugStore.instance.recordEvent(
      area: area,
      level: 'success',
      message: name,
      detail: 'status=success durationMs=$durationMs'
          '${resultSummary == null ? '' : ' result=$resultSummary'}',
      isCallable: true,
    );
    return result;
  } on FirebaseFunctionsException catch (error, stackTrace) {
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    AdminWebDebugStore.instance.recordError(
      area,
      error,
      stackTrace: stackTrace,
      message: name,
      isCallable: true,
    );
    AdminWebDebugStore.instance.recordEvent(
      area: area,
      level: 'warn',
      message: '$name failure-meta',
      detail: 'durationMs=$durationMs code=${error.code}'
          '${payloadSummary == null ? '' : ' payload=$payloadSummary'}',
      isCallable: true,
    );
    rethrow;
  } catch (error, stackTrace) {
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    AdminWebDebugStore.instance.recordError(
      area,
      error,
      stackTrace: stackTrace,
      message: name,
      isCallable: true,
    );
    AdminWebDebugStore.instance.recordEvent(
      area: area,
      level: 'warn',
      message: '$name failure-meta',
      detail: 'durationMs=$durationMs'
          '${payloadSummary == null ? '' : ' payload=$payloadSummary'}',
      isCallable: true,
    );
    rethrow;
  }
}

String? _summarizeCallableData(Object? value) {
  if (value == null) {
    return null;
  }
  final normalized = _normalizeCallableData(value);
  final encoded = jsonEncode(normalized);
  if (encoded.length <= 220) {
    return encoded;
  }
  return '${encoded.substring(0, 217)}...';
}

Object? _normalizeCallableData(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return 'String(len=${value.length})';
  }
  if (value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries.take(8)) {
      result[entry.key.toString()] = _normalizeCallableData(entry.value);
    }
    if (value.length > 8) {
      result['__truncatedKeys'] = value.length - 8;
    }
    return result;
  }
  if (value is List) {
    return <Object?>[
      'List(len=${value.length})',
      ...value.take(4).map(_normalizeCallableData),
      if (value.length > 4) '...(+${value.length - 4})',
    ];
  }
  return value.runtimeType.toString();
}
