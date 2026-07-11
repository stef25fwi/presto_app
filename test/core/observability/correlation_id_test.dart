import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/observability/correlation_id.dart';

void main() {
  test('normalise uniquement les identifiants sûrs', () {
    expect(normalizeCorrelationId(' request-1234 '), 'request-1234');
    expect(normalizeCorrelationId('short'), isNull);
    expect(normalizeCorrelationId('invalid id'), isNull);
    expect(normalizeCorrelationId('<script>alert(1)</script>'), isNull);
  });

  test('génère un identifiant déterministe et sûr', () {
    var call = 0;
    final id = createCorrelationId(
      clock: () => DateTime.utc(2026, 7, 11, 23),
      nextInt: (_) => <int>[1, 2, 3][call++],
    );

    expect(id, startsWith('client-'));
    expect(normalizeCorrelationId(id), id);
    expect(id.length, lessThanOrEqualTo(80));
  });

  test('conserve une valeur valide ou en génère une nouvelle', () {
    expect(resolveCorrelationId('request-1234'), 'request-1234');
    final generated = resolveCorrelationId(
      '',
      clock: () => DateTime.utc(2026, 7, 11, 23),
      nextInt: (_) => 42,
    );
    expect(normalizeCorrelationId(generated), generated);
  });
}
