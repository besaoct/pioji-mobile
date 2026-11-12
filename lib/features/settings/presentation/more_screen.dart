import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../../ex_factory/data/ex_factory_repository.dart';
import '../../../core/design/app_icons.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final auth = ref.watch(authControllerProvider).value;
    final user = auth is Authenticated ? auth.user : null;
    final ex = ref.watch(exFactoryMetricsProvider).value;
    final mismatches = ex == null ? 0 : (ex[RegisterStatus.priceMismatch] ?? 0) + (ex[RegisterStatus.qtyMismatch] ?? 0);

    Widget reg(AppIcons icon, String label, String route, {String? meta}) => AppListRow(
          title: label,
          titleStyle: AppText.body,
          minHeight: 50,
          leading: IconTile(icon: icon),
          trailing: meta == null ? null : Text(meta, style: AppText.footnote.copyWith(color: c.warning)),
          showChevron: true,
          onTap: () => context.pushNamed(route),
        );

    return PageScaffold(
      title: 'More',
      slivers: [
        SliverList.list(
          children: [
            if (user != null) ...[
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: c.accentTint,
                      child: Text(user.initial, style: AppText.headline.copyWith(color: c.accent)),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OneLineText(user.name, style: AppText.body.copyWith(fontWeight: FontWeight.w500)),
                          if (user.email.isNotEmpty) OneLineText(user.email, style: AppText.footnote.copyWith(color: c.textTertiary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ],
            GroupedSection(
              label: 'Registers',
              dividerIndent: 56,
              children: [
                reg(AppIcons.courier, 'Courier register', Routes.courier),
                reg(AppIcons.contracts, 'Contracts', Routes.contracts),
                reg(AppIcons.sales, 'Sales register', Routes.sales),
                reg(AppIcons.exFactory, 'Ex-factory register', Routes.exFactory, meta: mismatches > 0 ? '$mismatches mismatches' : null),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            GroupedSection(
              label: 'Account',
              children: [
                AppListRow(title: 'Settings', titleStyle: AppText.body, minHeight: 50, showChevron: true, onTap: () => context.pushNamed(Routes.settings)),
                AppListRow(
                  title: 'Sign out',
                  titleStyle: AppText.body.copyWith(color: c.danger),
                  minHeight: 50,
                  onTap: () async {
                    final ok = await confirm(context, title: 'Sign out?', body: "You'll need your password to sign in again.", action: 'Sign out', destructive: true);
                    if (ok) await ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return DetailScaffold(
      title: 'Settings',
      children: [
        GroupedSection(
          label: 'Appearance',
          children: [
            for (final m in ThemeMode.values)
              AppListRow(
                title: switch (m) { ThemeMode.system => 'System', ThemeMode.light => 'Light', ThemeMode.dark => 'Dark' },
                titleStyle: AppText.body,
                minHeight: 48,
                trailing: m == mode ? AppIcon(AppIcons.check, color: context.colors.accent, size: 20) : null,
                onTap: () => ref.read(themeModeProvider.notifier).set(m),
              ),
          ],
        ),
        GroupedSection(
          label: 'About',
          children: [
            AppListRow(
              title: 'Version',
              titleStyle: AppText.body,
              minHeight: 48,
              trailing: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (_, snap) => Text(snap.hasData ? '${snap.data!.version} (${snap.data!.buildNumber})' : ''),
              ),
            ),
            AppListRow(title: 'Terms of service', titleStyle: AppText.body, minHeight: 48, showChevron: true, onTap: () => context.pushNamed(Routes.legal, pathParameters: {'doc': 'terms'})),
            AppListRow(title: 'Privacy policy', titleStyle: AppText.body, minHeight: 48, showChevron: true, onTap: () => context.pushNamed(Routes.legal, pathParameters: {'doc': 'privacy'})),
          ],
        ),
      ],
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context) {
    final privacy = doc == 'privacy';
    final text = privacy
        ? 'What this app stores on your device:\n\n'
            '• Your sign-in token, in the iOS Keychain or Android Keystore.\n'
            '• Your name and email, so the app can show who is signed in.\n'
            '• Your appearance setting and whether you have seen onboarding.\n\n'
            'What it sends:\n\n'
            '• Only the records you create or edit, to your company\'s Pioji server.\n'
            '• Parcel photos, only when you attach one to a courier entry.\n\n'
            'Signing out removes the token from this device. The app has no analytics or advertising.'
        : 'This app is for authorised staff of your organisation. Use it only for work records you are allowed to create or view. '
            'Your organisation\'s policies on data handling apply to everything you enter. '
            'Replace this text with your organisation\'s terms before release.';
    return DetailScaffold(
      title: privacy ? 'Privacy policy' : 'Terms of service',
      children: [AppCard(padding: const EdgeInsets.all(AppSpace.lg), child: Text(text, style: AppText.callout))],
    );
  }
}
