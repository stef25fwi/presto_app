import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_access_state.dart';

class AdminWebDebugEvent {
  const AdminWebDebugEvent({
    required this.timestamp,
    required this.area,
    required this.level,
    required this.message,
    this.detail,
    this.isCallable = false,
  });

  final DateTime timestamp;
  final String area;
  final String level;
  final String message;
  final String? detail;
  final bool isCallable;
}

class AdminWebDebugStore extends ChangeNotifier {
  AdminWebDebugStore._();

  static final AdminWebDebugStore instance = AdminWebDebugStore._();

  static const int _maxEvents = 80;

  final List<AdminWebDebugEvent> _events = <AdminWebDebugEvent>[];
  String _currentRoute = '/';
  DateTime? _lastRouteAt;
  String? _currentUserId;
  String? _currentUserEmail;
  DateTime? _lastAuthAt;
  AdminAccessState _adminAccessState = AdminAccessState.initial();
  DateTime? _lastAdminAccessAt;
  bool _autoOpenRequested = false;

  List<AdminWebDebugEvent> get events =>
      List<AdminWebDebugEvent>.unmodifiable(_events);
  List<String> get availableAreas {
    final result = _events.map((event) => event.area).toSet().toList()..sort();
    return List<String>.unmodifiable(result);
  }

  String get currentRoute => _currentRoute;
  DateTime? get lastRouteAt => _lastRouteAt;
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  DateTime? get lastAuthAt => _lastAuthAt;
  AdminAccessState get adminAccessState => _adminAccessState;
  DateTime? get lastAdminAccessAt => _lastAdminAccessAt;
  bool get hasPendingAutoOpenRequest => _autoOpenRequested;

  void updateRoute(String routeName) {
    final normalized = routeName.trim().isEmpty ? '/' : routeName.trim();
    if (_currentRoute == normalized) return;
    _currentRoute = normalized;
    _lastRouteAt = DateTime.now();
    _append(
      AdminWebDebugEvent(
        timestamp: _lastRouteAt!,
        area: 'route',
        level: 'info',
        message: normalized,
      ),
      notify: true,
    );
  }

  void updateAuth(User? user) {
    final nextUid = user?.uid;
    final nextEmail = user?.email;
    if (_currentUserId == nextUid && _currentUserEmail == nextEmail) return;
    _currentUserId = nextUid;
    _currentUserEmail = nextEmail;
    _lastAuthAt = DateTime.now();
    _append(
      AdminWebDebugEvent(
        timestamp: _lastAuthAt!,
        area: 'auth',
        level: 'info',
        message: nextUid == null ? 'signed-out' : 'signed-in',
        detail: nextUid == null ? null : '$nextUid ${nextEmail ?? ''}'.trim(),
      ),
      notify: true,
    );
  }

  void updateAdminAccess(AdminAccessState state) {
    _adminAccessState = state;
    _lastAdminAccessAt = DateTime.now();
    _append(
      AdminWebDebugEvent(
        timestamp: _lastAdminAccessAt!,
        area: 'admin',
        level: state.hasConfirmedAdminAccess ? 'info' : 'warn',
        message: state.hasConfirmedAdminAccess
            ? 'access-confirmed'
            : 'access-denied',
        detail:
            'source=${state.consolidatedSourceOfTruth} stage=${state.lastStage}',
      ),
      notify: true,
    );
  }

  void recordEvent({
    required String area,
    required String message,
    String level = 'info',
    String? detail,
    bool isCallable = false,
  }) {
    _append(
      AdminWebDebugEvent(
        timestamp: DateTime.now(),
        area: area,
        level: level,
        message: message,
        detail: detail,
        isCallable: isCallable,
      ),
      notify: true,
    );
  }

  void recordError(
    String area,
    Object error, {
    StackTrace? stackTrace,
    String? message,
    bool isCallable = false,
  }) {
    _append(
      AdminWebDebugEvent(
        timestamp: DateTime.now(),
        area: area,
        level: 'error',
        message: message ?? error.runtimeType.toString(),
        detail: _summarizeError(error, stackTrace: stackTrace),
        isCallable: isCallable,
      ),
      notify: true,
    );
  }

  void clear() {
    _events.clear();
    _autoOpenRequested = false;
    notifyListeners();
  }

  bool consumeAutoOpenRequest() {
    final requested = _autoOpenRequested;
    _autoOpenRequested = false;
    return requested;
  }

