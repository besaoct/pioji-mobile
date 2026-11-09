import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/list/list_query.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/json.dart';
import '../../allocation/data/allocation_repository.dart';
import '../../batches/data/batches_repository.dart';
import '../../bid_book/data/bid_book_repository.dart';
import '../../samples/data/samples_repository.dart';
import '../../samples/domain/sample.dart';

DateTime get _today => DateUtils.dateOnly(DateTime.now());

/// Counts from `GET /dashboard/summary`, one call for most of Home.
///
/// The sales count is left out on purpose: a sale split between buyers is
/// one row in the list but one record per split here. Value, kg and pending
/// match the list.
class DashboardSummary {
  const DashboardSummary({
    this.samplesToday,
    this.samplesTotal,
    this.openBids,
    this.exMismatched,
    this.exUnregistered,
    this.salesPending,
    this.salesAmount,
    this.salesKg,
  });

  final int? samplesToday;
  final int? samplesTotal;
  final int? openBids;
  final int? exMismatched;
  final int? exUnregistered;
  final int? salesPending;
  final double? salesAmount;
  final double? salesKg;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(String k) => J.map(j[k]) ?? const {};
    return DashboardSummary(
      samplesToday: J.integer(m('samples')['today']),
      samplesTotal: J.integer(m('samples')['total']),
      openBids: J.integer(m('bid_book')['open']),
      exMismatched: J.integer(m('ex_factory')['mismatched']),
      exUnregistered: J.integer(m('ex_factory')['unregistered']),
      salesPending: J.integer(m('sales_register')['pending']),
      salesAmount: J.dbl(m('sales_register')['total_amount']),
      salesKg: J.dbl(m('sales_register')['total_kg']),
    );
  }
}

/// Each Home number loads and fails on its own, and reloads after any write.
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  ref.watch(summaryRefreshProvider);
  return DashboardSummary.fromJson(J.map(await ref.read(apiProvider).getData('/dashboard/summary')) ?? const {});
});

final unbatchedTodayProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  return (await ref.read(batchesRepositoryProvider).unbatched(_today)).length;
});

final awaitingBidsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  final repo = ref.read(bidBookRepositoryProvider);
  return (await repo.list(const ListQuery(params: {'tab': 'awaiting_allocation'}))).total;
});

final unallocatedTodayProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  final d = await ref.read(allocationRepositoryProvider).load(_today);
  return [...d.offers, ...d.samples].where((i) => i.buyers.isEmpty).length;
});

final recentSamplesProvider = FutureProvider<List<Sample>>((ref) async {
  ref.watch(summaryRefreshProvider);
  return (await ref.read(samplesRepositoryProvider).list(const ListQuery(), perPage: 5)).items;
});

void refreshHome(WidgetRef ref) => refreshSummaries(ref);
