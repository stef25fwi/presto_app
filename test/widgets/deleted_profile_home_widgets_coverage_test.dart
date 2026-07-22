import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';
import 'package:presto_app/widgets/home_interactions.dart';

void main() {
  test('DeletedUserProfile détecte tous les marqueurs de suppression', () {
    expect(DeletedUserProfile.isDeletedMap(null), isTrue);
    expect(DeletedUserProfile.isDeletedMap(<String, dynamic>{}), isFalse);

    for (final data in <Map<String, dynamic>>[
      <String, dynamic>{'deletedAt': 'now'},
      <String, dynamic>{'accountDeleted': true},
      <String, dynamic>{'isDeleted': true},
      <String, dynamic>{'disabled': true},
      <String, dynamic>{'anonymized': true},
      <String, dynamic>{'status': ' Deleted '},
      <String, dynamic>{'status': 'removed'},
      <String, dynamic>{'accountStatus': 'DISABLED'},
      <String, dynamic>{'accountStatus': 'anonymized'},
    ]) {
      expect(DeletedUserProfile.isDeletedMap(data), isTrue, reason: '$data');
    }
  });

  test('DeletedUserProfile normalise le nom affiché', () {
    expect(
      DeletedUserProfile.displayName(isDeleted: true, fallbackName: 'Alice'),
      DeletedUserProfile.label,
    );
    expect(
      DeletedUserProfile.displayName(isDeleted: false, fallbackName: null),
      'Utilisateur',
    );
    expect(
      DeletedUserProfile.displayName(isDeleted: false, fallbackName: '   '),
      'Utilisateur',
    );
    expect(
      DeletedUserProfile.displayName(isDeleted: false, fallbackName: ' Alice '),
      'Alice',
    );
  });

  testWidgets('widgets utilisateur supprimé respectent leurs paramètres', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 18, color: Colors.purple);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              DeletedUserAvatar(radius: 30, iconSize: 12),
              DeletedUserIdentity(radius: 18, spacing: 7, textStyle: style),
              DeletedUserNotice(),
            ],
          ),
        ),
      ),
    );

    final avatars = tester.widgetList<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatars.first.radius, 30);
    final firstIcon =
        tester.widget<Icon>(find.byIcon(Icons.person_off_rounded).first);
    expect(firstIcon.size, 12);
    expect(find.text(DeletedUserProfile.label), findsNWidgets(2));

    final identityText = tester.widget<Text>(
      find.text(DeletedUserProfile.label).first,
    );
    expect(identityText.style, style);
    expect(find.byType(DeletedUserNotice), findsOneWidget);
  });

  testWidgets('PrestoTapScale transmet le tap et garde son enfant', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrestoTapScale(
          onTap: () => taps += 1,
          child: const Text('Touchez-moi'),
        ),
      ),
    );

    expect(find.text('Touchez-moi'), findsOneWidget);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, const Duration(milliseconds: 120));

    await tester.tap(find.text('Touchez-moi'));
    expect(taps, 1);
  });

  testWidgets('HomeCategoryChip expose style, label et callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeCategoryChip(
            icon: Icons.build,
            label: 'Bricolage',
            iconScale: 1.25,
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.text('Bricolage'), findsOneWidget);
    expect(find.byIcon(Icons.build), findsOneWidget);
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(HomeCategoryChip),
        matching: find.byType(Transform),
      ).first,
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.25, 0.001));

    await tester.tap(find.text('Bricolage'));
    expect(taps, 1);
  });

  testWidgets('cloche de notification gère zéro, unité et plafonnement', (
    tester,
  ) async {
    Future<void> pumpBell(int count, {bool background = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrestoNotificationBellBase(
              badgeCount: count,
              showBackground: background,
              iconColor: Colors.blue,
            ),
          ),
        ),
      );
    }

    await pumpBell(0, background: false);
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.notifications_none_outlined)).color,
      Colors.blue,
    );

    await pumpBell(4);
    expect(find.text('4'), findsOneWidget);

    await pumpBell(12);
    expect(find.text('9+'), findsOneWidget);
  });

  test('HomeSlide conserve ses données', () {
    const slide = HomeSlide(
      title: 'Titre',
      subtitle: 'Sous-titre',
      badge: 'Nouveau',
      icon: Icons.star,
      imageAsset: 'assets/example.png',
    );

    expect(slide.title, 'Titre');
    expect(slide.subtitle, 'Sous-titre');
    expect(slide.badge, 'Nouveau');
    expect(slide.icon, Icons.star);
    expect(slide.imageAsset, 'assets/example.png');
  });
}
