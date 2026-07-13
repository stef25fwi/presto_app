import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/consult_offers_pagination_policy.dart';

void main() {
  const policy = ConsultOffersPaginationPolicy();
  final now = DateTime.utc(2026, 7, 11, 14);

  group('shouldRequestNextPage', () {
    test('autorise le chargement près du bas avec un curseur valide', () {
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: true,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1600,
          maxScrollExtent: 2000,
          now: now,
        ),
        isTrue,
      );
    });

    test('bloque les états incompatibles avec une page suivante', () {
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: true,
          isLoading: false,
          hasMore: true,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: true,
          hasMore: true,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: false,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: true,
          hasCursor: false,
          loadedCount: 20,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
        ),
        isFalse,
      );
    });

    test('respecte la distance, le plafond et le throttle', () {
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: true,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1000,
          maxScrollExtent: 2000,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: true,
          hasCursor: true,
          loadedCount: 100,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: true,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
          lastRequestAt: now.subtract(const Duration(milliseconds: 450)),
        ),
        isFalse,
      );
      expect(
        policy.shouldRequestNextPage(
          hasActiveClientFilters: false,
          isLoading: false,
          hasMore: true,
          hasCursor: true,
          loadedCount: 20,
          pixels: 1900,
          maxScrollExtent: 2000,
          now: now,
          lastRequestAt: now.subtract(const Duration(milliseconds: 451)),
        ),
        isTrue,
      );
    });
  });

  test('calcule une taille de page bornée par le plafond', () {
    expect(policy.nextPageLimit(0), 20);
    expect(policy.nextPageLimit(80), 20);
    expect(policy.nextPageLimit(93), 7);
    expect(policy.nextPageLimit(100), 0);
    expect(policy.nextPageLimit(120), 0);
  });

  test('détermine correctement la présence d une page suivante', () {
    expect(
      policy.hasMoreAfterPage(
        receivedCount: 20,
        requestedLimit: 20,
        totalLoadedCount: 40,
      ),
      isTrue,
    );
    expect(
      policy.hasMoreAfterPage(
        receivedCount: 12,
        requestedLimit: 20,
        totalLoadedCount: 32,
      ),
      isFalse,
    );
    expect(
      policy.hasMoreAfterPage(
        receivedCount: 20,
        requestedLimit: 20,
        totalLoadedCount: 100,
      ),
      isFalse,
    );
  });
}
