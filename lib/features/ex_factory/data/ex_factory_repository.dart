import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_mapper.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/status_badge.dart';

enum RegisterStatus {
  matched('matched', 'Matched', Tone.success),
  priceMismatch('price_mismatch', 'Price mismatch', Tone.warning),
  qtyMismatch('qty_mismatch', 'Qty mismatch', Tone.warning),
  unregistered('unregistered', 'Unregistered', Tone.danger);

  const RegisterStatus(this.api, this.label, this.tone);
  final String api;
  final String label;
  final Tone tone;

  static RegisterStatus? parse(Object? v) => values.where((s) => s.api == v?.toString()).firstOrNull;
}

class ExFactoryBill {
  const ExFactoryBill({
    required this.id,
    this.billNo,
    this.billDate,
    this.mark,
    this.invoicePrefix,
    this.invoiceNo,
    this.supplierName,
    this.pkgs,
    this.nett,
    this.taxableValue,
    this.gstType,
    this.igst,
    this.cgst,
    this.sgst,
    this.total,
    this.cnNumber,
    this.transport,
    this.creditDays,
    this.status,
  });

  final int id;
  final String? billNo;
  final DateTime? billDate;
  final String? mark;
  final String? invoicePrefix;
  final String? invoiceNo;
  final String? supplierName;
  final int? pkgs;
  final double? nett;
  final double? taxableValue;
  final String? gstType;
  final double? igst;
  final double? cgst;
  final double? sgst;
  final double? total;
  final String? cnNumber;
  final String? transport;
  final int? creditDays;
  final RegisterStatus? status;

  factory ExFactoryBill.fromJson(Map<String, dynamic> j) => ExFactoryBill(
        id: J.intOr(j['id'], 0),
        billNo: J.str(j['bill_no']) ?? J.str(j['bill_number']),
        billDate: J.date(j['bill_date']),
        mark: J.str(j['mark']),
        invoicePrefix: J.str(j['invoice_prefix']),
        invoiceNo: J.str(j['invoice_no']),
        supplierName: J.nested(j, 'supplier_name', 'supplier', 'seller_name') ?? J.nested(j, 'seller_name', 'seller', 'seller_name'),
        pkgs: J.integer(j['pkgs']),
        nett: J.dbl(j['nett']),
        taxableValue: J.dbl(j['taxable_value']),
        gstType: J.str(j['gst_type']),
        igst: J.dbl(j['igst_amount']),
        cgst: J.dbl(j['cgst_amount']),
        sgst: J.dbl(j['sgst_amount']),
        total: J.dbl(j['total_bill_value']),
        cnNumber: J.str(j['cn_number']),
        transport: J.str(j['transport']),
        creditDays: J.integer(j['credit_days']),
        status: RegisterStatus.parse(j['register_status']),
      );
}

class ExFactoryRepository {
  const ExFactoryRepository(this._api);
  final Api _api;

  Future<ExFactoryBill> get(int id) async => ExFactoryBill.fromJson(await _api.one('/ex-factory/$id'));

  Future<Page<ExFactoryBill>> list(ListQuery q, {int page = 1}) =>
      _api.page('/ex-factory', ExFactoryBill.fromJson, query: q.toQuery(), page: page);

  /// Status counts for the summary strip, when the API includes them.
  Future<Map<RegisterStatus, int>> metrics() async {
    final counts = <RegisterStatus, int>{};
    for (final s in RegisterStatus.values) {
      final p = await _api.page('/ex-factory', ExFactoryBill.fromJson, query: {'register_status': s.api}, perPage: 1);
      counts[s] = p.total;
    }
    return counts;
  }

  Future<ExFactoryBill?> create(Map<String, Object?> body) async {
    final data = await _api.post('/ex-factory', cleanBody(body));
    final map = J.map(data);
    return map == null ? null : ExFactoryBill.fromJson(J.map(map['bill']) ?? map);
  }

  /// Downloads the CSV with the current filters and returns the file path.
  Future<String> export(ListQuery q) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ex_factory_bills_${Fmt.api(DateTime.now())}.csv';
    try {
      await _api.dio.download('/ex-factory/export', path, queryParameters: cleanQuery(q.toQuery()));
    } on DioException catch (e) {
      throw mapError(e);
    }
    if (!await File(path).exists()) throw const ServerFailure();
    return path;
  }
}

final exFactoryRepositoryProvider = Provider((ref) => ExFactoryRepository(ref.watch(apiProvider)));
final exFactoryQueryProvider = ListQueryProvider(ListQueryNotifier.new);
final exFactoryListProvider = pagedProvider<ExFactoryBill>(
  exFactoryQueryProvider,
  (ref, q, page) => ref.read(exFactoryRepositoryProvider).list(q, page: page),
);
final exFactoryMetricsProvider = FutureProvider((ref) => ref.read(exFactoryRepositoryProvider).metrics());
