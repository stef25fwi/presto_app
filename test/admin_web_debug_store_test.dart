import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';
import 'package:presto_app/services/admin_web_debug_store.dart';

AdminWebDebugEvent _event({
  required String area,
  required String message,
  String level = 'info',
  String? detail,
  bool isCallable = false,
}) {
  return AdminWebDebugEvent(
    timestamp: DateTime.utc(2026, 7, 15, 12),
    area: area,
    level: level,
    message: message,
    detail: detail,
    isCallable: isCallable,
  );
}

void main() {
  final store = AdminWebDebugStore.instance;

  setUp(() {
    store.clear();
    store.consumeAutoOpenRequest();
  });

  test('updates route, normalizes blanks and avoids duplicate notifications', () {
    var notifications = 0;
    void listener() => notifications++;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    final uniqueRoute = '/admin-${DateTime.now().microsecondsSinceEpoch}';
    store.updateRoute('  $uniqueRoute  ');

    expect(store.currentRoute, uniqueRoute);
    expect(store.lastRouteAt, isNotNull);
    expect(store.events, hasLength(1));
    expect(store.events.first.area, 'route');
    expect(store.events.first.message, uniqueRoute);
    expect(notifications, 1);

    store.updateRoute(uniqueRoute);
    expect(store.events, hasLength(1));
    expect(notifications, 1);

    store.updateRoute('   ');
    expect(store.currentRoute, '/');
    expect(store.events.first.message, '/');
    expect(notifications, 2);
  });

  test('records, deduplicates, sorts areas and filters events', () async {
    store.recordEvent(area: 'zeta', message: 'plain');
    store.recordEvent(
      area: 'Auth',
      message: 'callable',
      level: 'warn',
      detail: ' details ',
      isCallable: true,
    );
    final firstTimestamp = store.events.first.timestamp;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    store.recordEvent(
      area: 'Auth',
      message: 'callable',
      level: 'warn',
      detail: ' details ',
      isCallable: true,
    );

    expect(store.events, hasLength(2));
    expect(store.events.first.timestamp.isAfter(firstTimestamp), isTrue);
    expect(store.availableAreas, <String>['Auth', 'zeta']);

    final byArea = store.filteredEvents(area: ' auth ');
    expect(byArea, hasLength(1));
    expect(byArea.single.message, 'callable');

    final callable = store.filteredEvents(callableOnly: true);
    expect(callable, hasLength(1));
    expect(callable.single.isCallable, isTrue);

    final all = store.filteredEvents(area: 'all');
    expect(all, hasLength(2));
    expect(
      () => all.add(_event(area: 'x', message: 'mutate')),
      throwsUnsupportedError,
    );
    expect(
      () => store.events.add(_event(area: 'x', message: 'mutate')),
      throwsUnsupportedError,
    );
  });

  test('records critical errors and consumes auto-open requests', () {
    store.recordError(
      'functions',
      StateError('backend exploded'),
      stackTrace: StackTrace.fromString('first line\nsecond line\nthird line'),
      message: 'call failed',
      isCallable: true,
    );

    expect(store.events, hasLength(1));
    final event = store.events.single;
    expect(event.area, 'functions');
    expect(event.level, 'error');
    expect(event.message, 'call failed');
    expect(event.detail, contains('Bad state: backend exploded'));
    expect(event.detail, contains('first line | second line'));
    expect(event.isCallable, isTrue);
    expect(store.hasPendingAutoOpenRequest, isTrue);
    expect(store.consumeAutoOpenRequest(), isTrue);
    expect(store.consumeAutoOpenRequest(), isFalse);

    store.clear();
    store.recordError('ui', ArgumentError('minor'));
    expect(store.events.single.message, 'ArgumentError');
    expect(store.hasPendingAutoOpenRequest, isFalse);
  });

  test('recognizes all critical areas and diagnostic keywords', () {
    final criticalCases = <({String area, String message, String? detail})>[
      (area: 'appcheck', message: 'failed', detail: null),
      (area: 'firestore', message: 'failed', detail: null),
      (area: 'public-offers', message: 'failed', detail: null),
      (area: 'messages-send', message: 'failed', detail: null),
      (area: 'ui', message: 'App Check rejected', detail: null),
      (area: 'ui', message: 'permission-denied', detail: null),
      (area: 'ui', message: 'failed-precondition', detail: null),
      (area: 'ui', message: 'failure', detail: 'Firestore unavailable'),
    ];

    for (final item in criticalCases) {
      store.clear();
      store.recordEvent(
        area: item.area,
        level: 'error',
        message: item.message,
        detail: item.detail,
      );
      expect(
        store.hasPendingAutoOpenRequest,
        isTrue,
        reason: '${item.area}: ${item.message}',
      );
    }

    store.clear();
    store.recordEvent(area: 'firestore', level: 'warn', message: 'warning');
    expect(store.hasPendingAutoOpenRequest, isFalse);
  });

  test('updates denied and confirmed admin access state', () {
    store.updateAdminAccess(AdminAccessState.initial());

    expect(store.lastAdminAccessAt, isNotNull);
    expect(store.adminAccessState.hasConfirmedAdminAccess, isFalse);
    expect(store.events.first.area, 'admin');
    expect(store.events.first.level, 'warn');
    expect(store.events.first.message, 'access-denied');
    expect(store.events.first.detail, contains('source=none'));
    expect(store.events.first.detail, contains('stage=idle'));

    final confirmed = AdminAccessState.initial().copyWith(
      isAuthenticated: true,
      tokenLoaded: true,
      tokenHasAdmin: true,
      tokenRoles: const ['admin'],
      tokenPrimaryRole: 'admin',
      lastStage: 'token-loaded',
    );
    store.updateAdminAccess(confirmed);

    expect(store.adminAccessState, same(confirmed));
    expect(store.events.first.level, 'info');
    expect(store.events.first.message, 'access-confirmed');
    expect(store.events.first.detail, contains('source=token'));
    expect(store.events.first.detail, contains('stage=token-loaded'));
  });

  test('builds text and JSON exports with active filters', () {
    final route = '/export-${DateTime.now().microsecondsSinceEpoch}';
    store.updateRoute(route);
    store.recordEvent(
      area: 'functions',
      level: 'error',
      message: 'call failed',
      detail: 'permission-denied',
      isCallable: true,
    );
    store.recordEvent(area: 'ui', message: 'rendered');

    final report = store.buildExportReport(
      area: 'functions',
      callableOnly: true,
    );
    expect(report, contains('Diagnostic admin web'));
    expect(report, contains('route=$route'));
    expect(report, contains('filter=functions'));
    expect(report, contains('callableOnly=true'));
    expect(report, contains('functions/error/callable call failed'));
    expect(report, contains('  permission-denied'));
    expect(report, isNot(contains('ui/info rendered')));

    final emptyFilterReport = store.buildExportReport(area: '   ');
    expect(emptyFilterReport, contains('filter=all'));

    final json = jsonDecode(
      store.buildExportJson(area: 'functions', callableOnly: true),
    ) as Map<String, dynamic>;
    expect(json['filter'], 'functions');
    expect(json['callableOnly'], isTrue);
    expect(json['generatedAt'], isA<String>());

    final context = json['context'] as Map<String, dynamic>;
    expect(context['route'], route);
    expect(context['adminAccess'], isA<bool>());
    expect(context.containsKey('lastRouteAt'), isTrue);

    final events = json['events'] as List<dynamic>;
    expect(events, hasLength(1));
    final event = events.single as Map<String, dynamic>;
    expect(event['area'], 'functions');
    expect(event['level'], 'error');
    expect(event['message'], 'call failed');
    expect(event['detail'], 'permission-denied');
    expect(event['isCallable'], isTrue);

    final emptyFilterJson = jsonDecode(store.buildExportJson(area: '   '))
        as Map<String, dynamic>;
    expect(emptyFilterJson['filter'], 'all');
  });

  test('caps the timeline at eighty newest events', () {
    for (var index = 0; index < 85; index++) {
      store.recordEvent(
        area: 'area-${index % 3}',
        message: 'event-$index',
      );
    }

    expect(store.events, hasLength(80));
    expect(store.events.first.message, 'event-84');
    expect(store.events.last.message, 'event-5');
  });

  test('clear resets events and pending auto-open state', () {
    store.recordEvent(
      area: 'appcheck',
      level: 'error',
      message: 'token rejected',
    );
    expect(store.events, isNotEmpty);
    expect(store.hasPendingAutoOpenRequest, isTrue);

    store.clear();

    expect(store.events, isEmpty);
    expect(store.hasPendingAutoOpenRequest, isFalse);
  });
}
