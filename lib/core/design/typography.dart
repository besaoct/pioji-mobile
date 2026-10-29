import 'package:flutter/material.dart';

/// System font only: no fontFamily is ever set. Selected states change colour,
/// never weight or size.
abstract final class AppText {
  static const largeTitle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.4, height: 1.15);
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.2);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25);
  static const body = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.35);
  static const callout = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.3);
  static const footnote = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.3);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.25);
  static const tabLabel = TextStyle(fontSize: 11, fontWeight: FontWeight.w400);
  static const metric = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