  List<AdminWebDebugEvent> filteredEvents({
    String? area,
    bool callableOnly = false,
  }) {
    final normalizedArea = (area ?? 'all').trim().toLowerCase();
    Iterable<AdminWebDebugEvent> filtered = _events;
    if (normalizedArea.isNotEmpty && normalizedArea != 'all') {
      filtered = filtered.where(
        (event) => event.area.toLowerCase() == normalizedArea,
      );
    }
    if (callableOnly) {
      filtered = filtered.where((event) => event.isCallable);
    }
    return List<AdminWebDebugEvent>.unmodifiable(
      filtered,
    );
  }

  String buildExportReport({
    String? area,
    bool callableOnly = false,
  }) {
    final lines = <String>[
      'Diagnostic admin web',
      'route=$_currentRoute',
      'user=${_currentUserId ?? 'null'} ${_currentUserEmail ?? ''}'.trim(),
      'adminAccess=${_adminAccessState.hasConfirmedAdminAccess}',
      'adminSource=${_adminAccessState.consolidatedSourceOfTruth}',
      'adminStage=${_adminAccessState.lastStage}',
      'filter=${(area ?? 'all').trim().isEmpty ? 'all' : area!.trim()}',
      'callableOnly=$callableOnly',
      '',
      'Timeline',
    ];

    for (final event
        in filteredEvents(area: area, callableOnly: callableOnly)) {
      lines.add(
        '[${event.timestamp.toIso8601String()}] '
        '${event.area}/${event.level}${event.isCallable ? '/callable' : ''} ${event.message}',
      );
      if ((event.detail ?? '').trim().isNotEmpty) {
        lines.add('  ${event.detail!.trim()}');
      }
    }

    return lines.join('\n');
  }

  String buildExportJson({
    String? area,
    bool callableOnly = false,
  }) {
    final filtered = filteredEvents(area: area, callableOnly: callableOnly);
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'filter': (area ?? 'all').trim().isEmpty ? 'all' : area!.trim(),
      'callableOnly': callableOnly,
      'context': <String, Object?>{
        'route': _currentRoute,
        'lastRouteAt': _lastRouteAt?.toIso8601String(),
        'userId': _currentUserId,
        'userEmail': _currentUserEmail,
        'lastAuthAt': _lastAuthAt?.toIso8601String(),
        'adminAccess': _adminAccessState.hasConfirmedAdminAccess,
        'adminSource': _adminAccessState.consolidatedSourceOfTruth,
        'adminStage': _adminAccessState.lastStage,
        'lastAdminAccessAt': _lastAdminAccessAt?.toIso8601String(),
      },
      'events': filtered
          .map(
            (event) => <String, Object?>{
              'timestamp': event.timestamp.toIso8601String(),
              'area': event.area,
              'level': event.level,
              'message': event.message,
              'detail': event.detail,
              'isCallable': event.isCallable,
            },
          )
          .toList(growable: false),
    });
  }

  void _append(AdminWebDebugEvent event, {required bool notify}) {
    if (_isCriticalEvent(event)) {
      _autoOpenRequested = true;
    }
    if (_events.isNotEmpty) {
      final latest = _events.first;
      if (latest.area == event.area &&
          latest.level == event.level &&
          latest.message == event.message &&
          latest.detail == event.detail &&
          latest.isCallable == event.isCallable) {
        _events[0] = event;
        if (notify) {
          notifyListeners();
        }
        return;
      }
    }
    _events.insert(0, event);
    if (_events.length > _maxEvents) {
      _events.removeRange(_maxEvents, _events.length);
    }
    if (notify) {
      notifyListeners();
    }
  }

  bool _isCriticalEvent(AdminWebDebugEvent event) {
    if (event.level != 'error') {
      return false;
    }
    final area = event.area.toLowerCase();
    if (area == 'appcheck' || area == 'firestore' || area == 'functions') {
      return true;
    }
    final combined = '${event.message} ${event.detail ?? ''}'.toLowerCase();
    if (combined.contains('app check') || combined.contains('appcheck')) {
      return true;
    }
    if (combined.contains('permission-denied') ||
        combined.contains('firestore') ||
        combined.contains('failed-precondition')) {
      return true;
    }
    return area == 'public-offers' || area.startsWith('messages');
  }

  String _summarizeError(Object error, {StackTrace? stackTrace}) {
    final errorText = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    final stackText = stackTrace
        ?.toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(2)
        .join(' | ');
    if (stackText == null || stackText.isEmpty) {
      return errorText;
    }
    return '$errorText | $stackText';
  }
}
