import 'package:flutter/material.dart';

/// Text that never wraps: one line, ellipsis, and the full text in a
/// long-press tooltip and for screen readers.
class OneLineText extends StatelessWidget {
  const OneLineText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // Data sometimes carries line breaks or runs of spaces; show one line.
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Tooltip(
      message: flat,
      excludeFromSemantics: true,
      child: Text(
        flat,
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Short numbers scale down instead of truncating.
class FitText extends StatelessWidget {
  const FitText(this.text, {super.key, this.style, this.alignment = Alignment.centerLeft});

  final String text;
  final TextStyle? style;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}
