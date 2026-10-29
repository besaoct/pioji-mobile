enum WeightField { pkgs, nett, total }

/// The 2-of-3 rule: of packages, nett per package and total kg, the field the
/// user did not touch most recently is derived from the other two.
class WeightCalc {
  final _order = <WeightField>[];

  /// The field currently calculated, or null until two fields were edited.
  WeightField? get derived =>
      _order.length < 2 ? null : WeightField.values.firstWhere((f) => !_order.contains(f));

  void seed(Iterable<WeightField> filled) {
    _order
      ..clear()
      ..addAll(filled.take(2));
  }

  ({double? pkgs, double? nett, double? total}) onEdit(
    WeightField edited, {
    required double? pkgs,
    required double? nett,
    required double? total,
  }) {
    _order
      ..remove(edited)
      ..add(edited);
    if (_order.length > 2) _order.removeAt(0);

    switch (derived) {
      case WeightField.total:
        total = pkgs != null && nett != null ? _round(pkgs * nett) : total;
      case WeightField.nett:
        nett = total != null && pkgs != null && pkgs != 0 ? _round(total / pkgs) : nett;
      case WeightField.pkgs:
        pkgs = total != null && nett != null && nett != 0 ? _round(total / nett) : pkgs;
      case null:
        break;
    }
    return (pkgs: pkgs, nett: nett, total: total);
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}
