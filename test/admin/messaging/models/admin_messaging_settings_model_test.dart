import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_settings_model.dart';

void main() {
  test('fromMap applique les valeurs par défaut', () {
    final settings = AdminMessagingSettingsModel.fromMap(
      const <String, dynamic>{},
    );

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

  test('fromMap parse les booléens, nombres et chaînes', () {
    final settings = AdminMessagingSettingsModel.fromMap(
      <String, dynamic>{
        'enabled': false,
        'allowImages': false,
        'allowVoice': false,
        'allowDocuments': false,
        'maxFileSizeMb': 12.9,
        'maxMessagesPerHour': 40,
        'maxConversationsPerDay': 8.8,
        'retentionDays': 90,
        'notificationPreviewEnabled': true,
        'moderationMode': 'strict',
        'riskThreshold': 55.7,
        'autoBlockThreshold': 75,
      },
    );

    expect(settings.enabled, isFalse);
    expect(settings.allowImages, isFalse);
    expect(settings.allowVoice, isFalse);
    expect(settings.allowDocuments, isFalse);
    expect(settings.maxFileSizeMb, 12);
    expect(settings.maxMessagesPerHour, 40);
    expect(settings.maxConversationsPerDay, 8);
    expect(settings.retentionDays, 90);
    expect(settings.notificationPreviewEnabled, isTrue);
    expect(settings.moderationMode, 'strict');
    expect(settings.riskThreshold, 55);
    expect(settings.autoBlockThreshold, 75);
  });

  test('toMap restitue toutes les propriétés', () {
    const settings = AdminMessagingSettingsModel(
      enabled: false,
      allowImages: true,
      allowVoice: false,
      allowDocuments: true,
      maxFileSizeMb: 18,
      maxMessagesPerHour: 50,
      maxConversationsPerDay: 11,
      retentionDays: 120,
      notificationPreviewEnabled: true,
      moderationMode: 'manual',
      riskThreshold: 62,
      autoBlockThreshold: 88,
    );

    expect(settings.toMap(), <String, dynamic>{
      'enabled': false,
      'allowImages': true,
      'allowVoice': false,
      'allowDocuments': true,
      'maxFileSizeMb': 18,
      'maxMessagesPerHour': 50,
      'maxConversationsPerDay': 11,
      'retentionDays': 120,
      'notificationPreviewEnabled': true,
      'moderationMode': 'manual',
      'riskThreshold': 62,
      'autoBlockThreshold': 88,
    });
  });

  test('copyWith remplace les valeurs demandées et conserve les autres', () {
    final original = AdminMessagingSettingsModel.fromMap(
      const <String, dynamic>{},
    );
    final copy = original.copyWith(
      enabled: false,
      allowImages: false,
      allowVoice: false,
      allowDocuments: false,
      maxFileSizeMb: 9,
      maxMessagesPerHour: 30,
      maxConversationsPerDay: 5,
      retentionDays: 45,
      notificationPreviewEnabled: true,
      moderationMode: 'strict',
      riskThreshold: 40,
      autoBlockThreshold: 60,
    );
    final unchanged = original.copyWith();

    expect(copy.enabled, isFalse);
    expect(copy.allowImages, isFalse);
    expect(copy.allowVoice, isFalse);
    expect(copy.allowDocuments, isFalse);
    expect(copy.maxFileSizeMb, 9);
    expect(copy.maxMessagesPerHour, 30);
    expect(copy.maxConversationsPerDay, 5);
    expect(copy.retentionDays, 45);
    expect(copy.notificationPreviewEnabled, isTrue);
    expect(copy.moderationMode, 'strict');
    expect(copy.riskThreshold, 40);
    expect(copy.autoBlockThreshold, 60);
    expect(unchanged.toMap(), original.toMap());
  });
}
