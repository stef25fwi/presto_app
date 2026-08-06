import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cookie_consent_service.dart';

const Set<String> campaignQueryKeys = <String>{
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_id',
  'utm_term',
  'utm_content',
  'gclid',
  'dclid',
  'gbraid',
  'wbraid',
  'fbclid',
  'ttclid',
  'msclkid',
};

class CampaignAttribution {
  const CampaignAttribution({
    required this.source,
    required this.medium,
    required this.campaign,
    required this.landingRoute,
    required this.destination,
    required this.capturedAt,
    this.campaignId,
    this.term,
    this.content,
    this.clickIdType,
  });

  final String source;
  final String medium;
  final String campaign;
  final String? campaignId;
  final String? term;
  final String? content;
  final String? clickIdType;
  final String landingRoute;
  final String destination;
  final DateTime capturedAt;

  String get fingerprint => <String>[
        source,
        medium,
        campaign,
        campaignId ?? '',
        term ?? '',
        content ?? '',
        clickIdType ?? '',
        landingRoute,
      ].join('|');

  bool get isExpired => DateTime.now().toUtc().difference(capturedAt.toUtc()) >=
      CampaignAttributionService.retentionDuration;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'medium': medium,
        'campaign': campaign,
        if (campaignId != null) 'campaignId': campaignId,
        if (term != null) 'term': term,
        if (content != null) 'content': content,
        if (clickIdType != null) 'clickIdType': clickIdType,
        'landingRoute': landingRoute,
        'destination': destination,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'schemaVersion': 1,
      };

  static CampaignAttribution? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    final capturedAt = DateTime.tryParse((map['capturedAt'] ?? '').toString());
    final source = (map['source'] ?? '').toString().trim();
    final medium = (map['medium'] ?? '').toString().trim();
    final campaign = (map['campaign'] ?? '').toString().trim();
    final landingRoute = (map['landingRoute'] ?? '').toString().trim();
    final destination = (map['destination'] ?? '').toString().trim();
    if (capturedAt == null ||
        source.isEmpty ||
        medium.isEmpty ||
        campaign.isEmpty ||
        landingRoute.isEmpty ||
        destination.isEmpty) {
      return null;
    }
    return CampaignAttribution(
      source: source,
      medium: medium,
      campaign: campaign,
      campaignId: _nullable(map['campaignId']),
      term: _nullable(map['term']),
      content: _nullable(map['content']),
      clickIdType: _nullable(map['clickIdType']),
      landingRoute: landingRoute,
      destination: destination,
      capturedAt: capturedAt.toUtc(),
    );
  }

  Map<String, Object> analyticsParameters({String prefix = ''}) {
    String key(String value) => prefix.isEmpty ? value : '${prefix}_$value';
    return <String, Object>{
      key('source'): source,
      key('medium'): medium,
      key('campaign'): campaign,
      if (campaignId != null) key('campaign_id'): campaignId!,
      if (term != null) key('term'): term!,
      if (content != null) key('content'): content!,
      if (clickIdType != null) key('click_id_type'): clickIdType!,
      key('landing_route'): landingRoute,
      key('destination'): destination,
    };
  }
}

class CampaignAttributionService {
  CampaignAttributionService._();

  static final CampaignAttributionService instance =
      CampaignAttributionService._();

  static const Duration retentionDuration = Duration(days: 90);
  static const String _firstTouchKey = 'campaign_attribution_first_v1';
  static const String _lastTouchKey = 'campaign_attribution_last_v1';
  static const String _lastLoggedFingerprintKey =
      'campaign_attribution_last_logged_v1';

  final CookieConsentService _consent = CookieConsentService.instance;

  CampaignAttribution? _pending;
  CampaignAttribution? _firstTouch;
  CampaignAttribution? _lastTouch;
  Future<void>? _readyFuture;
  bool _listenerRegistered = false;

  CampaignAttribution? get firstTouch => _firstTouch;
  CampaignAttribution? get lastTouch => _lastTouch ?? _pending;

  /// Capture synchrone et sans stockage : elle peut être appelée depuis le
  /// routeur. L'écriture et les événements GA4 ne sont déclenchés qu'après un
  /// consentement Analytics explicite.
  void observeRoute(String? rawLocation) {
    final attribution = parseCampaignAttribution(rawLocation);
    if (attribution == null) return;
    _pending = attribution;
    _registerConsentListener();

    if (_consent.canUseAnalytics) {
      _readyFuture = null;
      unawaited(ensureReady());
    } else if (_consent.hasChoice) {
      unawaited(_clearStoredAttribution(clearPending: true));
    }
  }

