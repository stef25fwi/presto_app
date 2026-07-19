import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';

typedef SubscriptionCreditCaller = Future<Map<String, dynamic>> Function(
  String name,
  Map<String, dynamic>? parameters,
);

enum SubscriptionCreditKind {
  journeys('journeys'),
  pdf('pdf'),
  voiceAi('voiceAi'),
  textAi('textAi'),
  activeOffers('activeOffers');

  const SubscriptionCreditKind(this.key);
  final String key;
}

class SubscriptionCreditStatus {
  final int used;
  final int limit;
  final int remaining;
  final bool unlimited;
  final bool exhausted;

  const SubscriptionCreditStatus({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.unlimited,
    required this.exhausted,
  });

  factory SubscriptionCreditStatus.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return SubscriptionCreditStatus(
      used: _int(map['used']),
      limit: _int(map['limit']),
      remaining: _int(map['remaining']),
      unlimited: map['unlimited'] == true,
      exhausted: map['exhausted'] == true,
    );
  }

  String get compactLabel {
    if (unlimited) return '∞';
    if (limit <= 0) return '0';
    return '$remaining/$limit';
  }
}

class SubscriptionCreditSnapshot {
  final String plan;
  final String period;
  final bool freeAccessMode;
  final DateTime? nextResetAt;
  final Map<SubscriptionCreditKind, SubscriptionCreditStatus> credits;

  const SubscriptionCreditSnapshot({
    required this.plan,
    required this.period,
    required this.freeAccessMode,
    required this.nextResetAt,
    required this.credits,
  });

  factory SubscriptionCreditSnapshot.fromMap(Map<String, dynamic> data) {
    final rawCredits = _map(data['credits']);
    return SubscriptionCreditSnapshot(
      plan: '${data['plan'] ?? 'free'}',
      period: '${data['period'] ?? ''}',
      freeAccessMode: data['freeAccessMode'] == true,
      nextResetAt: DateTime.tryParse('${data['nextResetAt'] ?? ''}'),
      credits: {
        for (final kind in SubscriptionCreditKind.values)
          kind: SubscriptionCreditStatus.fromMap(_map(rawCredits[kind.key])),
      },
    );
  }

  SubscriptionCreditStatus operator [](SubscriptionCreditKind kind) =>
      credits[kind] ??
      const SubscriptionCreditStatus(
        used: 0,
        limit: 0,
        remaining: 0,
        unlimited: false,
        exhausted: true,
      );
}

class SavedJourneyRecord {
  final String id;
  final String title;
  final String activity;
  final String currentStatus;
  final String region;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> snapshot;

  const SavedJourneyRecord({
    required this.id,
    required this.title,
    required this.activity,
    required this.currentStatus,
    required this.region,
    required this.createdAt,
    required this.updatedAt,
    required this.snapshot,
  });

  factory SavedJourneyRecord.fromMap(Map<String, dynamic> data) {
    return SavedJourneyRecord(
      id: '${data['id'] ?? ''}',
      title: '${data['title'] ?? ''}',
      activity: '${data['activity'] ?? ''}',
      currentStatus: '${data['currentStatus'] ?? ''}',
      region: '${data['region'] ?? ''}',
      createdAt: _dateFromMillis(data['createdAtMillis']),
      updatedAt: _dateFromMillis(data['updatedAtMillis']),
      snapshot: _map(data['snapshot']),
    );
  }
}

class SubscriptionQuotaExceededException implements Exception {
  final SubscriptionCreditKind? kind;
  final int used;
  final int limit;
  final String message;

  const SubscriptionQuotaExceededException({
    required this.message,
    this.kind,
    this.used = 0,
    this.limit = 0,
  });

  @override
  String toString() => message;
}

class SubscriptionCreditService {
  SubscriptionCreditService({
    FirebaseFunctions? functions,
    SubscriptionCreditCaller? caller,
  })  : _functionsOverride = functions,
        _caller = caller;

  final FirebaseFunctions? _functionsOverride;
  final SubscriptionCreditCaller? _caller;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? prestoFirebaseFunctions;

  Future<SubscriptionCreditSnapshot> getSnapshot() async {
    final result = await _call('getMySubscriptionCredits');
    return SubscriptionCreditSnapshot.fromMap(result);
  }

  Future<void> consume({
    required SubscriptionCreditKind kind,
    required String operationId,
  }) async {
    if (kind == SubscriptionCreditKind.journeys ||
        kind == SubscriptionCreditKind.activeOffers) {
      throw ArgumentError('Ce crédit ne peut pas être consommé directement.');
    }
    await _call(
      'consumeSubscriptionCredit',
      parameters: {'kind': kind.key, 'operationId': operationId},
      quotaKind: kind,
    );
  }

  Future<void> refund({
    required SubscriptionCreditKind kind,
    required String operationId,
  }) async {
    if (kind == SubscriptionCreditKind.journeys ||
        kind == SubscriptionCreditKind.activeOffers) {
      return;
    }
    try {
      await _call(
        'refundSubscriptionCredit',
        parameters: {'kind': kind.key, 'operationId': operationId},
      );
    } catch (_) {
      // Le remboursement est compensatoire : l'erreur initiale reste prioritaire.
    }
  }

  Future<String> saveJourney(
    Map<String, dynamic> snapshot, {
    String? journeyId,
  }) async {
    final result = await _call(
      'saveMyJourney',
      parameters: {
        'snapshot': snapshot,
        if ((journeyId ?? '').trim().isNotEmpty) 'journeyId': journeyId,
      },
      quotaKind: SubscriptionCreditKind.journeys,
    );
    return '${result['journeyId'] ?? ''}';
  }

  Future<List<SavedJourneyRecord>> listJourneys() async {
    final result = await _call('listMyJourneys');
    final raw = result['journeys'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => SavedJourneyRecord.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> deleteJourney(String journeyId) async {
    await _call(
      'deleteMyJourney',
      parameters: {'journeyId': journeyId},
    );
  }

  Future<Map<String, dynamic>> _call(
    String name, {
    Map<String, dynamic>? parameters,
    SubscriptionCreditKind? quotaKind,
  }) async {
    try {
      final caller = _caller;
      if (caller != null) {
        return await caller(name, parameters);
      }
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<dynamic>(parameters);
      return _map(result.data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        final details = _map(error.details);
        final detailKind = _kindFromKey('${details['kind'] ?? ''}') ?? quotaKind;
        final serverMessage = error.message.trim();
        throw SubscriptionQuotaExceededException(
          message: serverMessage.isEmpty
              ? 'Votre crédit est épuisé. Consultez les offres disponibles.'
              : serverMessage,
          kind: detailKind,
          used: _int(details['used']),
          limit: _int(details['limit']),
        );
      }
      rethrow;
    }
  }

  static String newOperationId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_$now';
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime? _dateFromMillis(Object? value) {
  final millis = _int(value);
  if (millis <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

SubscriptionCreditKind? _kindFromKey(String key) {
  for (final kind in SubscriptionCreditKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}
