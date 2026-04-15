import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeOfferDeletionReason(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll('\u2019', "'")
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôöō]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool isOfferJobDoneDeletionReason(String? reason) {
  final normalized = normalizeOfferDeletionReason(reason ?? '');
  final foundOnIliPresto =
      normalized.contains('trouve quelqu') && normalized.contains('ilipresto');
  final foundProvider =
      normalized.contains('deja trouve') && normalized.contains('prestataire');
  return foundOnIliPresto || foundProvider;
}

DateTime? offerDateTimeFromDynamic(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? offerJobDoneVisibleUntil(Map<String, dynamic> data) {
  return offerDateTimeFromDynamic(
    data['jobDoneOverlayVisibleUntil'] ??
        data['removeFromBrowseAt'] ??
        data['pendingScreenRemovalUntil'],
  );
}

bool isOfferArchivedLike(Map<String, dynamic> data) {
  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  if (status == 'archived' ||
      status == 'archivé' ||
      status == 'deleted' ||
      status == 'removed' ||
      status == 'sold') {
    return true;
  }

  return data['archivedAt'] != null || data['deletedAt'] != null;
}

bool isOfferJobDoneOverlayVisible(Map<String, dynamic> data) {
  final visibleUntil = offerJobDoneVisibleUntil(data);
  if (visibleUntil == null || !visibleUntil.isAfter(DateTime.now())) {
    return false;
  }

  final visibleFlag = data['jobDoneOverlayVisible'];
  if (visibleFlag is bool && !visibleFlag) {
    return false;
  }

  final reason =
      (data['deletedReason'] ?? data['archiveReason'] ?? '').toString().trim();
  return visibleFlag == true || isOfferJobDoneDeletionReason(reason);
}

bool isPublishedOfferData(Map<String, dynamic> data) {
  if (isOfferArchivedLike(data)) return false;

  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  final visibility = data['visibility'];

  // status == 'active' est suffisant (les offres legacy n'ont pas de visibility)
  if (status == 'active') return true;

  if (status == 'published') return true;

  final isPublished = data['isPublished'];
  if (isPublished is bool && isPublished) return true;

  // Flag legacy
  final isActive = data['isActive'];
  if (isActive is bool && isActive) return true;

  // visibility.isPublic map sans status explicite
  if (visibility is Map) {
    final isPublic = visibility['isPublic'];
    if (isPublic is bool && isPublic) return true;
  }

  return false;
}

String offerDetailsPublishedLabel(dynamic raw) {
  if (raw is Timestamp) {
    final publishedAt = raw.toDate();
    final diff = DateTime.now().difference(publishedAt);

    if (diff.inMinutes < 1) return 'Publiee a l\'instant';
    if (diff.inHours < 1) return 'Publiee il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Publiee il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Publiee il y a ${diff.inDays} j';
  }

  return 'Publication recente';
}

String extractOfferImageUrl(dynamic entry) {
  if (entry == null) return '';
  if (entry is Map) {
    for (final key in const [
      'downloadUrl',
      'thumbnailUrl',
      'imageUrl',
      'photoUrl',
      'url',
      'secureUrl',
      'src',
      'storagePath',
      'filePath',
      'path',
    ]) {
      final value = (entry[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
  return entry.toString().trim();
}
