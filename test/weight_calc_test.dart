import 'package:flutter_test/flutter_test.dart';
import 'package:tea_erp/core/utils/weight_calc.dart';

void main() {
  test('packages and total give the weight per package', () {
    final calc = WeightCalc();
    calc.onEdit(WeightField.pkgs, pkgs: 20, nett: null, total: null);
    final r = calc.onEdit(WeightField.total, pkgs: 20, nett: null, total: 500);
    expect(calc.derived, WeightField.nett);
    expect(r.nett, 25);
  });

  test('clearing the total clears the calculated weight per package', () {
    final calc = WeightCalc();
    calc.onEdit(WeightField.pkgs, pkgs: 2000, nett: null, total: null);
    calc.onEdit(WeightField.total, pkgs: 2000, nett: null, total: 500);
    final r = calc.onEdit(WeightField.total, pkgs: 2000, nett: 0.25, total: null);
    expect(r.nett, isNull);
  });

  test('packages and weight per package give the total', () {
    final calc = WeightCalc();
    calc.onEdit(WeightField.pkgs, pkgs: 10, nett: null, total: null);
    final r = calc.onEdit(WeightField.nett, pkgs: 10, nett: 26, total: null);
    expect(calc.derived, WeightField.total);
    expect(r.total, 260);
  });

  test('total and weight per package give the packages', () {
    final calc = WeightCalc();
    calc.onEdit(WeightField.total, pkgs: null, nett: null, total: 520);
    final r = calc.onEdit(WeightField.nett, pkgs: null, nett: 26, total: 520);
    expect(calc.derived, WeightField.pkgs);
    expect(r.pkgs, 20);
  });
}