  Future<void> ensureReady() {
    _registerConsentListener();
    return _readyFuture ??= _restoreAndFlush();
  }

  Map<String, Object> parametersForProductEvent() {
    if (!_consent.canUseAnalytics) return const <String, Object>{};
    final first = _firstTouch ?? _pending;
    final last = _lastTouch ?? _pending;
    return <String, Object>{
      if (first != null) ...first.analyticsParameters(prefix: 'first'),
      if (last != null) ...last.analyticsParameters(prefix: 'last'),
    };
  }

  void _registerConsentListener() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;
    _consent.addListener(_handleConsentChanged);
  }

  void _handleConsentChanged() {
    _readyFuture = null;
    if (_consent.canUseAnalytics) {
      unawaited(ensureReady());
    } else if (_consent.hasChoice) {
      unawaited(_clearStoredAttribution(clearPending: true));
    }
  }

  Future<void> _restoreAndFlush() async {
    await _consent.load();
    if (!_consent.canUseAnalytics) return;

    final prefs = await SharedPreferences.getInstance();
    _firstTouch = _decodeAttribution(prefs.getString(_firstTouchKey));
    _lastTouch = _decodeAttribution(prefs.getString(_lastTouchKey));

    if (_firstTouch?.isExpired ?? false) {
      _firstTouch = null;
      await prefs.remove(_firstTouchKey);
    }
    if (_lastTouch?.isExpired ?? false) {
      _lastTouch = null;
      await prefs.remove(_lastTouchKey);
    }

    final pending = _pending;
    if (pending == null) return;

    _firstTouch ??= pending;
    _lastTouch = pending;
    await prefs.setString(_firstTouchKey, jsonEncode(_firstTouch!.toJson()));
    await prefs.setString(_lastTouchKey, jsonEncode(pending.toJson()));

    final lastLogged = prefs.getString(_lastLoggedFingerprintKey);
    if (lastLogged == pending.fingerprint) return;

    await prefs.setString(_lastLoggedFingerprintKey, pending.fingerprint);
    await _logAttributionEvent('campaign_landing', pending);
    if (pending.destination != 'home' && pending.destination != 'other') {
      await _logAttributionEvent('deep_link_open', pending);
    }
  }

  Future<void> _logAttributionEvent(
    String name,
    CampaignAttribution attribution,
  ) async {
    if (!_consent.canUseAnalytics) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: attribution.analyticsParameters(),
      );
    } catch (error) {
      debugPrint('[CampaignAttribution] $name failed: $error');
    }
  }

  Future<void> _clearStoredAttribution({required bool clearPending}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_firstTouchKey);
      await prefs.remove(_lastTouchKey);
      await prefs.remove(_lastLoggedFingerprintKey);
    } catch (error) {
      debugPrint('[CampaignAttribution] clear failed: $error');
    }
    _firstTouch = null;
    _lastTouch = null;
    if (clearPending) _pending = null;
  }

  CampaignAttribution? _decodeAttribution(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return CampaignAttribution.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _pending = null;
    _firstTouch = null;
    _lastTouch = null;
    _readyFuture = null;
  }
}

CampaignAttribution? parseCampaignAttribution(
  String? rawLocation, {
  DateTime? capturedAt,
}) {
  final effective = effectiveCampaignUri(rawLocation);
  if (effective == null) return null;

  final query = <String, String>{};
  for (final entry in effective.queryParameters.entries) {
    final key = entry.key.toLowerCase().trim();
    if (campaignQueryKeys.contains(key)) {
      query[key] = _sanitize(entry.value, maxLength: 160);
    }
  }
  query.removeWhere((_, value) => value.isEmpty);
  if (query.isEmpty) return null;

  final clickIdType = _clickIdType(query);
  final inferred = _inferredSourceMedium(clickIdType);
  final source = _sanitize(
    query['utm_source'] ?? inferred.$1 ?? 'direct',
    maxLength: 100,
  );
  final medium = _sanitize(
    query['utm_medium'] ?? inferred.$2 ?? 'campaign',
    maxLength: 100,
  );
  final campaign = _sanitize(
    query['utm_campaign'] ?? query['utm_id'] ?? '(not set)',
    maxLength: 100,
  );
  final route = normalizedCampaignRoute(effective);

  return CampaignAttribution(
    source: source,
    medium: medium,
    campaign: campaign,
    campaignId: _nullable(query['utm_id']),
    term: _nullable(query['utm_term']),
    content: _nullable(query['utm_content']),
    clickIdType: clickIdType,
    landingRoute: route,
    destination: campaignDestinationForRoute(route),
    capturedAt: (capturedAt ?? DateTime.now()).toUtc(),
  );
}

