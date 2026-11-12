import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../utils/formatters.dart';
import 'buttons.dart';
import 'controls.dart';
import 'one_line_text.dart';
import '../design/app_icons.dart';

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
                        decoration: InputDecoration(hintText: hint ?? label),
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
                      AppIcon(AppIcons.chevronRight, size: 15, color: c.textTertiary),
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

/// Label with a switch on the right.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.rowMinH),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.body)),
            AppSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Segmented control on a fill track.
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

/// Opens a month calendar in a sheet. Returns null if dismissed.
Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? minimum}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(child: _CalendarSheet(initial: initial, minimum: minimum)),
  );
}

class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet({this.initial, this.minimum});
  final DateTime? initial;
  final DateTime? minimum;

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late final DateTime? _min = widget.minimum == null ? null : DateUtils.dateOnly(widget.minimum!);
  late final DateTime? _selected = widget.initial == null ? null : DateUtils.dateOnly(widget.initial!);
  late DateTime _month = DateTime((_selected ?? _today).year, (_selected ?? _today).month);

  bool _allowed(DateTime d) => _min == null || !d.isBefore(_min);

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = DateTime(_month.year, _month.month);
    final lead = (first.weekday + 6) % 7; // Monday first
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= days; d++) DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final canGoBack = _min == null || _month.isAfter(DateTime(_min.year, _min.month));
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(Fmt.monthYear(_month), style: AppText.headline)),
              _NavButton(icon: AppIcons.chevronLeft, label: 'Previous month', onTap: canGoBack ? () => _shift(-1) : null),
              _NavButton(icon: AppIcons.chevronRight, label: 'Next month', onTap: () => _shift(1)),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(child: Center(child: Text(w, style: AppText.caption.copyWith(color: c.textTertiary)))),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          for (var r = 0; r < cells.length; r += 7)
            Row(children: [for (final d in cells.sublist(r, r + 7)) Expanded(child: _dayCell(c, d))]),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              if (_allowed(_today)) LinkButton(label: 'Today', onPressed: () => Navigator.pop(context, _today)),
              const Spacer(),
              LinkButton(label: 'Cancel', color: c.textSecondary, onPressed: () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(AppColors c, DateTime? d) {
    if (d == null) return const SizedBox(height: 44);
    final selected = _selected != null && DateUtils.isSameDay(d, _selected);
    final today = DateUtils.isSameDay(d, _today);
    final ok = _allowed(d);
    return Semantics(
      button: ok,
      selected: selected,
      label: Fmt.day(d),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ok ? () => Navigator.pop(context, d) : null,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.accentFill : (today ? c.accentTint : null),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${d.day}',
                style: AppText.callout.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: selected || today ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? c.onAccent : (!ok ? c.textTertiary.withValues(alpha: 0.5) : (today ? c.accent : c.textPrimary)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, this.onTap});
  final AppIcons icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: AppIcon(icon, size: 20, color: onTap == null ? c.textTertiary.withValues(alpha: 0.4) : c.textPrimary)),
        ),
      ),
    );
  }
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
