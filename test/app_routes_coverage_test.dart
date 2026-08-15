import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/app_routes.dart';
import 'package:presto_app/pages/account/account_security_page.dart';
import 'package:presto_app/pages/auth/login_page.dart';
import 'package:presto_app/pages/legal/account_deletion_info_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';

void main() {
  const routes = AppRoutes();

  test('routes nommées exposent les destinations production attendues', () {
    final named = routes.namedRoutes();

    expect(named, contains(LoginPage.routeName));
    expect(named, contains(AccountSecurityPage.routeName));
    expect(named, contains(LegalInfoPage.legalNoticesRouteName));
    expect(named, contains(AccountDeletionInfoPage.routeName));
    expect(named, contains('/publish'));
    expect(named, contains('/messages'));
    expect(named, contains('/messages-2'));
    expect(named, contains('/account'));
    expect(named, contains('/admin'));
  });

  test('generateInitialRoutes normalise login, compte et route inconnue', () {
    final login = routes.generateInitialRoutes('/login/');
    expect(login, hasLength(1));
    expect(login.single.settings.name, '/');

    final account = routes.generateInitialRoutes('/account/');
    expect(account, hasLength(1));
    expect(account.single.settings.name, '/account');

    final fallback = routes.generateInitialRoutes('/route-inconnue');
    expect(fallback, hasLength(1));
    expect(fallback.single.settings.name, '/');
  });

  testWidgets('generateInitialRoutes construit login et pages légales',
      (tester) async {
    final login = routes.generateInitialRoutes(LoginPage.routeName).single
        as MaterialPageRoute<dynamic>;
    final legal = routes
        .generateInitialRoutes(LegalInfoPage.termsRouteName)
        .single as MaterialPageRoute<dynamic>;
    final deletion = routes
        .generateInitialRoutes(AccountDeletionInfoPage.routeName)
        .single as MaterialPageRoute<dynamic>;

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: login.builder)),
    );
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: legal.builder)),
    );
    expect(find.byType(LegalInfoPage), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: deletion.builder)),
    );
    expect(find.byType(AccountDeletionInfoPage), findsOneWidget);
  });

  test('generateRoute couvre annonce, profil, messages et route nulle', () {
    expect(routes.generateRoute(const RouteSettings(name: '/inconnue')), isNull);

    final listing = routes.generateRoute(
      const RouteSettings(name: '/listings/listing_cov'),
    );
    final profile = routes.generateRoute(
      const RouteSettings(name: '/profile/user_cov'),
    );
    final messages = routes.generateRoute(
      const RouteSettings(name: '/messages/conv_cov?draft=Bonjour'),
    );
    final messagesV2 = routes.generateRoute(
      const RouteSettings(name: '/messages-2/conv_cov_v2'),
    );

    expect(listing, isA<MaterialPageRoute<dynamic>>());
    expect(profile, isA<MaterialPageRoute<dynamic>>());
    expect(messages, isA<MaterialPageRoute<dynamic>>());
    expect(messagesV2, isA<MaterialPageRoute<dynamic>>());
  });
}
