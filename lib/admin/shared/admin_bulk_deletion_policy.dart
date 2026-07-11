/// Règles pures utilisées avant une suppression administrative multiple.
///
/// La policy normalise la sélection, découpe les opérations en lots bornés et
/// produit un enregistrement d’audit indépendant de Firebase.
class AdminBulkDeletionPolicy {
  const AdminBulkDeletionPolicy({this.maxBatchSize = 200})
      : assert(maxBatchSize > 0);

  final int maxBatchSize;

  List<String> normalizeIds(Iterable<String> entityIds) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawId in entityIds) {
      final id = rawId.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      normalized.add(id);
    }
    return List<String>.unmodifiable(normalized);
  }

  List<List<String>> buildBatches(Iterable<String> entityIds) {
    final ids = normalizeIds(entityIds);
    final batches = <List<String>>[];
    for (var index = 0; index < ids.length; index += maxBatchSize) {
      final end = index + maxBatchSize < ids.length
          ? index + maxBatchSize
          : ids.length;
      batches.add(List<String>.unmodifiable(ids.sublist(index, end)));
    }
    return List<List<String>>.unmodifiable(batches);
  }

  bool isDeletedRecord(Map<String, Object?> record) {
    if (record['deletedAt'] != null) return true;
    final status = (record['status'] ?? '').toString().trim().toLowerCase();
    return status == 'deleted';
  }

  bool isActiveForStatistics(Map<String, Object?> record) {
    return !isDeletedRecord(record);
  }

  Map<String, Object?> buildAuditSnapshot({
    required String entityType,
    required String entityId,
    required String deletedBy,
    required DateTime deletedAt,
    String deletionReason = '',
    Map<String, Object?> snapshot = const <String, Object?>{},
  }) {
    final normalizedType = _requiredValue(entityType, 'entityType');
    final normalizedId = _requiredValue(entityId, 'entityId');
    final normalizedActor = _requiredValue(deletedBy, 'deletedBy');

    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'operation': 'delete',
      'status': 'deleted',
      'entityType': normalizedType,
      'entityId': normalizedId,
      'deletedBy': normalizedActor,
      'deletedAt': deletedAt.toUtc().toIso8601String(),
      'deletionReason': deletionReason.trim(),
      'snapshot': Map<String, Object?>.unmodifiable(snapshot),
    });
  }

  String _requiredValue(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, 'La valeur est obligatoire.');
    }
    return normalized;
  }
}
