import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/firestore_web_safe_reads.dart';

void main() {
  test('query polling emits the first Firestore snapshot', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('events').doc('event-1').set(
      const <String, dynamic>{'active': true},
    );

    final snapshot = await firestore
        .collection('events')
        .webSafeSnapshots(interval: Duration.zero)
        .first;

    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.single.data()['active'], isTrue);
  });

  test('document polling emits the first Firestore snapshot', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set(
      const <String, dynamic>{'name': 'Prestō'},
    );

    final snapshot = await firestore
        .collection('users')
        .doc('user-1')
        .webSafeSnapshots(interval: Duration.zero)
        .first;

    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['name'], 'Prestō');
  });
}
