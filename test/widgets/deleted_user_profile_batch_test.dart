import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';

void main() {
  group('DeletedUserProfile', () {
    test('détecte toutes les formes de compte supprimé', () {
      expect(DeletedUserProfile.isDeletedMap(null), isTrue);
      expect(DeletedUserProfile.isDeletedMap(<String, dynamic>{}), isFalse);

      for (final data in <Map<String, dynamic>>[
        <String, dynamic>{'deletedAt': DateTime(2026)},
        <String, dynamic>{'accountDeleted': true},
        <String, dynamic>{'isDeleted': true},
        <String, dynamic>{'disabled': true},
        <String, dynamic>{'anonymized': true},
        <String, dynamic>{'status': ' DELETED '},
        <String, dynamic>{'status': 'removed'},
        <String, dynamic>{'accountStatus': 'disabled'},
        <String, dynamic>{'accountStatus': 'anonymized'},
      ]) {
        expect(DeletedUserProfile.isDeletedMap(data), isTrue, reason: '$data');
      }
    });

    test('résout le nom affiché selon l état du compte', () {
      expect(
        DeletedUserProfile.displayName(isDeleted: true, fallbackName: 'Stef'),
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
        DeletedUserProfile.displayName(
          isDeleted: false,
          fallbackName: '  Stef  ',
        ),
        'Stef',
      );
    });
  });

  testWidgets('rend avatar, identité et notice avec leurs options', (tester) async {
    const style = TextStyle(fontSize: 18, fontWeight: FontWeight.w900);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DeletedUserAvatar(radius: 30, iconSize: 17),
              DeletedUserIdentity(radius: 20, spacing: 6, textStyle: style),
              DeletedUserNotice(),
            ],
          ),
        ),
      ),
    );

    final avatars = tester.widgetList<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatars.length, 3);
    expect(avatars.first.radius, 30);

    final icons = tester.widgetList<Icon>(find.byIcon(Icons.person_off_rounded));
    expect(icons.first.size, 17);
    expect(find.text(DeletedUserProfile.label), findsNWidgets(2));

    final identityText = tester.widgetList<Text>(
      find.text(DeletedUserProfile.label),
    ).first;
    expect(identityText.style, style);
    expect(find.byType(DeletedUserNotice), findsOneWidget);
  });
}
