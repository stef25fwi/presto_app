class AdminMessagingPaginationPolicy {
  const AdminMessagingPaginationPolicy({
    this.defaultPageSize = 40,
    this.maximumPageSize = 100,
  })  : assert(defaultPageSize > 0),
        assert(maximumPageSize >= defaultPageSize);

  final int defaultPageSize;
  final int maximumPageSize;

  int normalizePageSize(int requestedPageSize) {
    if (requestedPageSize <= 0) return defaultPageSize;
    if (requestedPageSize > maximumPageSize) return maximumPageSize;
    return requestedPageSize;
  }

  int queryLimit(int requestedPageSize) {
    return normalizePageSize(requestedPageSize) + 1;
  }

  bool hasMore({
    required int receivedCount,
    required int requestedPageSize,
  }) {
    return receivedCount > normalizePageSize(requestedPageSize);
  }

  List<T> visibleItems<T>(
    Iterable<T> items, {
    required int requestedPageSize,
  }) {
    return List<T>.unmodifiable(
      items.take(normalizePageSize(requestedPageSize)),
    );
  }
}
