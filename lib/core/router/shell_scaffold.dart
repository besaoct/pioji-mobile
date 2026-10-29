import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = [
  _Tab('Samples', CupertinoIcons.lab_flask),
  _Tab('Offers', CupertinoIcons.doc_text),
  _Tab('Home', CupertinoIcons.house),
  _Tab('Bids', CupertinoIcons.hammer),
  _Tab('More', CupertinoIcons.square_grid_2x2),
];

/// Tab shell: bottom bar on phones, a left rail on tablets. Home sits in the
/// centre and is selected on launch.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.shortestSide >= 600;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Rail(current: shell.currentIndex, onTap: _go),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _BottomBar(current: shell.currentIndex, onTap: _go),
    );
  }
}

/// No top border, no blur. One gradient that is transparent at the top,
/// solid by the icons, and keeps deepening to the bottom edge.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  static const _fade = 60.0;
  static const _bar = 56.0;

  static double _ease(double x) => x * x * x * (x * (x * 6 - 15) + 10);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final safe = MediaQuery.of(context).padding.bottom;
    final total = _fade + _bar + safe;
    final solidAt = _fade / total;
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= 24; i++) {
      final p = i / 24;
      final alpha = _ease((p / solidAt).clamp(0, 1));
      final tone = Color.lerp(c.background, c.barDeep, _ease(p))!;
      colors.add(tone.withValues(alpha: alpha));
      stops.add(p);
    }
    return IgnorePointer(
      ignoring: false,
      child: Container(
        height: total,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops),
        ),
        padding: EdgeInsets.only(top: _fade, bottom: safe),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(child: _TabButton(tab: _tabs[i], active: i == current, onTap: () => onTap(i))),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.active, required this.onTap});
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.accent : c.textTertiary;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            _TileIcon(icon: tab.icon, color: color, tinted: active),
            const SizedBox(height: 3),
            Text(tab.label, style: AppText.tabLabel.copyWith(color: color), maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.color, required this.tinted});
  final IconData icon;
  final Color color;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 30,
      decoration: ShapeDecoration(
        color: tinted ? context.colors.accentTint : Colors.transparent,
        shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            const SizedBox(height: AppSpace.xxl),
            for (var i = 0; i < _tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.lg),
                child: _TabButton(tab: _tabs[i], active: i == current, onTap: () => onTap(i)),
              ),
          ],
        ),
      ),
    );
  }
}
