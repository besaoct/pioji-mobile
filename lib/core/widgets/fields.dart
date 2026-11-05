import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../utils/formatters.dart';
import 'one_line_text.dart';

/// Text input inside a grouped card: small label above, value below,
/// error text under the value. No border, no focus ring.
class FieldInput extends StatelessWidget {
  const FieldInput({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.maxLines = 1,
    this.obscureText = false,
    this.autofillHints,
    this.caption,
    this.captionAccent = false,
    this.trailing,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? suffix;
  final int maxLines;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? caption;
  final bool captionAccent;
  final Widget? trailing;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelText = caption == null ? label : '$label · $caption';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OneLineText(
                  labelText,
                  style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: error != null ? c.danger : (captionAccent ? c.accent : c.textTertiary),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: keyboardType,
                        inputFormatters: inputFormatters,
                        textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        maxLines: maxLines,
                        minLines: 1,
                        obscureText: obscureText,
                        autofillHints: autofillHints,
                        textCapitalization: textCapitalization,
                        style: AppText.body.copyWith(color: c.textPrimary),
                        decoration: InputDecoration.collapsed(hintText: hint ?? label),
                      ),
                    ),
                    if (suffix != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, right: 6),
                        child: Text(suffix!, style: AppText.body.copyWith(color: c.textTertiary)),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 3),
                  Text(error!, style: AppText.footnote.copyWith(color: c.danger)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Decimal input formatter: digits and one dot.
final decimalOnly = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))];
final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
final alphanumericOnly = [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))];

/// A tappable row: label on the left, current value and chevron on the right.
/// Used for pickers, dates and navigation inside forms.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    this.value,
    this.placeholder = 'Select',
    this.onTap,
    this.error,
    this.showChevron = true,
    this.valueColor,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final String? error;
  final bool showChevron;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: '$label, ${value ?? placeholder}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.rowMinH),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(label, style: AppText.body.copyWith(color: error != null ? c.danger : c.textPrimary)),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: OneLineText(
                        value ?? placeholder,
                        textAlign: TextAlign.right,
                        style: AppText.body.copyWith(
                          color: value == null ? c.textTertiary : (valueColor ?? c.textSecondary),
                        ),
                      ),
                    ),
                    if (showChevron) ...[
                      const SizedBox(width: 6),
                      Icon(CupertinoIcons.chevron_right, size: 15, color: c.textTertiary),
                    ],
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 3),
                  Text(error!, style: AppText.footnote.copyWith(color: c.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS switch row.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.rowMinH),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.body)),
            CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: c.accentFill),
          ],
        ),
      ),
    );
  }
}

/// iOS segmented control on a fill track.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.selected, required this.onChanged, this.compact = false});

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        color: c.fill,
        shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (final e in options.entries)
            _segment(context, c, e.key, e.value),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, AppColors c, T key, String label) {
    final isOn = key == selected;
    final child = Semantics(
      selected: isOn,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(key),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: isOn
              ? ShapeDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? c.surfaceRaised : c.surface,
                  shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  shadows: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
                )
              : null,
          child: OneLineText(label, style: AppText.footnote.copyWith(color: isOn ? c.textPrimary : c.textSecondary)),
        ),
      ),
    );
    return compact ? child : Expanded(child: child);
  }
}

/// Opens an iOS date wheel in a sheet. Returns null if dismissed.
Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? minimum}) {
  var value = initial ?? DateTime.now();
  if (minimum != null && value.isBefore(minimum)) value = minimum;
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: value,
              minimumDate: minimum,
              onDateTimeChanged: (d) => value = d,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('Done')),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Date row that opens [pickDate].
class DateRow extends StatelessWidget {
  const DateRow({super.key, required this.label, required this.value, required this.onChanged, this.minimum, this.error, this.placeholder = 'Select'});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? minimum;
  final String? error;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return ValueRow(
      label: label,
      value: value == null ? null : Fmt.day(value),
      placeholder: placeholder,
      error: error,
      onTap: () async {
        final d = await pickDate(context, initial: value, minimum: minimum);
        if (d != null) onChanged(d);
      },
    );
  }
}
