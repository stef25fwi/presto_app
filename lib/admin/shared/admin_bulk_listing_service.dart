import 'package:cloud_functions/cloud_functions.dart';

import '../../core/observability/correlation_id.dart';
import '../../services/firebase_functions_region.dart';
import 'admin_bulk_deletion_policy.dart';

typedef AdminBulkListingCaller = Future<Object?> Function(
    Map<String, Object?> payload);

class AdminBulkListingDeleteItemResult {
  const AdminBulkListingDeleteItemResult({
    required this.listingId,
    required this.ok,
    this.errorCode,
    this.errorMessage,
  });

  final String listingId;
  final bool ok;
  final String? errorCode;
  final String? errorMessage;

  factory AdminBulkListingDeleteItemResult.fromData(Object? data) {
    if (data is! Map) {
      throw const FormatException('Résultat de suppression invalide.');
    }
    final map = data.map((key, value) => MapEntry(key.toString(), value));
    final listingId = (map['listingId'] ?? '').toString().trim();
    if (listingId.isEmpty || map['ok'] is! bool) {
      throw const FormatException('Résultat de suppression incomplet.');
    }
    final errorCode = (map['errorCode'] ?? '').toString().trim();
    final errorMessage = (map['errorMessage'] ?? '').toString().trim();
    return AdminBulkListingDeleteItemResult(
      listingId: listingId,
      ok: map['ok'] as bool,
      errorCode: errorCode.isEmpty ? null : errorCode,
      errorMessage: errorMessage.isEmpty ? null : errorMessage,
    );
  }
}

class AdminBulkListingDeleteSummary {
  const AdminBulkListingDeleteSummary({
    required this.ok,
    required this.adminActionId,
    required this.requestedCount,
    required this.succeededCount,
    required this.failedCount,
    required this.results,
    this.correlationId = '',
  });

  final bool ok;
  final String correlationId;
  final String adminActionId;
  final int requestedCount;
  final int succeededCount;
  final int failedCount;
  final List<AdminBulkListingDeleteItemResult> results;

  factory AdminBulkListingDeleteSummary.fromData(Object? data) {
    if (data is! Map) {
      throw const FormatException('Réponse de suppression invalide.');
    }
    final map = data.map((key, value) => MapEntry(key.toString(), value));
    final rawResults = map['results'];
    if (rawResults is! List) {
      throw const FormatException('Liste des résultats absente.');
    }
    final results = rawResults
        .map(AdminBulkListingDeleteItemResult.fromData)
        .toList(growable: false);
    final succeededCount = _readInt(map['succeededCount']) ??
        results.where((result) => result.ok).length;
    final failedCount = _readInt(map['failedCount']) ??
        results.where((result) => !result.ok).length;
    final requestedCount = _readInt(map['requestedCount']) ?? results.length;
    if (requestedCount != results.length ||
        succeededCount + failedCount != requestedCount) {
      throw const FormatException('Compteurs de suppression incohérents.');
    }
    return AdminBulkListingDeleteSummary(
      ok: map['ok'] == true,
      correlationId: (map['correlationId'] ?? '').toString().trim(),
      adminActionId: (map['adminActionId'] ?? '').toString().trim(),
      requestedCount: requestedCount,
      succeededCount: succeededCount,
      failedCount: failedCount,
      results: List<AdminBulkListingDeleteItemResult>.unmodifiable(results),
    );
  }

  List<String> get succeededIds => results
      .where((result) => result.ok)
      .map((result) => result.listingId)
      .toList(growable: false);

  List<AdminBulkListingDeleteItemResult> get failures =>
      results.where((result) => !result.ok).toList(growable: false);
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString());
}

class AdminBulkListingService {
  AdminBulkListingService({
    AdminBulkListingCaller? caller,
    FirebaseFunctions? functions,
    AdminBulkDeletionPolicy policy = const AdminBulkDeletionPolicy(
      maxBatchSize: 50,
    ),
  })  : _caller = caller ??
            ((payload) => _callFirebase(payload, functions: functions)),
        _policy = policy;

  static const int maxListingIds = 50;

  final AdminBulkListingCaller _caller;
  final AdminBulkDeletionPolicy _policy;

  Future<AdminBulkListingDeleteSummary> deleteListings({
    required Iterable<String> listingIds,
    required String reason,
    String? correlationId,
  }) async {
    final normalizedIds = _policy.normalizeIds(listingIds);
    if (normalizedIds.isEmpty) {
      throw ArgumentError.value(
        listingIds,
        'listingIds',
        'Sélectionnez au moins une annonce.',
      );
    }
    if (normalizedIds.length > maxListingIds) {
      throw ArgumentError.value(
        normalizedIds.length,
        'listingIds',
        'La suppression est limitée à 50 annonces par opération.',
      );
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Le motif de suppression est obligatoire.',
      );
    }

    final data = await _caller(<String, Object?>{
      'listingIds': normalizedIds,
      'reason': normalizedReason,
      'correlationId': resolveCorrelationId(correlationId),
    });
    return AdminBulkListingDeleteSummary.fromData(data);
  }

  static Future<Object?> _callFirebase(
    Map<String, Object?> payload, {
    FirebaseFunctions? functions,
  }) async {
    final HttpsCallableResult<dynamic> result =
        await callPrestoFunction<dynamic>(
      functions: functions ?? prestoFirebaseFunctions,
      name: 'adminBulkDeleteListings',
      timeout: const Duration(minutes: 5),
      parameters: payload,
      area: 'admin-listings',
    );
    return result.data;
  }
}
