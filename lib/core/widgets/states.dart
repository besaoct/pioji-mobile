import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_provider.dart';
import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../errors/app_failure.dart';
import 'buttons.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: c.textTertiary),
          const SizedBox(height: AppSpace.md),
          Text(title, style: AppText.headline, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs + 2),
          Text(body, style: AppText.callout.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpace.lg),
            SecondaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is AppFailure ? error as AppFailure : UnknownFailure(error);
    return EmptyState(
      icon: failure is OfflineFailure ? CupertinoIcons.wifi_slash : CupertinoIcons.exclamationmark_circle,
      title: failure is OfflineFailure ? "You're offline" : "Couldn't load this",
      body: failure.message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

/// Pulsing placeholder rows in the same shape as real rows (no layout shift).
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 6, this.rowHeight = 64});

  final int rows;
  final double rowHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, _) {
          final o = reduce ? 0.7 : 0.45 + _ac.value * 0.4;
          Widget bar(double w, double h) => Container(
                width: w,
                height: h,
                decoration: BoxDecoration(color: c.fill.withValues(alpha: o), borderRadius: BorderRadius.circular(5)),
              );
          return Container(
            decoration: ShapeDecoration(color: c.surface, shape: AppRadius.cardBorder, shadows: c.cardShadow),
            child: Column(
              children: [
                for (var i = 0; i < widget.rows; i++) ...[
                  if (i > 0) const Divider(indent: AppSpace.lg, height: 0.5),
                  SizedBox(
                    height: widget.rowHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [bar(150, 13), const SizedBox(height: 8), bar(100, 10)],
                            ),
                          ),
                          bar(56, 13),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(color: c.warning.withValues(alpha: 0.12), shape: AppRadius.controlBorder),
      child: Row(
        children: [
          Icon(CupertinoIcons.wifi_slash, size: 16, color: c.warning),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text("You're offline. Changes can't be saved until you reconnect.",
                style: AppText.footnote.copyWith(color: c.warning)),
          ),
        ],
      ),
    );
  }
}

/// Inline error banner at the top of a form, for errors without a field.
class FormBanner extends StatelessWidget {
  const FormBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ShapeDecoration(color: c.danger.withValues(alpha: 0.09), shape: AppRadius.controlBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle, size: 18, color: c.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.callout.copyWith(color: c.danger))),
        ],
      ),
    );
  }
}
