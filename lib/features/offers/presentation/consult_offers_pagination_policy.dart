/// Règles pures de pagination de la consultation des annonces.
///
/// Cette classe ne dépend ni de Flutter ni de Firebase afin que les décisions
/// de chargement restent déterministes et entièrement testables.
class ConsultOffersPaginationPolicy {
  const ConsultOffersPaginationPolicy({
    this.initialLimit = 20,
    this.pageSize = 20,
    this.maxLimit = 100,
    this.triggerDistancePx = 500,
    this.requestThrottle = const Duration(milliseconds: 450),
  })  : assert(initialLimit > 0),
        assert(pageSize > 0),
        assert(maxLimit >= initialLimit),
        assert(triggerDistancePx >= 0);

  final int initialLimit;
  final int pageSize;
  final int maxLimit;
  final double triggerDistancePx;
  final Duration requestThrottle;

  bool shouldRequestNextPage({
    required bool hasActiveClientFilters,
    required bool isLoading,
    required bool hasMore,
    required bool hasCursor,
    required int loadedCount,
    required double pixels,
    required double maxScrollExtent,
    required DateTime now,
    DateTime? lastRequestAt,
  }) {
    if (hasActiveClientFilters || isLoading || !hasMore || !hasCursor) {
      return false;
    }
    if (loadedCount >= maxLimit) return false;
    if (maxScrollExtent - pixels > triggerDistancePx) return false;
    if (lastRequestAt != null &&
        now.difference(lastRequestAt) <= requestThrottle) {
      return false;
    }
    return true;
  }

  int nextPageLimit(int loadedCount) {
    final remaining = maxLimit - loadedCount;
    if (remaining <= 0) return 0;
    return remaining < pageSize ? remaining : pageSize;
  }

  bool hasMoreAfterPage({
    required int receivedCount,
    required int requestedLimit,
    required int totalLoadedCount,
  }) {
    if (requestedLimit <= 0) return false;
    return receivedCount == requestedLimit && totalLoadedCount < maxLimit;
  }
}
