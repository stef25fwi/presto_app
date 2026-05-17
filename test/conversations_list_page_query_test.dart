import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

void main() {
  test('la query utilisateur repose sur participantIds puis updatedAt', () {
    final shape = ConversationsQueryContract.shape(
      isAdminMode: false,
      userId: 'user_1',
    );

    expect(shape['collection'], 'conversations');
    expect(shape['participantField'], 'participantIds');
    expect(shape['participantValue'], 'user_1');
    expect(shape['orderBy'], 'updatedAt');
    expect(shape['descending'], isTrue);
    expect(shape['limit'], isNull);
  });

  test('la query admin garde le tri updatedAt sans filtre participantIds', () {
    final shape = ConversationsQueryContract.shape(
      isAdminMode: true,
      userId: 'admin_1',
    );

    expect(shape['collection'], 'conversations');
    expect(shape['participantField'], isNull);
    expect(shape['participantValue'], isNull);
    expect(shape['orderBy'], 'updatedAt');
    expect(shape['descending'], isTrue);
    expect(shape['limit'], 50);
  });
}