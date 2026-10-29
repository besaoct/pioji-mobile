import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../samples/domain/sample.dart';

const kBatchCap = 48;

class Batch {
  const Batch({required this.id, required this.name, this.date, required this.open, this.notes, this.sampleCount, this.samples = const []});

  final int id;
  final String name;
  final DateTime? date;
  final bool open;
  final String? notes;
  final int? sampleCount;
  final List<Sample> samples;

  int get count => sampleCount ?? samples.length;

  factory Batch.fromJson(Map<String, dynamic> j) {
    final samples = (j['samples'] is List ? j['samples'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(Sample.fromJson)
        .toList();
    return Batch(
      id: J.intOr(j['id'], 0),
      name: J.str(j['batch_name']) ?? J.str(j['name']) ?? 'Batch #${j['id']}',
      date: J.date(j['batch_date'] ?? j['date']),
      open: (J.str(j['status']) ?? 'open') == 'open',
      notes: J.str(j['notes']),
      sampleCount: J.integer(j['samples_count'] ?? j['sample_count']),
      samples: samples,
    );
  }
}

class BatchesRepository {
  const BatchesRepository(this._api);
  final Api _api;

  Future<Page<Batch>> list(ListQuery q, {int page = 1}) =>
      _api.page('/batches', Batch.fromJson, query: q.toQuery(), page: page);

  Future<void> create({String? name, required DateTime date, required bool open, String? notes, required List<int> sampleIds}) =>
      _api.post('/batches', cleanBody({
        'batch_name': name,
        'batch_date': Fmt.api(date),
        'status': open ? 'open' : 'closed',
        'notes': notes,
        'sample_ids': sampleIds,
      }));

  /// Returns the batches the server created, when it reports them.
  Future<List<Batch>> createForDate(DateTime date) async {
    final data = await _api.post('/batches/create-for-date', {'date': Fmt.api(date)});
    final list = data is List ? data : (J.map(data)?['batches'] as List? ?? const []);
    return list.whereType<Map<String, dynamic>>().map(Batch.fromJson).toList();
  }

  Future<List<Sample>> unbatched(DateTime date) async {
    final data = await _api.getData('/batches/unbatched-samples', query: {'date': Fmt.api(date)});
    final node = data is Map<String, dynamic> ? (data['samples'] ?? data['data']) : data;
    return (node is List ? node : const []).whereType<Map<String, dynamic>>().map(Sample.fromJson).toList();
  }
}

final batchesRepositoryProvider = Provider((ref) => BatchesRepository(ref.watch(apiProvider)));
final batchesQueryProvider = ListQueryProvider(ListQueryNotifier.new);
final batchesListProvider = pagedProvider<Batch>(
  batchesQueryProvider,
  (ref, q, page) => ref.read(batchesRepositoryProvider).list(q, page: page),
);

final unbatchedProvider = FutureProvider.family<List<Sample>, DateTime>(
  (ref, date) => ref.read(batchesRepositoryProvider).unbatched(date),
);
