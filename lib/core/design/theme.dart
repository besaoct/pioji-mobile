import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';
import '../widgets/controls.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? AppColors.light : AppColors.dark;
  final base = ThemeData(useMaterial3: true, brightness: brightness, fontFamily: AppText.family);
  const noOverlay = WidgetStatePropertyAll<Color>(Colors.transparent);
  final controlShape = const WidgetStatePropertyAll<OutlinedBorder>(AppRadius.controlBorder);
  // InputBorder.none: an outline border adds side gap padding, which would
  // push input text out of line with its label.
  const noBorder = InputBorder.none;

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    colorScheme: base.colorScheme.copyWith(
      primary: c.accentFill,
      onPrimary: c.onAccent,
      secondary: c.accent,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: c.danger,
      outline: c.separator,
    ),
    extensions: [c],
    textTheme: base.textTheme.apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),

    // No interaction chrome anywhere: no ripple, hover, focus or highlight.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        overlayColor: noOverlay,
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
        shape: controlShape,
        textStyle: const WidgetStatePropertyAll(AppText.headline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        overlayColor: noOverlay,
        foregroundColor: WidgetStatePropertyAll(c.accent),
        textStyle: const WidgetStatePropertyAll(AppText.body),
        shape: controlShape,
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(overlayColor: noOverlay)),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: noBorder,
      enabledBorder: noBorder,
      focusedBorder: noBorder,
      errorBorder: noBorder,
      focusedErrorBorder: noBorder,
      disabledBorder: noBorder,
      hintStyle: AppText.body.copyWith(color: c.textTertiary),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.25),
      selectionHandleColor: c.accent,
    ),
    dividerTheme: DividerThemeData(color: c.separator, thickness: 0.5, space: 0.5),
    tooltipTheme: TooltipThemeData(
      textStyle: AppText.footnote.copyWith(color: c.surface),
      decoration: ShapeDecoration(color: c.textPrimary, shape: AppRadius.controlBorder),
      triggerMode: TooltipTriggerMode.longPress,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.textPrimary,
      contentTextStyle: AppText.callout.copyWith(color: c.surface),
      shape: AppRadius.controlBorder,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceRaised,
      modalBackgroundColor: c.surfaceRaised,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: c.separator,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AppPageTransitionsBuilder(),
        TargetPlatform.iOS: AppPageTransitionsBuilder(),
      },
    ),
  );
}
