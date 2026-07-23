import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/firebase_contract.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

void main() {
  test('décrit distinctement les requêtes admin et participant', () {
    final admin = ConversationsQueryContract.shape(
      isAdminMode: true,
      userId: 'admin-user',
    );
    final participant = ConversationsQueryContract.shape(
      isAdminMode: false,
      userId: 'participant-user',
    );

    expect(admin['collection'], FirestoreCollections.conversations);
    expect(admin['participantField'], isNull);
    expect(admin['participantValue'], isNull);
    expect(admin['limit'], 50);

    expect(participant['collection'], FirestoreCollections.conversations);
    expect(participant['participantField'], 'participantIds');
    expect(participant['participantValue'], 'participant-user');
    expect(participant['limit'], isNull);
    expect(participant['orderBy'], 'updatedAt');
    expect(participant['descending'], isTrue);
  });
}
