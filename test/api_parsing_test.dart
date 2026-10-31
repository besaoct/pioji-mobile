// Checks every model against real API responses saved as JSON files.
// The responses contain business data, so they are not committed. Run with:
//
//   API_FIXTURES=/path/to/responses flutter test test/api_parsing_test.dart
//
// File names match the endpoint, e.g. GET_samples_per_page-2.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tea_erp/core/network/paginated.dart';
import 'package:tea_erp/features/allocation/data/allocation_repository.dart';
import 'package:tea_erp/features/auth/domain/user.dart';
import 'package:tea_erp/features/batches/data/batches_repository.dart';
import 'package:tea_erp/features/bid_book/data/bid_book_repository.dart';
import 'package:tea_erp/features/contracts/data/contracts_repository.dart';
import 'package:tea_erp/features/courier/data/courier_repository.dart';
import 'package:tea_erp/features/masters/data/masters_repository.dart';
import 'package:tea_erp/features/offer_lists/data/offer_lists_repository.dart';
import 'package:tea_erp/features/samples/domain/sample.dart';

void main() {
  final dir = Platform.environment['API_FIXTURES'];
  final skip = dir == null ? 'Set API_FIXTURES to a folder of saved responses' : null;

  Object? load(String name) => jsonDecode(File('$dir/$name.json').readAsStringSync());

  Page<T> page<T>(String name, T Function(Map<String, dynamic>) f) {
    final p = Page.parse(load(name), f);
    expect(p.items, isNotEmpty, reason: '$name parsed no items');
    return p;
  }

  test('samples', () {
    final p = page('GET_samples_per_page-2', Sample.fromJson);
    expect(p.total, greaterThan(p.items.length));
    expect(p.hasMore, isTrue);
    final s = p.items.first;
    expect(s.gardenName, isNotNull);
    expect(s.grade, isNotNull);
    expect(s.status, isNot(SampleStatus.unknown));
  }, skip: skip);

  test('offer lists', () {
    final o = page('GET_offer-lists_per_page-2', OfferList.fromJson).items.first;
    expect(o.gardenName, isNotNull);
    expect(o.invNo, isNotNull);
  }, skip: skip);

  test('batches', () {
    final b = page('GET_batches_per_page-2', Batch.fromJson).items.first;
    expect(b.name, startsWith('BATCH'));
    expect(b.count, greaterThan(0));
  }, skip: skip);

  test('courier entries', () {
    final e = page('GET_courier-entries_per_page-2', CourierEntry.fromJson).items.first;
    expect(e.trackingNumber, isNotNull);
    expect(e.buyerName, isNotNull);
  }, skip: skip);

  test('bid book', () {
    final b = page('GET_bid-book_per_page-2', Bid.fromJson).items.first;
    expect(b.gardenName, isNot('–'));
    expect(b.invoiceNumber, isNot('–'));
  }, skip: skip);

  test('contracts', () {
    final k = page('GET_contracts_per_page-2', Contract.fromJson).items.first;
    expect(k.sellerName, isNotNull);
    expect(k.items, isNotEmpty);
  }, skip: skip);

  test('lookup lists', () {
    for (final name in ['GET_gardens', 'GET_buyers', 'GET_sellers', 'GET_posting-lists']) {
      final items = MasterItem.listFrom(load(name));
      expect(items, isNotEmpty, reason: name);
      expect(items.first.name, isNot(startsWith('#')), reason: name);
    }
    final negotiators = MasterItem.listFrom((load('GET_negotiators')! as Map)['data']);
    expect(negotiators, isNotEmpty);
    final services = (load('GET_courier-entries_services')! as Map)['data'] as Map;
    expect(MasterItem.listFrom(services['courier_services']).first.name, isNot(startsWith('#')));
    expect(MasterItem.listFrom(services['courier_addresses']).first.name, isNot(startsWith('#')));
  }, skip: skip);

  test('grades', () {
    final p = Page.parse<String?>(load('GET_grades'), (g) => g['grade_name'] as String?);
    expect(p.items.whereType<String>(), isNotEmpty);
  }, skip: skip);

  test('offered today', () {
    final data = (load('GET_samples-offered-today_date-2026-10-30')! as Map)['data'] as Map<String, dynamic>;
    final samples = (data['samples'] as List).cast<Map<String, dynamic>>().map((j) => OfferedItem.fromJson(ItemType.sample, j)).toList();
    expect(samples, isNotEmpty);
    expect(samples.first.title, isNot(startsWith('Lot #')));
    expect(samples.any((s) => s.buyers.isNotEmpty), isTrue);
    expect(MasterItem.listFrom(data['available_buyers']), isNotEmpty);
  }, skip: skip);

  test('auth me', () {
    final data = (load('GET_auth_me')! as Map)['data'] as Map<String, dynamic>;
    final u = User.fromJson(data['user'] as Map<String, dynamic>);
    expect(u.email, isNotEmpty);
    expect(u.name, isNot('Admin'));
  }, skip: skip);

  test('ex-factory metrics come with the list', () {
    final p = Page.parse(load('GET_ex-factory_per_page-2'), (j) => j);
    expect(p.extra['metrics'], isA<Map<String, dynamic>>());
  }, skip: skip);
}
