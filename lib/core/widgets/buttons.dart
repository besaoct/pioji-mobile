import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Deep filled button. While [loading] it shows a spinner and ignores taps,
/// so a form can never be submitted twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.destructive = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = destructive ? c.dangerFill : c.accentFill;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? () {} : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? bg.withValues(alpha: 0.4) : bg,
          ),
          foregroundColor: WidgetStatePropertyAll(c.onAccent),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: c.onAccent),
              )
            : Text(label),
      ),
    );
  }
}

/// Tinted button with accent text and no border.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(c.accentTint),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpace.lg)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: AppSpace.xs + 2)],
            Text(label, style: AppText.callout.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Text link in the accent colour, for top bars and inline actions.
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, this.onPressed, this.color, this.style});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Text(
                label,
                maxLines: 1,
                style: (style ?? AppText.body).copyWith(color: color ?? context.colors.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round filled "+" button used for "New …" in list headers.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed, required this.semanticLabel});

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.accentFill, shape: BoxShape.circle),
              child: Icon(CupertinoIcons.add, color: c.onAccent, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular surface icon button (notifications, scan).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onPressed, required this.semanticLabel, this.tinted = false});

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: ShapeDecoration(
            color: tinted ? c.accentTint : c.surface,
            shape: tinted ? AppRadius.controlBorder : const CircleBorder(),
            shadows: tinted ? null : c.cardShadow,
          ),
          child: Icon(icon, size: 21, color: tinted ? c.accent : c.textSecondary),
        ),
      ),
    );
  }
}
