import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_broadcast_service.dart';

void main() {
  test('BroadcastResult conserve les compteurs entiers', () {
    final result = BroadcastResult.fromMap(<String, dynamic>{
      'userCount': 12,
      'tokenCount': 18,
      'successCount': 16,
      'failureCount': 2,
      'totalUsers': 20,
    });

    expect(result.userCount, 12);
    expect(result.tokenCount, 18);
    expect(result.successCount, 16);
    expect(result.failureCount, 2);
    expect(result.totalUsers, 20);
  });

  test('BroadcastResult convertit les valeurs numériques décimales', () {
    final result = BroadcastResult.fromMap(<String, dynamic>{
      'userCount': 3.9,
      'tokenCount': 4.1,
      'successCount': 2.8,
      'failureCount': 1.2,
      'totalUsers': 5.7,
    });

    expect(result.userCount, 3);
    expect(result.tokenCount, 4);
    expect(result.successCount, 2);
    expect(result.failureCount, 1);
    expect(result.totalUsers, 5);
  });

  test('BroadcastResult remplace les valeurs absentes ou invalides par zéro', () {
    final result = BroadcastResult.fromMap(<String, dynamic>{
      'userCount': '12',
      'tokenCount': null,
      'successCount': true,
    });

    expect(result.userCount, 0);
    expect(result.tokenCount, 0);
    expect(result.successCount, 0);
    expect(result.failureCount, 0);
    expect(result.totalUsers, 0);
  });
}
