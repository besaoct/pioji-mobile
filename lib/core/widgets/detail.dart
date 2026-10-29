import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../design/context_ext.dart';
import '../design/typography.dart';
import 'one_line_text.dart';
import 'scaffolds.dart';
import 'states.dart';

/// Read-only label/value row for detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label: ${value ?? 'not set'}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(label, style: AppText.callout.copyWith(color: c.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: OneLineText(
                  value ?? '–',
                  textAlign: TextAlign.right,
                  style: AppText.callout.copyWith(color: valueColor ?? c.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-line text block (remarks, terms, addresses).
class InfoBlock extends StatelessWidget {
  const InfoBlock(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w400)),
          const SizedBox(height: 4),
          Text(value, style: AppText.callout),
        ],
      ),
    );
  }
}

/// Shown when a detail route opens without its record (for example from a
/// deep link): the API has no single-record endpoints yet.
class MissingItemScreen extends StatelessWidget {
  const MissingItemScreen({super.key, required this.what});
  final String what;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: what,
      children: [
        EmptyState(
          icon: CupertinoIcons.doc_text_search,
          title: "Couldn't open this",
          body: 'Open the $what from its list.',
          actionLabel: 'Go home',
          onAction: () => context.go('/home'),
        ),
      ],
    );
  }
}
