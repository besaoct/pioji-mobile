import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/status_badge.dart';

enum ContractStatus {
  draft('draft', 'Draft', Tone.neutral),
  active('active', 'Active', Tone.success),
  expired('expired', 'Expired', Tone.danger),
  cancelled('cancelled', 'Cancelled', Tone.neutral);

  const ContractStatus(this.api, this.label, this.tone);
  final String api;
  final String label;
  final Tone tone;

  static ContractStatus parse(Object? v) => values.firstWhere((s) => s.api == v?.toString(), orElse: () => draft);
}

class ContractItem {
  const ContractItem({this.grade, this.pricePerKg, this.quantity, this.currency = 'INR'});
  final String? grade;
  final double? pricePerKg;
  final double? quantity;
  final String currency;

  double get value => (pricePerKg ?? 0) * (quantity ?? 0);

  factory ContractItem.fromJson(Map<String, dynamic> j) => ContractItem(
        grade: J.str(j['tea_grade']) ?? J.str(j['tea_grade_description']),
        pricePerKg: J.dbl(j['price_per_kg']),
        quantity: J.dbl(j['quantity']),
        currency: J.str(j['currency']) ?? 'INR',
      );

  Map<String, Object?> toJson() => {'tea_grade': grade, 'price_per_kg': pricePerKg, 'quantity': quantity, 'currency': currency};
}

class Contract {
  const Contract({
    required this.id,
    required this.title,
    this.number,
    this.sellerName,
    this.buyerName,
    this.effective,
    this.expiry,
    this.promptDays,
    this.discount,
    this.status = ContractStatus.draft,
    this.terms,
    this.items = const [],
  });

  final int id;
  final String title;
  final String? number;
  final String? sellerName;
  final String? buyerName;
  final DateTime? effective;
  final DateTime? expiry;
  final int? promptDays;
  final double? discount;
  final ContractStatus status;
  final String? terms;
  final List<ContractItem> items;

  bool get expiringSoon =>
      status == ContractStatus.active && expiry != null && expiry!.difference(DateTime.now()).inDays <= 7 && expiry!.isAfter(DateTime.now());

  factory Contract.fromJson(Map<String, dynamic> j) => Contract(
        id: J.intOr(j['id'], 0),
        title: (J.str(j['contract_title']) ?? 'Contract #${j['id']}').replaceAll(RegExp(r'\s+'), ' '),
        number: J.str(j['contract_number']),
        sellerName: J.nested(j, 'seller_name', 'seller', 'seller_name'),
        buyerName: J.nested(j, 'buyer_name', 'buyer', 'buyer_name'),
        effective: J.date(j['effective_date']),
        expiry: J.date(j['expiry_date']),
        promptDays: J.integer(j['prompt_days']),
        discount: J.dbl(j['discount']),
        status: ContractStatus.parse(j['status']),
        terms: J.str(j['terms_and_conditions']),
        items: ((j['contract_items'] ?? j['items']) is List ? (j['contract_items'] ?? j['items']) as List : const [])
            .whereType<Map<String, dynamic>>()
            .map(ContractItem.fromJson)
            .toList(),
      );
}

class ContractsRepository {
  const ContractsRepository(this._api);
  final Api _api;

  Future<Contract> get(int id) async => Contract.fromJson(await _api.one('/contracts/$id'));

  Future<Page<Contract>> list(ListQuery q, {int page = 1}) =>
      _api.page('/contracts', Contract.fromJson, query: q.toQuery(), page: page);

  Future<void> create(Map<String, Object?> body) => _api.post('/contracts', cleanBody(body));
}

final contractsRepositoryProvider = Provider((ref) => ContractsRepository(ref.watch(apiProvider)));
final contractsQueryProvider = ListQueryProvider(ListQueryNotifier.new);
final contractsListProvider = pagedProvider<Contract>(
  contractsQueryProvider,
  (ref, q, page) => ref.read(contractsRepositoryProvider).list(q, page: page),
);
