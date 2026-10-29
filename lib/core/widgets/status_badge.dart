import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/typography.dart';

enum Tone { neutral, accent, success, warning, danger }

/// Tinted status label. Always carries text, never colour alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = Tone.neutral});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.13),
        shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: AppText.caption.copyWith(color: color),
      ),
    );
  }
}

Color toneColor(BuildContext context, Tone tone) {
  final c = context.colors;
  return switch (tone) {
    Tone.neutral => c.textSecondary,
    Tone.accent => c.accent,
    Tone.success => c.success,
    Tone.warning => c.warning,
    Tone.danger => c.danger,
  };
}
