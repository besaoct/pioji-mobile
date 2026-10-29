import 'package:flutter/cupertino.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'one_line_text.dart';

/// A list row: optional icon tile, one-line title and subtitle, trailing
/// widgets that never shrink, optional chevron. Min height 48.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.titleStyle,
    this.minHeight = 56,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final TextStyle? titleStyle;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg - 2, vertical: AppSpace.sm),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: AppSpace.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  OneLineText(title, style: titleStyle ?? AppText.body.copyWith(fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpace.xxs),
                    OneLineText(subtitle!, style: AppText.footnote.copyWith(color: c.textTertiary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppSpace.sm + 2), trailing!],
            if (showChevron) ...[
              const SizedBox(width: AppSpace.sm),
              Icon(CupertinoIcons.chevron_right, size: 15, color: c.textTertiary),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
    );
  }
}

/// Small rounded square holding an icon or an initial.
class IconTile extends StatelessWidget {
  const IconTile({super.key, this.icon, this.initial, this.color, this.background, this.size = 30});

  final IconData? icon;
  final String? initial;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: background ?? c.accentTint,
        shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.55, color: fg)
          : Text(initial ?? '', style: AppText.footnote.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
