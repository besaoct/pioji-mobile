import 'package:flutter/material.dart';

/// Inter on both platforms (bundled in assets/fonts). Selected states change
/// colour, never weight or size.
abstract final class AppText {
  static const family = 'Inter';

  static const largeTitle =
      TextStyle(fontFamily: family, fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.4, height: 1.15);
  static const title = TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w600, height: 1.2);
  static const headline = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, height: 1.25);
  static const body = TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w400, height: 1.35);
  static const callout = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w400, height: 1.3);
  static const footnote = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w400, height: 1.3);
  static const caption = TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w500, height: 1.25);
  static const tabLabel = TextStyle(fontFamily: family, fontSize: 11, fontWeight: FontWeight.w400);
  static const metric = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