Uri? effectiveCampaignUri(String? rawLocation) {
  final raw = (rawLocation ?? '').trim();
  if (raw.isEmpty) return null;
  final outer = Uri.tryParse(raw);
  if (outer == null) return null;

  Uri routeUri = outer;
  if (outer.fragment.isNotEmpty &&
      (outer.path.isEmpty || outer.path == '/' || outer.fragment.startsWith('/'))) {
    final fragment = outer.fragment.startsWith('/')
        ? outer.fragment
        : '/${outer.fragment}';
    routeUri = Uri.tryParse(fragment) ?? outer;
  }

  var pathSegments = routeUri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: true);
  if (outer.scheme.toLowerCase() == 'ilipresto' && outer.host.isNotEmpty) {
    pathSegments = <String>[outer.host, ...pathSegments];
  }
  if (pathSegments.isNotEmpty && pathSegments.first == 'app') {
    pathSegments = pathSegments.skip(1).toList(growable: false);
  }

  return Uri(
    pathSegments: pathSegments,
    queryParameters: <String, String>{
      ...outer.queryParameters,
      ...routeUri.queryParameters,
    },
  );
}

String normalizedCampaignRoute(Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) return '/';

  final first = segments.first;
  if (segments.length >= 2 &&
      <String>{
        'offers',
        'listings',
        'profile',
        'profil',
        'messages',
        'messages-2',
        'chat',
      }.contains(first)) {
    return '/$first/:id';
  }
  return '/${segments.join('/')}';
}

String campaignDestinationForRoute(String route) {
  if (route == '/') return 'home';
  if (route.startsWith('/offers/')) return 'offer';
  if (route.startsWith('/listings/')) return 'listing';
  if (route.startsWith('/profile/') || route.startsWith('/profil/')) {
    return 'profile';
  }
  if (route.startsWith('/messages') || route.startsWith('/chat/')) {
    return 'messages';
  }
  if (route == '/publish') return 'publish';
  if (route == '/account') return 'account';
  return 'other';
}

Uri buildCampaignDeepLink({
  required String path,
  required String source,
  required String medium,
  required String campaign,
  String? campaignId,
  String? term,
  String? content,
}) {
  var normalizedPath = path.trim();
  if (!normalizedPath.startsWith('/')) normalizedPath = '/$normalizedPath';
  if (!normalizedPath.startsWith('/app/')) {
    normalizedPath = '/app${normalizedPath == '/' ? '' : normalizedPath}';
  }
  return Uri.https('ilipresto.fr', normalizedPath, <String, String>{
    'utm_source': _sanitize(source, maxLength: 100),
    'utm_medium': _sanitize(medium, maxLength: 100),
    'utm_campaign': _sanitize(campaign, maxLength: 100),
    if (_nullable(campaignId) != null) 'utm_id': _nullable(campaignId)!,
    if (_nullable(term) != null) 'utm_term': _nullable(term)!,
    if (_nullable(content) != null) 'utm_content': _nullable(content)!,
  });
}

(String?, String?) _inferredSourceMedium(String? clickIdType) {
  switch (clickIdType) {
    case 'gclid':
    case 'gbraid':
    case 'wbraid':
      return ('google', 'cpc');
    case 'dclid':
      return ('google', 'display');
    case 'fbclid':
      return ('facebook', 'paid_social');
    case 'ttclid':
      return ('tiktok', 'paid_social');
    case 'msclkid':
      return ('bing', 'cpc');
    default:
      return (null, null);
  }
}

String? _clickIdType(Map<String, String> query) {
  for (final key in const <String>[
    'gclid',
    'dclid',
    'gbraid',
    'wbraid',
    'fbclid',
    'ttclid',
    'msclkid',
  ]) {
    if ((query[key] ?? '').isNotEmpty) return key;
  }
  return null;
}

String _sanitize(String value, {required int maxLength}) {
  final cleaned = value
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.length <= maxLength) return cleaned;
  return cleaned.substring(0, maxLength);
}

String? _nullable(Object? value) {
  final normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? null : normalized;
}
