import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/shared/admin_bulk_listing_service.dart';

class _FakeFunctions implements FirebaseFunctions {
  String? requestedName;
  HttpsCallableOptions? requestedOptions;
  final _FakeCallable callable = _FakeCallable();

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    requestedName = name;
    requestedOptions = options;
    return callable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  dynamic receivedParameters;
  var calls = 0;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls += 1;
    receivedParameters = parameters;
    return _FakeCallableResult<T>(
      <String, Object?>{
        'ok': true,
        'correlationId': 'bulk-request-1',
        'adminActionId': 'bulk-action-1',
        'requestedCount': 1,
        'succeededCount': 1,
        'failedCount': 0,
        'results': <Object?>[
          <String, Object?>{'listingId': 'listing-1', 'ok': true},
        ],
      } as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  const _FakeCallableResult(this.data);

  @override
  final T data;
}

void main() {
  test('suppression groupée utilise le callable Firebase réel', () async {
    final functions = _FakeFunctions();
    final service = AdminBulkListingService(functions: functions);

    final summary = await service.deleteListings(
      listingIds: const <String>[' listing-1 '],
      reason: ' contenu expiré ',
      correlationId: 'bulk-request-1',
    );

    expect(functions.requestedName, 'adminBulkDeleteListings');
    expect(functions.requestedOptions?.timeout, const Duration(minutes: 5));
    expect(functions.callable.calls, 1);
    expect(functions.callable.receivedParameters, <String, Object?>{
      'listingIds': <String>['listing-1'],
      'reason': 'contenu expiré',
      'correlationId': 'bulk-request-1',
    });
    expect(summary.ok, isTrue);
    expect(summary.adminActionId, 'bulk-action-1');
    expect(summary.succeededIds, const <String>['listing-1']);
  });
}
