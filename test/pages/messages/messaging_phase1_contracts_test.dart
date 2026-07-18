import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_center_page.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

void main() {
  test('décrit les requêtes de conversations', () {
    final adminShape = ConversationsQueryContract.shape(
      isAdminMode: true,
      userId: 'admin-1',
    );
    expect(adminShape['limit'], 50);
    expect(adminShape['participantField'], isNull);

    final userShape = ConversationsQueryContract.shape(
      isAdminMode: false,
      userId: 'user-42',
    );
    expect(userShape['participantField'], 'participantIds');
    expect(userShape['participantValue'], 'user-42');
    expect(userShape['limit'], isNull);
  });

  test('chaque section possède un libellé et une icône', () {
    for (final section in AdminMessagingSection.values) {
      expect(section.label, isNotEmpty);
      expect(section.icon, isA<IconData>());
    }
  });
}
