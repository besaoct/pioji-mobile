import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/list/list_query.dart';
import '../../../core/utils/formatters.dart';
import '../../allocation/data/allocation_repository.dart';
import '../../batches/data/batches_repository.dart';
import '../../bid_book/data/bid_book_repository.dart';
import '../../ex_factory/data/ex_factory_repository.dart';
import '../../samples/data/samples_repository.dart';
import '../../samples/domain/sample.dart';

DateTime get _today => DateUtils.dateOnly(DateTime.now());

/// Each Home number loads and fails on its own, and reloads after any write.
final samplesTodayCountProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  final p = await ref.read(samplesRepositoryProvider).list(
        ListQuery(params: {'arrival_date': Fmt.api(_today)}),
        perPage: 1,
      );
  return p.total;
});

final unbatchedTodayProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  return (await ref.read(batchesRepositoryProvider).unbatched(_today)).length;
});

final openBidsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  final repo = ref.read(bidBookRepositoryProvider);
  return (await repo.list(const ListQuery(params: {'tab': 'open'}))).total;
});

final awaitingBidsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(summaryRefreshProvider);
  final repo = ref.read(bidBookRepositoryProvider);
  return (await repo.list(const ListQuery(params: {'tab': 'awaiting_allocation'}))).total;
});

final exMetricsHomeProvider = FutureProvider<Map<RegisterStatus, int>>((ref) async {
  ref.watch(summaryRefreshProvider);
  return ref.read(exFactoryRepositoryProvider).metrics();
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
