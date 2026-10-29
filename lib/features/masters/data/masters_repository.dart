import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/json.dart';

/// A pickable record: garden, buyer, seller, courier service, address, user.
class MasterItem {
  const MasterItem(this.id, this.name, {this.subtitle});
  final int id;
  final String name;
  final String? subtitle;

  static MasterItem? fromJson(Map<String, dynamic> j) {
    final id = J.integer(j['id']);
    if (id == null) return null;
    final name = J.str(j['name']) ??
        J.str(j['garden_name']) ??
        J.str(j['company_name']) ??
        J.str(j['buyer_name']) ??
        J.str(j['title']) ??
        J.str(j['address']) ??
        '#$id';
    return MasterItem(id, name, subtitle: J.str(j['city']) ?? J.str(j['email']));
  }
}

/// Lookup lists for pickers. Most of these endpoints aren't on the backend
/// yet (see FLUTTER_IMPLEMENTATION.md §18.2); an empty list makes the picker
/// fall back to typing an ID.
class MastersRepository {
  const MastersRepository(this._api);
  final Api _api;

  Future<List<MasterItem>> list(String path, {String? key}) async {
    try {
      final data = await _api.getData(path, query: const {'per_page': 500});
      return _items(key == null ? data : (J.map(data)?[key]));
    } catch (_) {
      return const [];
    }
  }

  Future<List<MasterItem>> buyers() async {
    final direct = await list('/buyers');
    if (direct.isNotEmpty) return direct;
    // Fallback: today's allocation grid includes the buyer list.
    return list('/samples-offered-today', key: 'available_buyers');
  }

  Future<({List<MasterItem> services, List<MasterItem> addresses})> courierOptions() async {
    try {
      final data = J.map(await _api.getData('/courier-entries/services')) ?? const {};
      return (
        services: _items(data['courier_services'] ?? data['services']),
        addresses: _items(data['courier_addresses'] ?? data['addresses'] ?? data['custom_addresses']),
      );
    } catch (_) {
      return (services: const <MasterItem>[], addresses: const <MasterItem>[]);
    }
  }

  List<MasterItem> _items(Object? node) {
    if (node is Map<String, dynamic> && node['data'] is List) node = node['data'];
    if (node is! List) return const [];
    return node.whereType<Map<String, dynamic>>().map(MasterItem.fromJson).whereType<MasterItem>().toList();
  }
}

final mastersRepositoryProvider = Provider((ref) => MastersRepository(ref.watch(apiProvider)));

final gardensProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/gardens'));
final buyersProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).buyers());
final sellersProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/sellers'));
final negotiatorsProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/negotiators'));
final postingListsProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/posting-lists'));
final courierOptionsProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).courierOptions());

/// Grades used across the business. Replace with `GET /grades` when it exists.
const kTeaGrades = ['BOP', 'BOPSM', 'BP', 'OF', 'PD', 'Dust', 'FOP', 'OP', 'PEKOE'];
