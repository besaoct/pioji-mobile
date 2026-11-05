import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/status_badge.dart';

enum BidStatus {
  open('open', 'Open', Tone.accent),
  parked('parked', 'Parked', Tone.warning),
  held('OK-BID HOLD', 'Held', Tone.warning),
  closed('closed', 'Closed', Tone.neutral);

  const BidStatus(this.api, this.label, this.tone);
  final String api;
  final String label;
  final Tone tone;

  static BidStatus parse(Object? v) => values.firstWhere((s) => s.api == v?.toString(), orElse: () => open);
}

class Bid {
  const Bid({
    required this.id,
    required this.gardenName,
    required this.grade,
    required this.invoiceNumber,
    this.packages,
    this.netWeight,
    this.incoming,
    this.maxBid,
    this.negotiated,
    this.pencil,
    this.status = BidStatus.open,
    this.buyerId,
    this.buyerName,
    this.negotiatorId,
    this.negotiatorName,
    this.remarks,
  });

  final int id;
  final String gardenName;
  final String grade;
  final String invoiceNumber;
  final int? packages;
  final double? netWeight;
  final double? incoming;
  final double? maxBid;
  final double? negotiated;
  final double? pencil;
  final BidStatus status;
  final int? buyerId;
  final String? buyerName;
  final int? negotiatorId;
  final String? negotiatorName;
  final String? remarks;

  factory Bid.fromJson(Map<String, dynamic> j) => Bid(
        id: J.intOr(j['id'], 0),
        gardenName: J.nested(j, 'garden_name', 'garden', 'garden_name') ?? '–',
        grade: J.str(j['grade']) ?? '–',
        invoiceNumber: J.str(j['invoice_number']) ?? '–',
        packages: J.integer(j['packages']),
        netWeight: J.dbl(j['net_weight']),
        incoming: J.dbl(j['seller_incoming_price']),
        maxBid: J.dbl(j['max_bid']),
        negotiated: J.dbl(j['negotiated_price']),
        pencil: J.dbl(j['pencil_price']),
        status: BidStatus.parse(j['status']),
        buyerId: J.integer(j['buyer_id']),
        buyerName: J.nested(j, 'buyer_name', 'buyer', 'buyer_name'),
        negotiatorId: J.integer(j['negotiator_id']),
        negotiatorName: J.nested(j, 'negotiator_name', 'negotiator'),
        remarks: J.str(j['remarks']),
      );
}

class BidBookRepository {
  const BidBookRepository(this._api);
  final Api _api;

  Future<Bid> get(int id) async => Bid.fromJson(await _api.one('/bid-book/$id'));

  Future<void> delete(int id) => _api.delete('/bid-book/$id');

  Future<Page<Bid>> list(ListQuery q, {int page = 1}) => _api.page('/bid-book', Bid.fromJson, query: q.toQuery(), page: page);

  Future<void> create(Map<String, Object?> body) => _api.post('/bid-book', cleanBody(body));

  Future<void> update(int id, Map<String, Object?> body) => _api.put('/bid-book/$id', body);
}

final bidBookRepositoryProvider = Provider((ref) => BidBookRepository(ref.watch(apiProvider)));
final bidBookQueryProvider = ListQueryProvider(() => ListQueryNotifier(const ListQuery(params: {'tab': 'open'})));
final bidBookListProvider = pagedProvider<Bid>(
  bidBookQueryProvider,
  (ref, q, page) => ref.read(bidBookRepositoryProvider).list(q, page: page),
);
