import 'api_result.dart';
import 'api_summary_models.dart';

class ActiveInactiveTotals {
  const ActiveInactiveTotals({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;

  static ActiveInactiveTotals resolve<T>({
    required ApiListMeta<ActiveInactiveSummary> meta,
    required Iterable<T> items,
    required bool Function(T item) isActive,
  }) {
    final resolvedItems = items.toList(growable: false);
    final totalCount = meta.total == 0 ? resolvedItems.length : meta.total;
    final activeCount =
        meta.summary?.activeCount ??
        resolvedItems.where(isActive).length;
    final inactiveCount =
        meta.summary?.inactiveCount ?? (totalCount - activeCount);

    return ActiveInactiveTotals(
      totalCount: totalCount,
      activeCount: activeCount,
      inactiveCount: inactiveCount,
    );
  }
}
