import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';

/// A pickable record: garden, buyer, seller, courier service, address, user,
/// posting list.
class MasterItem {
  const MasterItem(this.id, this.name, {this.subtitle});
  final int id;
  final String name;
  final String? subtitle;

  static MasterItem? fromJson(Map<String, dynamic> j) {
    final id = J.integer(j['id']);
    if (id == null) return null;
    final name = J.str(j['garden_name']) ??
        J.str(j['buyer_name']) ??
        J.str(j['seller_name']) ??
        J.str(j['company_name']) ??
        J.str(j['address_title']) ??
        J.str(j['name']) ??
        J.str(j['title']) ??
        '#$id';
    final subtitle = J.str(j['city']) ??
        J.str(j['tea_estate_name']) ??
        J.str(j['contact_person']) ??
        J.str(j['email']);
    return MasterItem(id, name, subtitle: subtitle == name ? null : subtitle);
  }

  static List<MasterItem> listFrom(Object? node) {
    if (node is Map<String, dynamic>) {
      return Page.parse<MasterItem?>(node, MasterItem.fromJson).items.whereType<MasterItem>().toList();
    }
    if (node is! List) return const [];
    return node.whereType<Map<String, dynamic>>().map(MasterItem.fromJson).whereType<MasterItem>().toList();
  }
}

/// Lookup lists for pickers. A failure returns an empty list, which makes the
/// picker fall back to typing an ID.
class MastersRepository {
  const MastersRepository(this._api);
  final Api _api;

  /// Every page of a small list (buyers, sellers, negotiators, posting lists).
  Future<List<MasterItem>> list(String path) async {
    try {
      final out = <MasterItem>[];
      var page = 1;
      while (page <= 10) {
        final p = await _api.page<MasterItem?>(path, MasterItem.fromJson, page: page, perPage: 100);
        out.addAll(p.items.whereType<MasterItem>());
        if (!p.hasMore) break;
        page++;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Server-side search for large lists (gardens: 2,000+ records).
  Future<List<MasterItem>> search(String path, String query) async {
    try {
      final p = await _api.page<MasterItem?>(path, MasterItem.fromJson, query: {'search': query}, perPage: 30);
      return p.items.whereType<MasterItem>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Grade codes from `GET /grades` (`grade_name`/`grade_code`), every page.
  Future<List<String>> grades() async {
    try {
      final names = <String>{};
      var page = 1;
      while (page <= 10) {
        final p = await _api.page<String?>(
          '/grades',
          (g) => J.str(g['grade_name']) ?? J.str(g['grade_code']) ?? J.str(g['name']),
          page: page,
          perPage: 100,
        );
        names.addAll(p.items.whereType<String>());
        if (!p.hasMore) break;
        page++;
      }
      final list = names.toList()..sort();
      return list.isEmpty ? kTeaGrades : list;
    } catch (_) {
      return kTeaGrades;
    }
  }

  /// Quick-register a buyer or seller by name (`POST /buyers`, `POST /sellers`).
  /// The server fills the rest (code, type, placeholder email).
  Future<MasterItem> create(String path, String nameKey, String name) async {
    final data = J.map(await _api.post(path, {nameKey: name})) ?? const {};
    final record = data.containsKey('id') ? data : data.values.whereType<Map<String, dynamic>>().firstWhere((v) => v.containsKey('id'), orElse: () => const {});
    return MasterItem.fromJson(record) ?? (throw StateError('The server did not return the new record.'));
  }

  Future<List<MasterItem>> buyers() async {
    final direct = await list('/buyers');
    if (direct.isNotEmpty) return direct;
    // Fallback: today's allocation grid includes the buyer list.
    try {
      final data = J.map(await _api.getData('/samples-offered-today')) ?? const {};
      return MasterItem.listFrom(data['available_buyers']);
    } catch (_) {
      return const [];
    }
  }

  Future<({List<MasterItem> services, List<MasterItem> addresses})> courierOptions() async {
    try {
      final data = J.map(await _api.getData('/courier-entries/services')) ?? const {};
      return (
        services: MasterItem.listFrom(data['courier_services']),
        addresses: MasterItem.listFrom(data['courier_addresses']),
      );
    } catch (_) {
      return (services: const <MasterItem>[], addresses: const <MasterItem>[]);
    }
  }
}

final mastersRepositoryProvider = Provider((ref) => MastersRepository(ref.watch(apiProvider)));

/// First page of gardens; the picker searches the server as you type.
final gardensProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).search('/gardens', ''));
final buyersProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).buyers());
final sellersProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/sellers'));
final negotiatorsProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/negotiators'));
final postingListsProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).list('/posting-lists'));
final courierOptionsProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).courierOptions());
final gradesProvider = FutureProvider((ref) => ref.read(mastersRepositoryProvider).grades());

/// Fallback grades, used when `GET /grades` returns nothing, and for the
/// grade filter on list screens.
const kTeaGrades = ['BOP', 'BOPSM', 'BP', 'OF', 'PD', 'Dust', 'FOP', 'OP', 'PEKOE'];
