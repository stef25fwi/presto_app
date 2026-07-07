import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_messaging_settings_model.dart';
import 'admin_messaging_audit_service.dart';

class AdminMessagingSettingsService {
  final FirebaseFirestore _firestore;
  final AdminMessagingAuditService _auditService;

  AdminMessagingSettingsService({
    FirebaseFirestore? firestore,
    AdminMessagingAuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditService = auditService ?? AdminMessagingAuditService();

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('messaging_settings').doc('global');

  Stream<AdminMessagingSettingsModel> watchSettings() {
    return _doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return AdminMessagingSettingsModel.fromMap(data);
    });
  }

  Future<void> ensureDefaults() async {
    final snapshot = await _doc.get();
    if (snapshot.exists) return;
    await _doc.set(const AdminMessagingSettingsModel(
      enabled: true,
      allowImages: true,
      allowVoice: true,
      allowDocuments: true,
      maxFileSizeMb: 25,
      maxMessagesPerHour: 60,
      maxConversationsPerDay: 20,
      retentionDays: 365,
      notificationPreviewEnabled: false,
      moderationMode: 'hybrid',
      riskThreshold: 70,
      autoBlockThreshold: 90,
    ).toMap());
  }

  Future<void> save(AdminMessagingSettingsModel settings) async {
    await _doc.set(settings.toMap(), SetOptions(merge: true));
    await _auditService.logAction(
      action: 'update_messaging_settings',
      targetType: 'messaging_settings',
      targetId: 'global',
      riskLevel: 'medium',
      after: settings.toMap(),
    );
  }
}
