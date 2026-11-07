import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/status_badge.dart';

enum SaleStatus {
  pending('pending', 'Pending', Tone.warning),
  confirmed('confirmed', 'Confirmed', Tone.accent),
  dispatched('dispatched', 'Dispatched', Tone.accent),
  delivered('delivered', 'Delivered', Tone.success);

  const SaleStatus(this.api, this.label, this.tone);
  final String api;
  final String label;
  final Tone tone;

  static SaleStatus parse(Object? v) => values.firstWhere((s) => s.api == v?.toString(), orElse: () => pending);
}

class SaleEntry {
  const SaleEntry({
    required this.id,
    this.buyerId,
    this.buyerName,
    this.grade,
    this.rate,
    this.pkgs,
    this.quantity,
    this.mark,
    this.invoicePrefix,
    this.invoiceNo,
    this.dealDate,
    this.cnNumber,
    this.cnDate,
    this.transport,
    this.discount,
    this.remarks,
    this.status = SaleStatus.pending,
  });

  final int id;
  final int? buyerId;
  final String? buyerName;
  final String? grade;
  final double? rate;
  final int? pkgs;
  final double? quantity;
  final String? mark;
  final String? invoicePrefix;
  final String? invoiceNo;
  final DateTime? dealDate;
  final String? cnNumber;
  final DateTime? cnDate;
  final String? transport;
  final double? discount;
  final String? remarks;
  final SaleStatus status;

  double? get amount => rate == null || quantity == null ? null : rate! * quantity! - (discount ?? 0);

  factory SaleEntry.fromJson(Map<String, dynamic> j) => SaleEntry(
        id: J.intOr(j['id'], 0),
        buyerId: J.integer(j['buyer_id']) ?? J.integer((j['buyer'] as Map?)?['id']),
        buyerName: J.nested(j, 'buyer_name', 'buyer', 'buyer_name'),
        grade: J.str(j['tea_grade']),
        rate: J.dbl(j['rate_per_kg']),
        pkgs: J.integer(j['pkgs']),
        quantity: J.dbl(j['quantity_kg']),
        mark: J.str(j['mark']),
        invoicePrefix: J.str(j['invoice_prefix']),
        invoiceNo: J.str(j['invoice_no']),
        dealDate: J.date(j['deal_date']),
        cnNumber: J.str(j['cn_number']),
        cnDate: J.date(j['cn_date']),
        transport: J.str(j['transport']),
        discount: J.dbl(j['discount']),
        remarks: J.str(j['remarks']),
        status: SaleStatus.parse(j['status']),
      );
}

class SalesRepository {
  const SalesRepository(this._api);
  final Api _api;

  Future<SaleEntry> get(int id) async => SaleEntry.fromJson(await _api.one('/sales-register/$id'));

  Future<void> delete(int id) => _api.delete('/sales-register/$id');

  Future<Page<SaleEntry>> list(ListQuery q, {int page = 1}) =>
      _api.page('/sales-register', SaleEntry.fromJson, query: q.toQuery(), page: page);

  Future<void> create(Map<String, Object?> body) => _api.post('/sales-register', cleanBody(body));

  Future<void> update(int id, Map<String, Object?> body) async {
    try {
      await _api.put('/sales-register/$id', cleanBody(body));
    } on ServerFailure catch (e) {
      // More packages than the sale's split allows comes back as a 500:
      // "Cannot update to 12 pkgs. Maximum allowed for this split is 10 pkgs (…)".
      final max = RegExp(r'Maximum allowed for this split is (\d+)').firstMatch(e.serverMessage ?? '')?.group(1);
      if (max != null) throw ValidationFailure('Too many packages.', {'pkgs': 'At most $max packages for this sale.'});
      rethrow;
    }
  }
}

final salesRepositoryProvider = Provider((ref) => SalesRepository(ref.watch(apiProvider)));
final salesQueryProvider = ListQueryProvider(ListQueryNotifier.new);
final salesListProvider = pagedProvider<SaleEntry>(
  salesQueryProvider,
  (ref, q, page) => ref.read(salesRepositoryProvider).list(q, page: page),
);
