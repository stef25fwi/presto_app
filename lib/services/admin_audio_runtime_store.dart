import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminAudioRuntimeEntry {
  final int attemptNumber;
  final DateTime timestamp;
  final String flowKey;
  final String status;
  final String label;
  final String detail;
  final String configuredMode;
  final String? backendModeUsed;
  final int? transcriptLength;

  const AdminAudioRuntimeEntry({
    required this.attemptNumber,
    required this.timestamp,
    required this.flowKey,
    required this.status,
    required this.label,
    required this.detail,
    required this.configuredMode,
    this.backendModeUsed,
    this.transcriptLength,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'attemptNumber': attemptNumber,
      'timestamp': timestamp.toIso8601String(),
      'flowKey': flowKey,
      'status': status,
      'label': label,
      'detail': detail,
      'configuredMode': configuredMode,
      'backendModeUsed': backendModeUsed,
      'transcriptLength': transcriptLength,
    };
  }

  factory AdminAudioRuntimeEntry.fromMap(Map<String, dynamic> map) {
    return AdminAudioRuntimeEntry(
      attemptNumber: (map['attemptNumber'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse((map['timestamp'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      flowKey: (map['flowKey'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      label: (map['label'] ?? '').toString(),
      detail: (map['detail'] ?? '').toString(),
      configuredMode: (map['configuredMode'] ?? 'HYBRID').toString(),
      backendModeUsed: map['backendModeUsed']?.toString(),
      transcriptLength: (map['transcriptLength'] as num?)?.toInt(),
    );
  }
}

class AdminAudioRuntimeStore extends ChangeNotifier {
  AdminAudioRuntimeStore._();

  static final AdminAudioRuntimeStore instance = AdminAudioRuntimeStore._();

  static const int _maxHistoryEntries = 5;
  static const String _storageKey = 'admin_audio_runtime_store_v1';
  static const String _cloudCollection = 'admin_runtime_audio';
  static const String _cloudDocumentId = 'shared';

  int _attemptCounter = 0;
  String _configuredMode = 'HYBRID';
  String _currentLabel = 'Mode serveur';
  String _currentDetail = 'Aucun pipeline recent';
  String? _backendModeUsed;
  DateTime? _lastUpdatedAt;
  String _dataSource = 'local';
  final List<AdminAudioRuntimeEntry> _history = <AdminAudioRuntimeEntry>[];
  Future<void>? _loadFuture;
  bool _loaded = false;
  bool _cloudSyncEnabled = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cloudSubscription;

  String get configuredMode => _configuredMode;
  String get currentLabel => _currentLabel;
  String get currentDetail => _currentDetail;
  String? get backendModeUsed => _backendModeUsed;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  String get dataSource => _dataSource;
  bool get cloudSyncEnabled => _cloudSyncEnabled;
  AdminAudioRuntimeEntry? get latestEntry =>
      _history.isEmpty ? null : _history.first;
  List<AdminAudioRuntimeEntry> get history =>
      List<AdminAudioRuntimeEntry>.unmodifiable(_history);

  Future<void> ensureInitialized() {
    return _loadFuture ??= _loadFromStorage();
  }

  Future<void> enableCloudSync() async {
    await ensureInitialized();
    if (_cloudSyncEnabled) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _cloudSyncEnabled = true;
    final docRef = FirebaseFirestore.instance
        .collection(_cloudCollection)
        .doc(_cloudDocumentId);

    _cloudSubscription?.cancel();
    _cloudSubscription = docRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return;

        final remoteUpdatedAtMs = (data['updatedAtMs'] as num?)?.toInt() ?? 0;
        final localUpdatedAtMs = _lastUpdatedAt?.millisecondsSinceEpoch ?? 0;

        if (remoteUpdatedAtMs <= localUpdatedAtMs && _history.isNotEmpty) {
          return;
        }

        _applyRemotePayload(data);
      },
      onError: (_) {
        _cloudSyncEnabled = false;
      },
    );

    await _pullFromCloudOrPushLocal(docRef);
  }

  Future<void> _loadFromStorage() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        _dataSource = 'local';
        _loaded = true;
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _loaded = true;
        return;
      }

      _attemptCounter = (decoded['attemptCounter'] as num?)?.toInt() ?? 0;
      _configuredMode =
          (decoded['configuredMode'] ?? 'HYBRID').toString().toUpperCase();
      _currentLabel =
          (decoded['currentLabel'] ?? 'Mode serveur').toString();
      _currentDetail =
          (decoded['currentDetail'] ?? 'Aucun pipeline recent').toString();
      _backendModeUsed = decoded['backendModeUsed']?.toString();
        _dataSource = (decoded['dataSource'] ?? 'local').toString();
      _lastUpdatedAt = decoded['lastUpdatedAt'] == null
          ? null
          : DateTime.tryParse(decoded['lastUpdatedAt'].toString());

      final historyList = decoded['history'];
      if (historyList is List) {
        _history
          ..clear()
          ..addAll(
            historyList
                .whereType<Map>()
                .map(
                  (entry) => AdminAudioRuntimeEntry.fromMap(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .take(_maxHistoryEntries),
          );
      }
    } catch (_) {
      _history.clear();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _pullFromCloudOrPushLocal(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        await _persistToCloud();
        return;
      }

      final remoteUpdatedAtMs = (data['updatedAtMs'] as num?)?.toInt() ?? 0;
      final localUpdatedAtMs = _lastUpdatedAt?.millisecondsSinceEpoch ?? 0;

      if (remoteUpdatedAtMs > localUpdatedAtMs) {
        _applyRemotePayload(data);
      } else if (_history.isNotEmpty) {
        await _persistToCloud();
      }
    } catch (_) {
      _cloudSyncEnabled = false;
    }
  }

  void _applyRemotePayload(Map<String, dynamic> data) {
    _attemptCounter = (data['attemptCounter'] as num?)?.toInt() ?? _attemptCounter;
    _configuredMode =
        (data['configuredMode'] ?? _configuredMode).toString().toUpperCase();
    _currentLabel = (data['currentLabel'] ?? _currentLabel).toString();
    _currentDetail = (data['currentDetail'] ?? _currentDetail).toString();
    _backendModeUsed = data['backendModeUsed']?.toString();
    _dataSource = 'cloud';
    final updatedAtMs = (data['updatedAtMs'] as num?)?.toInt();
    _lastUpdatedAt = updatedAtMs == null
        ? _lastUpdatedAt
        : DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

    final historyList = data['history'];
    if (historyList is List) {
      _history
        ..clear()
        ..addAll(
          historyList
              .whereType<Map>()
              .map(
                (entry) => AdminAudioRuntimeEntry.fromMap(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .take(_maxHistoryEntries),
        );
    }

    _schedulePersist();
    notifyListeners();
  }

  void _schedulePersist() {
    unawaited(_persistToStorage());
    if (_cloudSyncEnabled) {
      unawaited(_persistToCloud());
    }
  }

  Future<void> _persistToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'attemptCounter': _attemptCounter,
        'configuredMode': _configuredMode,
        'currentLabel': _currentLabel,
        'currentDetail': _currentDetail,
        'backendModeUsed': _backendModeUsed,
        'dataSource': _dataSource,
        'lastUpdatedAt': _lastUpdatedAt?.toIso8601String(),
        'history': _history.map((entry) => entry.toMap()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('[AdminAudioRuntimeStore] _persistToLocal failed: $e');
    }
  }

  Future<void> _persistToCloud() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final payload = <String, dynamic>{
        'attemptCounter': _attemptCounter,
        'configuredMode': _configuredMode,
        'currentLabel': _currentLabel,
        'currentDetail': _currentDetail,
        'backendModeUsed': _backendModeUsed,
        'updatedAtMs': _lastUpdatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        'updatedByUid': currentUser.uid,
        'history': _history.map((entry) => entry.toMap()).toList(),
      };

      await FirebaseFirestore.instance
          .collection(_cloudCollection)
          .doc(_cloudDocumentId)
          .set(payload, SetOptions(merge: true));
    } catch (_) {
      _cloudSyncEnabled = false;
    }
  }

  void updateConfiguredMode(String mode) {
    final normalized = mode.trim().isEmpty ? 'HYBRID' : mode.trim().toUpperCase();
    if (_configuredMode == normalized) return;
    _configuredMode = normalized;
    _dataSource = 'local';
    _schedulePersist();
    notifyListeners();
  }

  void recordRuntime({
    required String flowKey,
    required String label,
    required String detail,
    String status = 'pending',
    String? backendModeUsed,
    int? transcriptLength,
  }) {
    final now = DateTime.now();
    final normalizedBackendMode = backendModeUsed == null || backendModeUsed.trim().isEmpty
        ? null
        : backendModeUsed.trim().toUpperCase();
    _attemptCounter += 1;

    _currentLabel = label;
    _currentDetail = detail;
    _backendModeUsed = normalizedBackendMode;
    _dataSource = 'local';
    _lastUpdatedAt = now;

    _history.insert(
      0,
      AdminAudioRuntimeEntry(
        attemptNumber: _attemptCounter,
        timestamp: now,
        flowKey: flowKey,
        status: status,
        label: label,
        detail: detail,
        configuredMode: _configuredMode,
        backendModeUsed: normalizedBackendMode,
        transcriptLength: transcriptLength,
      ),
    );

    if (_history.length > _maxHistoryEntries) {
      _history.removeRange(_maxHistoryEntries, _history.length);
    }
    _schedulePersist();
    notifyListeners();
  }

  void confirmLatestBackendResult({
    required String backendModeUsed,
    required String detail,
    int? transcriptLength,
  }) {
    final normalized = backendModeUsed.trim().toUpperCase();
    if (normalized.isEmpty) return;
    _backendModeUsed = normalized;
    _dataSource = 'local';
    _lastUpdatedAt = DateTime.now();
    _currentDetail = detail;

    if (_history.isNotEmpty) {
      final latest = _history.first;
      _history[0] = AdminAudioRuntimeEntry(
        attemptNumber: latest.attemptNumber,
        timestamp: latest.timestamp,
        flowKey: latest.flowKey,
        status: 'confirmed',
        label: latest.label,
        detail: detail,
        configuredMode: latest.configuredMode,
        backendModeUsed: normalized,
        transcriptLength: transcriptLength ?? latest.transcriptLength,
      );
    }
    _schedulePersist();
    notifyListeners();
  }

  void clearHistory() {
    _attemptCounter = 0;
    _currentLabel = 'Mode serveur';
    _currentDetail = 'Historique effacé';
    _backendModeUsed = null;
    _dataSource = 'local';
    _lastUpdatedAt = DateTime.now();
    _history.clear();
    _schedulePersist();
    notifyListeners();
  }
}