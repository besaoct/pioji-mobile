import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../utils/formatters.dart';
import '../utils/weight_calc.dart';
import 'app_card.dart';
import 'fields.dart';

/// Packages × nett per package = total kg, with the 2-of-3 rule applied live.
class WeightFields extends StatefulWidget {
  const WeightFields({
    super.key,
    required this.pkgs,
    required this.nett,
    required this.total,
    this.errors = const {},
    this.keys = const (pkgs: 'pkgs', nett: 'nett', total: 'ttl_kgs'),
    this.nettLabel = 'Per pkg',
  });

  final TextEditingController pkgs;
  final TextEditingController nett;
  final TextEditingController total;
  final Map<String, String> errors;
  final ({String pkgs, String nett, String total}) keys;
  final String nettLabel;

  @override
  State<WeightFields> createState() => _WeightFieldsState();
}

class _WeightFieldsState extends State<WeightFields> {
  final _calc = WeightCalc();

  @override
  void initState() {
    super.initState();
    _calc.seed([
      if (widget.pkgs.text.isNotEmpty) WeightField.pkgs,
      if (widget.nett.text.isNotEmpty) WeightField.nett,
      if (widget.total.text.isNotEmpty) WeightField.total,
    ]);
  }

  void _edited(WeightField f) {
    final r = _calc.onEdit(
      f,
      pkgs: Fmt.parse(widget.pkgs.text),
      nett: Fmt.parse(widget.nett.text),
      total: Fmt.parse(widget.total.text),
    );
    void put(TextEditingController c, double? v, WeightField which) {
      if (_calc.derived == which && v != null) c.text = Fmt.editable(v);
    }

    put(widget.pkgs, r.pkgs, WeightField.pkgs);
    put(widget.nett, r.nett, WeightField.nett);
    put(widget.total, r.total, WeightField.total);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = _calc.derived;
    Widget cell(String label, TextEditingController ctl, WeightField f, String key, {bool ints = false, String? suffix}) {
      final derived = d == f;
      return Container(
        color: derived ? c.accentTint : null,
        child: FieldInput(
          label: label,
          caption: derived ? 'Calculated' : null,
          captionAccent: derived,
          controller: ctl,
          error: widget.errors[key],
          suffix: suffix,
          keyboardType: TextInputType.numberWithOptions(decimal: !ints),
          inputFormatters: ints ? digitsOnly : decimalOnly,
          onChanged: (_) => _edited(f),
        ),
      );
    }

    return GroupedSection(
      label: 'Weight',
      footer: const Text('Enter any two. The third is calculated.'),
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell('Packages', widget.pkgs, WeightField.pkgs, widget.keys.pkgs, ints: true)),
              VerticalDivider(width: 0.5, thickness: 0.5, color: c.separator),
              Expanded(child: cell(widget.nettLabel, widget.nett, WeightField.nett, widget.keys.nett, suffix: 'kg')),
              VerticalDivider(width: 0.5, thickness: 0.5, color: c.separator),
              Expanded(child: cell('Total', widget.total, WeightField.total, widget.keys.total, suffix: 'kg')),
            ],
          ),
        ),
      ],
    );
  }
}
