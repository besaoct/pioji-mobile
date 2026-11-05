import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';

class OfferList {
  const OfferList({
    required this.id,
    this.date,
    this.gardenId,
    this.gardenName,
    this.grade,
    this.invPrefix,
    this.invNo,
    this.pkgs,
    this.nett,
    this.totalKgs,
    this.grossWeight,
    this.packingDate,
    this.type,
    this.price,
    this.currency,
    this.promptDays,
    this.parties = const [],
    this.buyers = const [],
  });

  final int id;
  final DateTime? date;
  final int? gardenId;
  final String? gardenName;
  final String? grade;
  final String? invPrefix;
  final String? invNo;
  final double? pkgs;
  final double? nett;
  final double? totalKgs;
  final double? grossWeight;
  final DateTime? packingDate;
  final String? type;
  final double? price;
  final String? currency;
  final int? promptDays;
  /// party_1 … party_10, filled ones only, in order.
  final List<String> parties;
  final List<String> buyers;

  String get title => [gardenName ?? 'Garden #${gardenId ?? '–'}', ?grade].join(' · ');

  factory OfferList.fromJson(Map<String, dynamic> j) => OfferList(
        id: J.intOr(j['id'], 0),
        date: J.date(j['date']),
        gardenId: J.integer(j['garden_id']),
        gardenName: J.nested(j, 'garden_name', 'garden', 'garden_name'),
        grade: J.code(j['grade']),
        invPrefix: J.str(j['inv_prefix']) ?? J.str(j['inv_pretx']),
        invNo: J.str(j['inv_no']),
        pkgs: J.dbl(j['pkgs']),
        nett: J.dbl(j['nett']),
        totalKgs: J.dbl(j['ttl_kgs']),
        grossWeight: J.dbl(j['gross_weight']),
        packingDate: J.date(j['d_o_packing']),
        type: J.str(j['type']),
        price: J.dbl(j['price']),
        currency: J.str(j['currency']),
        promptDays: J.integer(j['prompt_days']),
        parties: [
          for (var i = 1; i <= 10; i++)
            if ((J.str(j['party_$i']) ?? '').trim().isNotEmpty) J.str(j['party_$i'])!.trim(),
        ],
        buyers: (j['buyers'] is List ? j['buyers'] as List : const [])
            .map((b) => b is Map ? J.str(b['name']) : J.str(b))
            .whereType<String>()
            .toList(),
      );
}

class OfferListsRepository {
  const OfferListsRepository(this._api);
  final Api _api;

  Future<OfferList> get(int id) async => OfferList.fromJson(await _api.one('/offer-lists/$id'));

  Future<void> delete(int id) => _api.delete('/offer-lists/$id');

  Future<Page<OfferList>> list(ListQuery q, {int page = 1}) =>
      _api.page('/offer-lists', OfferList.fromJson, query: q.toQuery(), page: page);

  Future<void> create(Map<String, Object?> body) => _api.post('/offer-lists', cleanBody(body));
}

final offerListsRepositoryProvider = Provider((ref) => OfferListsRepository(ref.watch(apiProvider)));
final offerListsQueryProvider = ListQueryProvider(ListQueryNotifier.new);
final offerListsListProvider = pagedProvider<OfferList>(
  offerListsQueryProvider,
  (ref, q, page) => ref.read(offerListsRepositoryProvider).list(q, page: page),
);
