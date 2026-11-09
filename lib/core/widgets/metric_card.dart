import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/typography.dart';
import 'app_card.dart';
import 'one_line_text.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, this.onTap, this.valueColor, this.loading = false, this.hint});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final bool loading;

  /// Small text after the value, e.g. "28 in all".
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: hint == null ? '$label: $value' : '$label: $value, $hint',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OneLineText(label, style: AppText.footnote.copyWith(color: c.textTertiary)),
            const SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: loading
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 40,
                        height: 20,
                        decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(6)),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(child: FitText(value, style: AppText.metric.copyWith(color: valueColor ?? c.textPrimary))),
                        if (hint != null) ...[
                          const SizedBox(width: 6),
                          Flexible(child: OneLineText(hint!, style: AppText.footnote.copyWith(color: c.textTertiary))),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
