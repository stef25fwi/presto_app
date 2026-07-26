import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';

void main() {
  testWidgets('applique le style personnalisé à l identité supprimée',
      (tester) async {
    const customStyle = TextStyle(
      color: Colors.purple,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeletedUserIdentity(
            radius: 24,
            spacing: 12,
            textStyle: customStyle,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(DeletedUserProfile.label));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));

    expect(text.style, customStyle);
    expect(avatar.radius, 24);
    expect(find.byIcon(Icons.person_off_rounded), findsOneWidget);
  });

  testWidgets('affiche le panneau utilisateur supprimé', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DeletedUserNotice()),
      ),
    );

    expect(find.text(DeletedUserProfile.label), findsOneWidget);
    expect(find.byType(DeletedUserAvatar), findsOneWidget);
    expect(find.byIcon(Icons.person_off_rounded), findsOneWidget);
  });
}
