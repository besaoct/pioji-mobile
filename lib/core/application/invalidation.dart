import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Providers that summarise data from several modules (Home). Features call
/// [refreshSummaries] after a write so counts never go stale.
final summaryRefreshProvider = NotifierProvider<SummaryTick, int>(SummaryTick.new);

class SummaryTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

void refreshSummaries(WidgetRef ref) => ref.read(summaryRefreshProvider.notifier).bump();
