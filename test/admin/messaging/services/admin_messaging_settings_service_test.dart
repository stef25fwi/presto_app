import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_settings_model.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_audit_service.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_settings_service.dart';

class _RecordingAuditService extends AdminMessagingAuditService {
  _RecordingAuditService() : super(firestore: FakeFirebaseFirestore());

  String? action;
  String? targetType;
  String? targetId;
  String? reason;
  String? riskLevel;
  Map<String, dynamic>? before;
  Map<String, dynamic>? after;

  @override
  Future<void> logAction({
    required String action,
    required String targetType,
    required String targetId,
    String reason = '',
    String riskLevel = 'normal',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    this.action = action;
    this.targetType = targetType;
    this.targetId = targetId;
    this.reason = reason;
    this.riskLevel = riskLevel;
    this.before = before;
    this.after = after;
  }
}

const _customSettings = AdminMessagingSettingsModel(
  enabled: false,
  allowImages: false,
  allowVoice: true,
  allowDocuments: false,
  maxFileSizeMb: 12,
  maxMessagesPerHour: 24,
  maxConversationsPerDay: 8,
  retentionDays: 90,
  notificationPreviewEnabled: true,
  moderationMode: 'manual',
  riskThreshold: 55,
  autoBlockThreshold: 80,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('construit le service avec ses dépendances par défaut', () {
    expect(() => AdminMessagingSettingsService(), returnsNormally);
  });

  test('observe les valeurs par défaut quand le document est absent',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminMessagingSettingsService(
      firestore: firestore,
      auditService: _RecordingAuditService(),
    );

    final settings = await service.watchSettings().first;

    expect(settings.enabled, isTrue);
    expect(settings.allowImages, isTrue);
    expect(settings.allowVoice, isTrue);
    expect(settings.allowDocuments, isTrue);
    expect(settings.maxFileSizeMb, 25);
    expect(settings.maxMessagesPerHour, 60);
    expect(settings.maxConversationsPerDay, 20);
    expect(settings.retentionDays, 365);
    expect(settings.notificationPreviewEnabled, isFalse);
    expect(settings.moderationMode, 'hybrid');
    expect(settings.riskThreshold, 70);
    expect(settings.autoBlockThreshold, 90);
  });

  test('crée les réglages par défaut une seule fois', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminMessagingSettingsService(
      firestore: firestore,
      auditService: _RecordingAuditService(),
    );
    final reference =
        firestore.collection('messaging_settings').doc('global');

    await service.ensureDefaults();

    final created = (await reference.get()).data();
    expect(created, isNotNull);
    expect(created!['enabled'], isTrue);
    expect(created['maxFileSizeMb'], 25);
    expect(created['moderationMode'], 'hybrid');
    expect(created['autoBlockThreshold'], 90);

    await reference.set(_customSettings.toMap());
    await service.ensureDefaults();

    expect((await reference.get()).data(), _customSettings.toMap());
  });

  test('fusionne les réglages et enregistre un audit exact', () async {
    final firestore = FakeFirebaseFirestore();
    final audit = _RecordingAuditService();
    final service = AdminMessagingSettingsService(
      firestore: firestore,
      auditService: audit,
    );
    final reference =
        firestore.collection('messaging_settings').doc('global');
    await reference.set(<String, dynamic>{'legacyFlag': true});

    await service.save(_customSettings);

    final saved = (await reference.get()).data();
    expect(saved, containsPair('legacyFlag', true));
    for (final entry in _customSettings.toMap().entries) {
      expect(saved, containsPair(entry.key, entry.value));
    }
    expect(audit.action, 'update_messaging_settings');
    expect(audit.targetType, 'messaging_settings');
    expect(audit.targetId, 'global');
    expect(audit.reason, '');
    expect(audit.riskLevel, 'medium');
    expect(audit.before, isNull);
    expect(audit.after, _customSettings.toMap());
  });
}
