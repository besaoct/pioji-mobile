import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';

class _Page {
  const _Page(this.title, this.body, this.icon, this.rows);
  final String title;
  final String body;
  final IconData icon;
  final List<(String, String)> rows;
}

const _pages = [
  _Page(
    'Track every lot',
    'Offer lists, samples and batches in one place, from arrival to the tasting table.',
    CupertinoIcons.lab_flask,
    [('Samples', 'Arrival, grade and weight'), ('Batches', 'Up to 48 samples each')],
  ),
  _Page(
    'Allocate and bid faster',
    "Assign buyers to today's samples and manage the bid book on the go.",
    CupertinoIcons.hammer,
    [('Allocation', 'One lot or many at once'), ('Bid book', 'Open, parked, held, closed')],
  ),
  _Page(
    'Close the loop',
    'Courier, contracts, sales and ex-factory reconciliation, all from your phone.',
    CupertinoIcons.checkmark_seal,
    [('Courier', 'Scan tracking numbers'), ('Ex-factory', 'Matched against sales')],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  // The router redirects to login as soon as onboarding is marked seen.
  void _finish() => ref.read(onboardingSeenProvider.notifier).markSeen();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.xl),
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: LinkButton(label: 'Skip', onPressed: _finish)),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) => _PageView(page: _pages[i]),
                ),
              ),
              Semantics(
                label: 'Page ${_i + 1} of ${_pages.length}',
                child: Row(
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _i ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _i ? c.accentFill : c.separator,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              PrimaryButton(
                label: last ? 'Get started' : 'Continue',
                onPressed: last
                    ? _finish
                    : () => _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});
  final _Page page;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: ShapeDecoration(color: c.accentTint, shape: AppRadius.controlBorder),
                child: Icon(page.icon, color: c.accent, size: 26),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in page.rows) ...[
                      Text(r.$1, style: AppText.headline),
                      Text(r.$2, style: AppText.footnote.copyWith(color: c.textTertiary)),
                      if (r != page.rows.last) const SizedBox(height: AppSpace.sm),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxl + 4),
        Text(page.title, style: AppText.largeTitle),
        const SizedBox(height: AppSpace.sm + 2),
        Text(page.body, style: AppText.body.copyWith(color: c.textSecondary, fontSize: 17, height: 1.45)),
      ],
    );
  }
}
