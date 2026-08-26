import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('construit les routes initiales principales', (tester) async {
    final context = await pumpContext(tester);
    const routes = AppRoutes();

    final login = routes.generateInitialRoutes('/login');
    expect(login, hasLength(1));
    expect(login.single.settings.name, '/login');
    expect(
      (login.single as MaterialPageRoute<dynamic>).builder(context).runtimeType
          .toString(),
      contains('LoginPage'),
    );

    for (final path in <String>[
      '/mentions-legales',
      '/confidentialite',
      '/cgu',
    ]) {
      final legal = routes.generateInitialRoutes(path);
      expect(legal, hasLength(1));
      expect(legal.single.settings.name, path);
      expect(
        (legal.single as MaterialPageRoute<dynamic>)
            .builder(context)
            .runtimeType
            .toString(),
        contains('LegalInfoPage'),
      );
    }

    final deletion = routes.generateInitialRoutes('/suppression-compte');
    expect(deletion, hasLength(1));

    final account = routes.generateInitialRoutes('/account');
    expect(account, hasLength(1));
    expect(account.single.settings.name, '/account');

    final fallback = routes.generateInitialRoutes('/inconnue/');
    expect(fallback, hasLength(1));
    expect(fallback.single.settings.name, '/');
    expect(
      (fallback.single as MaterialPageRoute<dynamic>)
          .builder(context)
          .runtimeType
          .toString(),
      contains('SplashScreen'),
    );
  });

  testWidgets('résout les deep links sans monter les pages métier',
      (tester) async {
    final context = await pumpContext(tester);
    const routes = AppRoutes();

    expect(routes.generateRoute(const RouteSettings()), isNull);
    expect(
      routes.generateRoute(const RouteSettings(name: '/inconnue')),
      isNull,
    );

    for (final path in <String>[
      '/offers/offre-1',
      '/listings/annonce-1',
      '/profile/user-1',
      '/profil/user-2',
      '/messages/conversation-1?draft=Bonjour',
      '/messages-2?draft=Salut',
      '/chat/conversation-2',
    ]) {
      final route = routes.generateRoute(RouteSettings(name: path));
      expect(route, isA<MaterialPageRoute<dynamic>>());
      final page = (route! as MaterialPageRoute<dynamic>).builder(context);
      expect(page, isA<Widget>());
    }
  });

  testWidgets('expose et construit les routes nommées du noyau',
      (tester) async {
    final context = await pumpContext(tester);
    const routes = AppRoutes();
    final named = routes.namedRoutes();

    for (final path in <String>[
      '/login',
      '/register',
      '/forgot-password',
      '/verify-email',
      '/reset-password-success',
      '/account/security',
      '/account/change-email',
      '/account/change-password',
      '/account/delete',
      '/mentions-legales',
      '/confidentialite',
      '/cgu',
      '/suppression-compte',
      '/publish',
      '/messages',
      '/messages-2',
      '/account',
      '/admin',
    ]) {
      expect(named, contains(path), reason: path);
      expect(named[path]!(context), isA<Widget>(), reason: path);
    }
  });
}
