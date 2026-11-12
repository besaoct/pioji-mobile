import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Borderless card: surface tone plus a light shadow in light mode only.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: c.surface, shape: AppRadius.cardBorder, shadows: c.cardShadow),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}

/// A section: small heading, then one flat surface whose rows are split by
/// full-width hairlines.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.label,
    required this.children,
    this.footer,
    this.dividerIndent = 0,
    this.trailingLabel,
  });

  final String? label;
  final Widget? trailingLabel;
  final List<Widget> children;
  final Widget? footer;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(indent: dividerIndent, height: 0.5));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm - 1),
            child: Row(
              children: [
                Expanded(child: Text(label!, style: AppText.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600))),
                ?trailingLabel,
              ],
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AppRadius.control)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm - 1, AppSpace.xs, 0),
            child: DefaultTextStyle(style: AppText.footnote.copyWith(color: c.textTertiary), child: footer!),
          ),
      ],
    );
  }
}
