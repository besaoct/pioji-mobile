import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/context_ext.dart';

/// Thin rotating arc in the accent colour. Same on Android and iOS.
class AppSpinner extends StatefulWidget {
  const AppSpinner({super.key, this.size = 20, this.color, this.strokeWidth = 2, this.spinning = true});

  final double size;
  final Color? color;
  final double strokeWidth;

  /// When false the arc stands still (used while pulling to refresh).
  final bool spinning;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _ctl.repeat();
  }

  @override
  void didUpdateWidget(AppSpinner old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_ctl.isAnimating) _ctl.repeat();
    if (!widget.spinning && _ctl.isAnimating) _ctl.stop();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.accent;
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) => CustomPaint(
            painter: _ArcPainter(turn: _ctl.value, color: color, stroke: widget.strokeWidth),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.turn, required this.color, required this.stroke});
  final double turn;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    canvas.drawArc(r, turn * math.pi * 2 - math.pi / 2, math.pi * 0.6, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.turn != turn || old.color != color;
}

/// Centred spinner for a loading area.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.height});
  final double? height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, child: const Center(child: AppSpinner(size: 24)));
}

/// Pill toggle in the palette colours.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 46,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? c.accentFill : c.fill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? c.onAccent : c.surface,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 2, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pull-to-refresh with the app's own spinner instead of a platform one.
/// Wraps a scroll view; works with both Android and iOS scrolling.
class AppRefresh extends StatefulWidget {
  const AppRefresh({super.key, required this.onRefresh, required this.child, this.top = 8});

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Distance of the spinner from the top of the scroll view.
  final double top;

  @override
  State<AppRefresh> createState() => _AppRefreshState();
}

class _AppRefreshState extends State<AppRefresh> {
  RefreshIndicatorStatus? _status;

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final visible = s == RefreshIndicatorStatus.drag ||
        s == RefreshIndicatorStatus.armed ||
        s == RefreshIndicatorStatus.snap ||
        s == RefreshIndicatorStatus.refresh;
    final spinning = s == RefreshIndicatorStatus.snap || s == RefreshIndicatorStatus.refresh;
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: (st) {
            if (mounted && st != _status) setState(() => _status = st);
          },
          child: widget.child,
        ),
        Positioned(
          top: widget.top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: visible ? (s == RefreshIndicatorStatus.drag ? 0.5 : 1) : 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    shape: BoxShape.circle,
                    boxShadow: context.colors.cardShadow,
                  ),
                  child: AppSpinner(size: 18, spinning: spinning),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Page transition used on both platforms: a short fade with a small slide.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}
