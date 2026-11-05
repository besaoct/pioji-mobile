import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'buttons.dart';
import 'one_line_text.dart';
import 'states.dart';

/// Height reserved at the bottom of tab screens for the tab bar.
const kTabBarReserve = 120.0;

/// Tab root and pushed list screens: actions row, large title, scrolling
/// content, pull-to-refresh.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.caption,
    this.actions = const [],
    this.header = const [],
    required this.slivers,
    this.onRefresh,
    this.controller,
    this.showBack = false,
    this.inTabs = true,
  });

  final String title;
  final String? caption;
  final List<Widget> actions;
  final List<Widget> header;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final bool showBack;
  final bool inTabs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canPop = showBack || GoRouter.of(context).canPop();
    final topBar = SizedBox(
      height: 44,
      child: Row(
        children: [
          if (canPop) const BackLink(),
          const Spacer(),
          ...actions,
        ],
      ),
    );

    final scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
          sliver: SliverList.list(
            children: [
              topBar,
              if (caption != null)
                Text(caption!, style: AppText.footnote.copyWith(color: c.textTertiary)),
              Semantics(header: true, child: OneLineText(title, style: AppText.largeTitle)),
              const SizedBox(height: AppSpace.md),
              const OfflineBanner(),
              ...header,
            ],
          ),
        ),
        for (final s in slivers)
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH), sliver: s),
        SliverToBoxAdapter(child: SizedBox(height: inTabs ? kTabBarReserve : AppSpace.xxxl)),
      ],
    );

    return Scaffold(body: SafeArea(bottom: false, child: scroll));
  }
}

class BackLink extends StatelessWidget {
  const BackLink({super.key, this.label = 'Back'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pop(),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(CupertinoIcons.chevron_left, color: c.accent, size: 22),
              Text(label, style: AppText.body.copyWith(color: c.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen form above the tab bar: Cancel / title / optional trailing,
/// scrolling body, sticky primary button above the keyboard.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.submitting = false,
    this.onCancel,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool submitting;
  final VoidCallback? onCancel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 88,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: LinkButton(label: 'Cancel', onPressed: onCancel ?? () => context.pop()),
                      ),
                    ),
                    Expanded(
                      child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline),
                    ),
                    SizedBox(width: 88, child: Align(alignment: Alignment.centerRight, child: trailing)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(AppSpace.screenH, AppSpace.xs, AppSpace.screenH, AppSpace.xl),
                  children: [
                    const OfflineBanner(),
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpace.lg + 2),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
            Container(
              color: c.background,
              padding: EdgeInsets.fromLTRB(
                AppSpace.screenH,
                AppSpace.sm,
                AppSpace.screenH,
                MediaQuery.of(context).viewInsets.bottom > 0 ? AppSpace.sm : bottomInset + AppSpace.sm,
              ),
              child: PrimaryButton(label: submitLabel, onPressed: onSubmit, loading: submitting),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pushed read-only screen with a back link and a title.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.children, this.actions = const []});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(
      title: title,
      actions: actions,
      inTabs: false,
      showBack: true,
      slivers: [
        SliverList.separated(
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.lg + 2),
          itemBuilder: (_, i) => children[i],
        ),
      ],
    );
  }
}
