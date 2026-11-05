import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'tokens.dart';
import 'typography.dart';

extension DesignContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// Short confirmation ("Sample saved") just above the tab bar icons.
  ///
  /// Not a SnackBar: the tab bar's transparent fade counts as part of the
  /// bottom bar, so a SnackBar would float far above the icons.
  void toast(String message) => _Toast.show(this, message);
}

abstract final class _Toast {
  static OverlayEntry? _current;

  /// Space the tab bar's icons and labels take above the safe area.
  static const _barHeight = 64.0;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    final c = context.colors;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom + _barHeight + AppSpace.sm;
        return Positioned(
          left: AppSpace.screenH,
          right: AppSpace.screenH,
          bottom: bottom,
          child: IgnorePointer(
            child: _FadeIn(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
                decoration: ShapeDecoration(color: c.textPrimary, shape: AppRadius.controlBorder),
                child: Text(message, style: AppText.callout.copyWith(color: c.surface)),
              ),
            ),
          ),
        );
      },
    );
    _current = entry;
    overlay.insert(entry);
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (_current == entry) _current = null;
      if (entry.mounted) entry.remove();
    });
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
