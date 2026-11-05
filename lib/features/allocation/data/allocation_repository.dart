import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../masters/data/masters_repository.dart';

enum ItemType {
  offerList('offer_list'),
  sample('sample');

  const ItemType(this.api);
  final String api;
}

class OfferedItem {
  const OfferedItem({required this.type, required this.id, required this.title, this.invoice, this.buyers = const []});

  final ItemType type;
  final int id;
  final String title;
  final String? invoice;
  final List<String> buyers;

  String get key => '${type.api}:$id';

  factory OfferedItem.fromJson(ItemType type, Map<String, dynamic> j) {
    final garden = J.nested(j, 'garden_name', 'garden', 'garden_name') ?? 'Lot #${j['id']}';
    final grade = J.code(j['grade']);
    // Samples carry `assigned_buyers[]`; offer lists carry one `buyer`.
    final single = J.map(j['buyer']);
    final buyersNode = j['assigned_buyers'] ?? j['buyers'] ?? j['allocated_buyers'] ?? (single == null ? null : [single]);
    return OfferedItem(
      type: type,
      id: J.intOr(j['id'], 0),
      title: [garden, ?grade].join(' · '),
      invoice: Fmt.invoice(
        J.code(j['inv_pretx']) ?? J.code(j['inv_prefix']) ?? J.code(j['invoice_prefix']),
        J.str(j['inv_no']) ?? J.str(j['invoice_no']),
      ),
      buyers: buyersNode is List
          ? buyersNode
              .map((b) => b is Map ? (J.str(b['buyer_name']) ?? J.str(b['name'])) : J.str(b))
              .whereType<String>()
              .toList()
          : const [],
    );
  }
}

class OfferedToday {
  const OfferedToday({required this.offers, required this.samples, required this.buyers});
  final List<OfferedItem> offers;
  final List<OfferedItem> samples;
  final List<MasterItem> buyers;
}

class AllocationRepository {
  const AllocationRepository(this._api);
  final Api _api;

  Future<OfferedToday> load(DateTime date) async {
    final data = J.map(await _api.getData('/samples-offered-today', query: {'date': Fmt.api(date)})) ?? const {};
    List<OfferedItem> items(Object? node, ItemType t) {
      if (node is Map<String, dynamic> && node['data'] is List) node = node['data'];
      return (node is List ? node : const []).whereType<Map<String, dynamic>>().map((j) => OfferedItem.fromJson(t, j)).toList();
    }

    final buyersNode = data['available_buyers'];
    return OfferedToday(
      offers: items(data['offer_lists'], ItemType.offerList),
      samples: items(data['samples'], ItemType.sample),
      buyers: (buyersNode is List ? buyersNode : const [])
          .whereType<Map<String, dynamic>>()
          .map(MasterItem.fromJson)
          .whereType<MasterItem>()
          .toList(),
    );
  }

  Future<void> allocate(List<OfferedItem> items, List<int> buyerIds) {
    if (items.length == 1) {
      return _api.post('/samples-offered-today/allocate-buyers', {
        'item_type': items.first.type.api,
        'item_id': items.first.id,
        'buyer_ids': buyerIds,
      });
    }
    return _api.post('/samples-offered-today/bulk-allocate-buyers', {
      'items': [for (final i in items) {'type': i.type.api, 'id': i.id}],
      'buyer_ids': buyerIds,
    });
  }
}

final allocationRepositoryProvider = Provider((ref) => AllocationRepository(ref.watch(apiProvider)));
final offeredTodayProvider = FutureProvider.family<OfferedToday, DateTime>(
  (ref, date) => ref.read(allocationRepositoryProvider).load(date),
);
