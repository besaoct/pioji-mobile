import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';
import '../domain/sample.dart';

class SamplesRepository {
  const SamplesRepository(this._api);
  final Api _api;

  Future<Sample> get(int id) async => Sample.fromJson(await _api.one('/samples/$id'));

  Future<Page<Sample>> list(ListQuery q, {int page = 1, int perPage = 20}) =>
      _api.page('/samples', Sample.fromJson, query: q.toQuery(), page: page, perPage: perPage);

  Future<void> update(int id, Map<String, Object?> body) => _api.put('/samples/$id', body);

  Future<void> delete(int id) => _api.delete('/samples/$id');

  Future<Sample?> create(Map<String, Object?> body) async {
    final data = await _api.post('/samples', cleanBody(body));
    final map = J.map(data);
    return map == null ? null : Sample.fromJson(map);
  }
}

final samplesRepositoryProvider = Provider((ref) => SamplesRepository(ref.watch(apiProvider)));

final samplesQueryProvider = ListQueryProvider(ListQueryNotifier.new);

final samplesListProvider = pagedProvider<Sample>(
  samplesQueryProvider,
  (ref, q, page) => ref.read(samplesRepositoryProvider).list(q, page: page),
);
