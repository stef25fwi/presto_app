import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/account_notifications_tile.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester,
    AccountNotificationsTile tile,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 600, child: tile),
        ),
      ),
    );
    await tester.pump();
  }

  SwitchListTile switchTile(WidgetTester tester) {
    return tester.widget<SwitchListTile>(find.byType(SwitchListTile));
  }

  testWidgets('affiche le chargement puis l état activé et enregistre le device',
      (tester) async {
    final status = Completer<AuthorizationStatus>();
    var ensureCalls = 0;

    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () => status.future,
        ensureDeviceRegistered: () async => ensureCalls += 1,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(switchTile(tester).onChanged, isNull);

    status.complete(AuthorizationStatus.authorized);
    await tester.pumpAndSettle();

    expect(find.text('Activées'), findsOneWidget);
    expect(
      find.text('Nouveaux messages, réponses à tes annonces et alertes.'),
      findsOneWidget,
    );
    expect(switchTile(tester).value, isTrue);
    expect(ensureCalls, 1);
  });

  testWidgets('ouvre les réglages pour débloquer une permission refusée',
      (tester) async {
    var settingsCalls = 0;

    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async => AuthorizationStatus.denied,
        openSystemSettings: () async => settingsCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bloquées'), findsOneWidget);
    expect(find.text('Bloquées dans les réglages système.'), findsOneWidget);

    switchTile(tester).onChanged!(true);
    await tester.pumpAndSettle();

    expect(settingsCalls, 1);
  });

  testWidgets('ouvre les réglages lors de la désactivation', (tester) async {
    var settingsCalls = 0;

    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async => AuthorizationStatus.authorized,
        ensureDeviceRegistered: () async {},
        openSystemSettings: () async => settingsCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    switchTile(tester).onChanged!(false);
    await tester.pumpAndSettle();

    expect(settingsCalls, 1);
  });

  testWidgets('active les notifications et affiche le succès', (tester) async {
    var status = AuthorizationStatus.notDetermined;
    var requestCalls = 0;
    var ensureCalls = 0;

    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async => status,
        requestPushPermission: () async {
          requestCalls += 1;
          status = AuthorizationStatus.authorized;
          return true;
        },
        ensureDeviceRegistered: () async => ensureCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Désactivées'), findsOneWidget);
    expect(find.text('Active-les pour ne rien manquer.'), findsOneWidget);

    switchTile(tester).onChanged!(true);
    await tester.pumpAndSettle();

    expect(requestCalls, 1);
    expect(ensureCalls, 1);
    expect(find.text('Activées'), findsOneWidget);
    expect(
      find.text('Notifications activées sur cet appareil.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche le message métier lorsque l activation est refusée',
      (tester) async {
    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async => AuthorizationStatus.notDetermined,
        requestPushPermission: () async => false,
        activationFailureMessage: () => 'Permission refusée par le système.',
      ),
    );
    await tester.pumpAndSettle();

    switchTile(tester).onChanged!(true);
    await tester.pumpAndSettle();

    expect(find.text('Permission refusée par le système.'), findsOneWidget);
    expect(switchTile(tester).value, isFalse);
  });

  testWidgets('affiche une erreur lorsque la demande de permission échoue',
      (tester) async {
    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async => AuthorizationStatus.notDetermined,
        requestPushPermission: () async {
          throw StateError('plugin indisponible');
        },
      ),
    );
    await tester.pumpAndSettle();

    switchTile(tester).onChanged!(true);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Erreur d’activation : Bad state: plugin indisponible'),
      findsOneWidget,
    );
    expect(switchTile(tester).onChanged, isNotNull);
  });

  testWidgets('termine le chargement même si la lecture de permission échoue',
      (tester) async {
    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async {
          throw StateError('permission illisible');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Désactivées'), findsOneWidget);
    expect(switchTile(tester).onChanged, isNotNull);
  });

  testWidgets('affiche le guide manuel si l ouverture des réglages échoue',
      (tester) async {
    await pumpTile(
      tester,
      AccountNotificationsTile(
        statusLoader: () async => AuthorizationStatus.notDetermined,
        openSystemSettings: () async {
          throw StateError('réglages indisponibles');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gérer dans les réglages système'));
    await tester.pumpAndSettle();

    expect(find.text('Réglages des notifications'), findsOneWidget);
    expect(
      find.textContaining('Ouvre les réglages de ton téléphone'),
      findsOneWidget,
    );
    expect(find.text('Compris'), findsOneWidget);

    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();
    expect(find.text('Réglages des notifications'), findsNothing);
  });
}
