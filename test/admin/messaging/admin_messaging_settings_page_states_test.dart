import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_settings_page.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_settings_model.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_settings_service.dart';

class _FakeSettingsService implements AdminMessagingSettingsService {
  final AdminMessagingSettingsModel? settings;
  final Completer<void>? defaultsCompleter;
  final List<AdminMessagingSettingsModel> saved = [];

  _FakeSettingsService({this.settings, this.defaultsCompleter});

  @override
  Future<void> ensureDefaults() async {
    await defaultsCompleter?.future;
  }

  @override
  Future<void> save(AdminMessagingSettingsModel settings) async {
    saved.add(settings);
  }

  @override
  Stream<AdminMessagingSettingsModel> watchSettings() {
    final value = settings;
    return value == null
        ? const Stream<AdminMessagingSettingsModel>.empty()
        : Stream<AdminMessagingSettingsModel>.value(value);
  }
}

const _settings = AdminMessagingSettingsModel(
  enabled: true,
  allowImages: true,
  allowVoice: true,
  allowDocuments: true,
  maxFileSizeMb: 18,
  maxMessagesPerHour: 42,
  maxConversationsPerDay: 12,
  retentionDays: 180,
  notificationPreviewEnabled: false,
  moderationMode: 'manual',
  riskThreshold: 65,
  autoBlockThreshold: 88,
);

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required bool canEdit,
    required _FakeSettingsService service,
  }) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingSettingsPage(
          canEdit: canEdit,
          service: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('affiche le chargement puis les valeurs par défaut',
      (tester) async {
    final completer = Completer<void>();
    final service = _FakeSettingsService(defaultsCompleter: completer);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingSettingsPage(
          canEdit: true,
          service: service,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Messagerie activée'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mode modération'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('hybrid'), findsOneWidget);
  });

  testWidgets('affiche la lecture seule et toutes les valeurs', (tester) async {
    final service = _FakeSettingsService(settings: _settings);
    await pumpPage(tester, canEdit: false, service: service);

    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(
      find.text(
        'Lecture seule: seuls les superadmins peuvent modifier les paramètres globaux de messagerie.',
      ),
      findsOneWidget,
    );

    for (final title in const [
      'Messagerie activée',
      'Autoriser les images',
      'Autoriser les vocaux',
      'Autoriser les documents',
      'Taille max fichier (Mo)',
      'Messages max / heure',
      'Conversations max / jour',
      'Rétention (jours)',
      'Seuil risque',
      'Seuil auto-blocage',
      'Mode modération',
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    for (final value in const ['18', '42', '12', '180', '65', '88', 'manual']) {
      expect(find.text(value), findsOneWidget);
    }

    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(switches, hasLength(4));
    expect(switches.every((tile) => tile.onChanged == null), isTrue);
    expect(service.saved, isEmpty);
  });

  testWidgets('sauvegarde les quatre interrupteurs en mode édition',
      (tester) async {
    final service = _FakeSettingsService(settings: _settings);
    await pumpPage(tester, canEdit: true, service: service);

    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

    for (final title in const [
      'Messagerie activée',
      'Autoriser les images',
      'Autoriser les vocaux',
      'Autoriser les documents',
    ]) {
      await tester.tap(find.widgetWithText(SwitchListTile, title));
      await tester.pump();
    }

    expect(service.saved, hasLength(4));
    expect(service.saved[0].enabled, isFalse);
    expect(service.saved[1].allowImages, isFalse);
    expect(service.saved[2].allowVoice, isFalse);
    expect(service.saved[3].allowDocuments, isFalse);
    expect(find.text('Paramètres messagerie enregistrés.'), findsWidgets);
  });
}
