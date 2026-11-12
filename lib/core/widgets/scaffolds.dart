import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'buttons.dart';
import 'controls.dart';
import 'one_line_text.dart';
import 'states.dart';
import '../design/app_icons.dart';

/// Height reserved at the bottom of tab screens for the tab bar.
const kTabBarReserve = 120.0;

/// Fixed 56 px top bar: optional back or close button, title (with an
/// optional caption under it) and actions on the right.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.title, this.caption, this.leading, this.actions = const []});

  final String title;
  final String? caption;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.only(left: leading == null ? AppSpace.screenH : AppSpace.xs, right: AppSpace.sm),
        child: Row(
          children: [
            ?leading,
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OneLineText(title, style: (leading == null ? AppText.title : AppText.headline).copyWith(color: c.textPrimary)),
                    if (caption != null) OneLineText(caption!, style: AppText.footnote.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Square 44 px icon button for top bars.
class TopBarIcon extends StatelessWidget {
  const TopBarIcon({super.key, required this.icon, required this.semanticLabel, required this.onPressed, this.color});

  final AppIcons icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: AppIcon(icon, size: 22, color: color ?? context.colors.textPrimary)),
        ),
      ),
    );
  }
}

/// Tab root and pushed list screens: fixed top bar, then a scrolling body
/// with optional header widgets and pull-to-refresh.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
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
    final canPop = showBack || GoRouter.of(context).canPop();
    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screenH, AppSpace.xs, AppSpace.screenH, 0),
          sliver: SliverList.list(
            children: [
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
    if (onRefresh != null) scroll = AppRefresh(onRefresh: onRefresh!, child: scroll);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(title: title, caption: caption, leading: canPop ? const BackLink() : null, actions: actions),
            Expanded(child: scroll),
          ],
        ),
      ),
    );
  }
}

/// Back arrow for top bars.
class BackLink extends StatelessWidget {
  const BackLink({super.key, this.label = 'Back'});
  final String label;

  @override
  Widget build(BuildContext context) =>
      TopBarIcon(icon: AppIcons.chevronLeft, semanticLabel: label, onPressed: () => context.pop());
}

/// Full-screen form above the tab bar: close / title / optional trailing,
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
            AppTopBar(
              title: title,
              leading: TopBarIcon(icon: AppIcons.close, semanticLabel: 'Cancel', onPressed: onCancel ?? () => context.pop()),
              actions: [?trailing],
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

/// Pushed read-only screen with a back arrow and a title.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.children, this.actions = const []});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
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
