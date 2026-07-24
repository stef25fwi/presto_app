import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'cache_monitoring_service.dart';

/// Service de cache pour les parcours de boîte à outils
///
/// Structure Firestore:
///   /toolbox_journeys/{journeyId}
///     - type_projet: string
///     - domaine: string
///     - region: string
///     - generatedAt: timestamp
///     - content: {parcours complet}
///
///   /toolbox_journey_index/{indexId}
///     - criteria_hash: string normalisé de "type_projet|domaine|region"
///     - journey_id: string
///     - createdAt: timestamp

class ToolboxCacheService {
  ToolboxCacheService({
    FirebaseFirestore? firestore,
    CacheMonitoringService? monitoring,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _monitoring = monitoring ?? CacheMonitoringService();

  final FirebaseFirestore _db;
  final CacheMonitoringService _monitoring;

  /// Génère une clé stable pour les critères saisis librement.
  String _normalizeCriteriaPart(String value) {
    var normalized = value.trim().toLowerCase();

    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
      '’': ' ',
      '\'': ' ',
      '-': ' ',
      '_': ' ',
      '/': ' ',
    };

    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  /// Format: "type_projet|domaine|region"
  String _generateCriteriaHash(
    String typeProjet,
    String domaine,
    String region,
  ) {
    final normalizedType = _normalizeCriteriaPart(typeProjet);
    final normalizedDomain = _normalizeCriteriaPart(domaine);
    final normalizedRegion = _normalizeCriteriaPart(region);
    return '$normalizedType|$normalizedDomain|$normalizedRegion';
  }

  /// Cherche un parcours existant pour les critères donnés
  /// Retourne le parcours (Map) ou null si pas trouvé
  Future<Map<String, dynamic>?> fetchExistingJourney({
    required String typeProjet,
    required String domaine,
    required String region,
  }) async {
    final startTime = DateTime.now();

    try {
      final criteriaHash = _generateCriteriaHash(typeProjet, domaine, region);

      // Chercher dans l'index
      final indexQuery = await _db
          .collection('toolbox_journey_index')
          .where('criteria_hash', isEqualTo: criteriaHash)
          .limit(1)
          .get();

      if (indexQuery.docs.isEmpty) {
        _monitoring.recordCacheMiss(DateTime.now().difference(startTime));
        return null; // Pas trouvé en cache
      }

      final indexDoc = indexQuery.docs.first;
      final journeyId = indexDoc['journey_id'] as String?;

      if (journeyId == null) {
        _monitoring.recordCacheMiss(DateTime.now().difference(startTime));
        return null;
      }

      // Récupérer le parcours complet
      final journeyDoc =
          await _db.collection('toolbox_journeys').doc(journeyId).get();

      if (journeyDoc.exists) {
        // ✅ Cache HIT
        final elapsed = DateTime.now().difference(startTime);
        _monitoring.recordCacheHit(elapsed);
        return journeyDoc.data();
      }

      _monitoring.recordCacheMiss(DateTime.now().difference(startTime));
      return null;
    } catch (e) {
      _monitoring.recordCacheError('fetchExistingJourney: $e');
      debugPrint('[ToolboxCache] fetch existing journey failed: $e');
      return null;
    }
  }

  /// Enregistrer un cache miss (parcours généré)
  void recordCacheMiss(Duration generationTime) {
    _monitoring.recordCacheMiss(generationTime);
  }

  /// Sauvegarde un nouveau parcours généré et met à jour l'index
  Future<String?> saveNewJourney({
    required String typeProjet,
    required String domaine,
    required String region,
    required Map<String, dynamic> journeyContent,
  }) async {
    try {
      final criteriaHash = _generateCriteriaHash(typeProjet, domaine, region);

      // 1. Créer le document du parcours
      final journeyRef = _db.collection('toolbox_journeys').doc();
      final journeyId = journeyRef.id;

      await journeyRef.set({
        'type_projet': typeProjet,
        'domaine': domaine,
        'region': region,
        'criteria_hash': criteriaHash,
        'generated_at': FieldValue.serverTimestamp(),
        'content': journeyContent,
      });

      // 2. Créer ou mettre à jour l'entrée d'index
      final existingIndex = await _db
          .collection('toolbox_journey_index')
          .where('criteria_hash', isEqualTo: criteriaHash)
          .limit(1)
          .get();
      final indexRef = existingIndex.docs.isNotEmpty
          ? existingIndex.docs.first.reference
          : _db.collection('toolbox_journey_index').doc();
      await indexRef.set({
        'criteria_hash': criteriaHash,
        'journey_id': journeyId,
        'created_at': FieldValue.serverTimestamp(),
      });

      return journeyId;
    } catch (e) {
      debugPrint('[ToolboxCache] save new journey failed: $e');
      return null;
    }
  }

  /// Supprime un parcours et l'index associé (optionnel, pour maintenance)
  Future<bool> deleteJourney({
    required String journeyId,
    required String criteriaHash,
  }) async {
    try {
      // Supprimer le document du parcours
      await _db.collection('toolbox_journeys').doc(journeyId).delete();

      // Supprimer l'entrée d'index
      final indexQuery = await _db
          .collection('toolbox_journey_index')
          .where('journey_id', isEqualTo: journeyId)
          .get();

      for (var doc in indexQuery.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      debugPrint('[ToolboxCache] delete journey failed: $e');
      return false;
    }
  }

  /// Stats du cache (nombre de parcours uniques)
  Future<int> getCacheStats() async {
    try {
      final snapshot = await _db.collection('toolbox_journeys').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[ToolboxCache] get cache stats failed: $e');
      return 0;
    }
  }
}
