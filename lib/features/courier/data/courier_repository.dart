import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/list/list_query.dart';
import '../../../core/list/paged_notifier.dart';
import '../../../core/network/api.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paginated.dart';
import '../../../core/utils/json.dart';

class CourierEntry {
  const CourierEntry({
    required this.id,
    this.entryNo,
    this.trackingNumber,
    this.courierName,
    this.buyerName,
    this.destinationAddress,
    this.pickupDate,
    this.pickupDay,
    this.weight,
    this.isAuc = false,
    this.isPvt = false,
    this.description,
    this.photoUrl,
  });

  final int id;
  final String? entryNo;
  final String? trackingNumber;
  final String? courierName;
  final String? buyerName;
  final String? destinationAddress;
  final DateTime? pickupDate;
  final String? pickupDay;
  final double? weight;
  final bool isAuc;
  final bool isPvt;
  final String? description;
  final String? photoUrl;

  factory CourierEntry.fromJson(Map<String, dynamic> j) => CourierEntry(
        id: J.intOr(j['id'], 0),
        entryNo: J.str(j['entry_no']) ?? J.str(j['entry_number']),
        trackingNumber: J.str(j['tracking_number']),
        courierName: J.str(j['courier_name']) ?? J.str(J.map(j['courier_service'])?['company_name']),
        buyerName: J.nested(j, 'buyer_name', 'buyer', 'buyer_name'),
        destinationAddress: J.str(j['destination_address']),
        pickupDate: J.date(j['pickup_date']),
        pickupDay: J.str(j['pickup_day']),
        weight: J.dbl(j['weight']),
        isAuc: J.boolOr(j['is_auc'], false),
        isPvt: J.boolOr(j['is_pvt'], false),
        description: J.str(j['description']),
        photoUrl: J.str(j['photo_url']) ?? J.str(j['photo']),
      );
}

class BuyerAddress {
  const BuyerAddress({this.address, this.phone, this.whatsapp});
  final String? address;
  final String? phone;
  final String? whatsapp;
}

class CourierRepository {
  const CourierRepository(this._api);
  final Api _api;

  Future<CourierEntry> get(int id) async => CourierEntry.fromJson(await _api.one('/courier-entries/$id'));

  Future<Page<CourierEntry>> list(ListQuery q, {int page = 1}) =>
      _api.page('/courier-entries', CourierEntry.fromJson, query: q.toQuery(), page: page);

  Future<BuyerAddress> buyerAddress(int buyerId) async {
    final j = J.map(await _api.getData('/courier-entries/buyer-address/$buyerId')) ?? const {};
    return BuyerAddress(
      address: J.str(j['address']) ?? J.str(j['billing_address']) ?? J.str(j['poc_address']),
      phone: J.str(j['phone']),
      whatsapp: J.str(j['whatsapp']) ?? J.str(j['whatsapp_number']),
    );
  }

  /// JSON without a photo; multipart with one. Booleans go as 1/0 and
  /// arrays as `key[]` in multipart, as PHP expects.
  Future<void> create(Map<String, Object?> body, {String? photoPath}) async {
    final clean = cleanBody(body);
    if (photoPath == null) {
      await _api.post('/courier-entries', clean);
      return;
    }
    final form = FormData();
    clean.forEach((k, v) {
      if (v is List) {
        for (final e in v) {
          form.fields.add(MapEntry('$k[]', '$e'));
        }
      } else if (v is bool) {
        form.fields.add(MapEntry(k, v ? '1' : '0'));
      } else {
        form.fields.add(MapEntry(k, '$v'));
      }
    });
    form.files.add(MapEntry('photo', await MultipartFile.fromFile(photoPath)));
    await _api.post('/courier-entries', form);
  }
}

final courierRepositoryProvider = Provider((ref) => CourierRepository(ref.watch(apiProvider)));
final courierQueryProvider = ListQueryProvider(ListQueryNotifier.new);
final courierListProvider = pagedProvider<CourierEntry>(
  courierQueryProvider,
  (ref, q, page) => ref.read(courierRepositoryProvider).list(q, page: page),
);
