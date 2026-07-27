import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';

void main() {
  testWidgets('rend les variantes par défaut du profil supprimé', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DeletedUserAvatar(radius: 20),
              DeletedUserIdentity(),
              DeletedUserNotice(),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_off_rounded), findsNWidgets(3));
    expect(find.text(DeletedUserProfile.label), findsNWidgets(2));

    final firstIcon = tester.widget<Icon>(
      find.byIcon(Icons.person_off_rounded).first,
    );
    expect(firstIcon.size, 20);
  });
}
