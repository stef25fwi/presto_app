import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/consult_offers_pager.dart';
import 'package:presto_app/features/offers/presentation/consult_offers_pagination_policy.dart';

void main() {
  ConsultOffersPager<int> pagerWith(
    Future<List<int>> Function(int, int) fetch, {
    int pageSize = 20,
  }) => ConsultOffersPager<int>(
        idOf: (doc) => '$doc',
        fetchPage: fetch,
        pageSize: pageSize,
      );

  void seed(ConsultOffersPager<int> pager, List<int> page, {List<int>? shown}) {
    pager.seed(
      requestGeneration: pager.generation,
      canonicalPage: page,
      displayedPage: shown ?? page,
    );
  }

  test('les filtres peuvent trouver une annonce après les 100 premières', () async {
    final all = List.generate(127, (index) => index);
    final limits = <int>[];
    final cursors = <int>[];
    final pager = pagerWith((cursor, limit) async {
      cursors.add(cursor);
      limits.add(limit);
      return all.skip(cursor + 1).take(limit).toList();
    });
    pager.reset('mot-cle');
    seed(pager, all.take(20).toList());
    const policy = ConsultOffersPaginationPolicy();
    var pageRequests = 0;
    while (pager.hasMore && pageRequests < 10) {
      expect(policy.shouldRequestNextPage(
        hasActiveClientFilters: true,
        isLoading: pager.loading,
        hasMore: pager.hasMore,
        hasCursor: pager.cursor != null,
        loadedCount: pager.docs.length,
        pixels: 0,
        maxScrollExtent: 0,
        now: DateTime.utc(2026),
      ), isTrue);
      expect(await pager.loadNext(), isTrue);
      pageRequests++;
    }
    expect(pager.docs.where((doc) => doc == 125), [125]);
    expect(pager.docs, all);
    expect(cursors, [19, 39, 59, 79, 99, 119]);
    expect(limits, everyElement(20));
    expect(pager.hasMore, isFalse);
    expect(await pager.loadNext(), isFalse);
    expect(consultOffersResultLabel(count: 1, initialized: true,
      hasMore: pager.hasMore), '1 annonce affichée');
  });

  test('le curseur reste canonique malgré des documents legacy fusionnés', () async {
    int? requestedAfter;
    final pager = pagerWith((cursor, limit) async {
      requestedAfter = cursor;
      return [2, 3];
    }, pageSize: 2);
    pager.reset('all');
    seed(pager, [1, 2], shown: [1, 2, 999]);
    expect(await pager.loadNext(), isTrue);
    expect(requestedAfter, 2);
    expect(pager.docs, [1, 2, 999, 3]);
    expect(pager.cursor, 3);
  });

  test('une page vide termine une série de pages pleines', () async {
    final pager = pagerWith((_, __) async => [], pageSize: 2);
    seed(pager, [1, 2]);
    expect(await pager.loadNext(), isTrue);
    expect(pager.docs, [1, 2]);
    expect(pager.hasMore, isFalse);
  });

  test('un échec conserve la page et le curseur pour réessayer', () async {
    var attempts = 0;
    final pager = pagerWith((cursor, _) async {
      expect(cursor, 2);
      if (attempts++ == 0) throw StateError('offline');
      return [3];
    }, pageSize: 2);
    seed(pager, [1, 2]);
    expect(await pager.loadNext(), isFalse);
    expect(pager.error, isA<StateError>());
    expect(pager.docs, [1, 2]);
    expect(pager.hasMore, isTrue);
    expect(pager.loading, isFalse);
    expect(await pager.loadNext(), isTrue);
    expect(pager.error, isNull);
    expect(pager.docs, [1, 2, 3]);
    expect(pager.hasMore, isFalse);
  });

  test('les appels simultanés ne doublent pas les lectures', () async {
    final response = Completer<List<int>>();
    var calls = 0;
    final pager = pagerWith((_, __) {
      calls++;
      return response.future;
    }, pageSize: 2);
    seed(pager, [1, 2]);
    final pending = pager.loadNext();
    expect(pager.loading, isTrue);
    expect(await pager.loadNext(), isFalse);
    expect(calls, 1);
    response.complete([3]);
    expect(await pending, isTrue);
  });

  for (final sameKey in [false, true]) {
    test('ignore une ancienne réponse après ${sameKey ? 'actualisation' : 'filtrage'}', () async {
      final oldResponse = Completer<List<int>>();
      final newResponse = Completer<List<int>>();
      final pager = pagerWith((cursor, _) =>
        cursor == 2 ? oldResponse.future : newResponse.future, pageSize: 2);
      pager.reset('initial');
      seed(pager, [1, 2]);
      final oldGeneration = pager.generation;
      final oldLoad = pager.loadNext();
      pager.reset(sameKey ? 'initial' : 'nouveau');
      seed(pager, [10, 11]);
      final newLoad = pager.loadNext();
      oldResponse.complete([3, 4]);
      expect(await oldLoad, isFalse);
      pager.seed(requestGeneration: oldGeneration,
        canonicalPage: [1, 2], displayedPage: [1, 2]);
      expect(pager.docs, [10, 11]);
      expect(pager.loading, isTrue);
      newResponse.complete([12]);
      expect(await newLoad, isTrue);
      expect(pager.docs, [10, 11, 12]);
      expect(pager.loading, isFalse);
    });
  }

  test('refuse un curseur qui ne progresse pas', () async {
    final pager = pagerWith((_, __) async => [1, 2], pageSize: 2);
    seed(pager, [1, 2]);
    expect(await pager.loadNext(), isFalse);
    expect(pager.error, isA<StateError>());
    expect(pager.docs, [1, 2]);
  });

  test('le compteur distingue chargement, résultats partiels et fin', () {
    expect(consultOffersResultLabel(count: 0, initialized: false, hasMore: false),
      'Chargement des annonces…');
    expect(consultOffersResultLabel(count: 0, initialized: true, hasMore: true),
      '0 annonce affichée · résultats partiels');
    expect(consultOffersResultLabel(count: 20, initialized: true, hasMore: true),
      '20 annonces affichées · résultats partiels');
    expect(consultOffersResultLabel(count: 0, initialized: true, hasMore: false),
      '0 annonce affichée');
  });
}
