import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/delete_record_button.dart';
import '../../../core/widgets/detail.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../core/widgets/module_list.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/bid_book_repository.dart';
import '../../../core/design/app_icons.dart';

class BidBookScreen extends StatelessWidget {
  const BidBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<Bid>(
      title: 'Bid book',
      listProvider: bidBookListProvider,
      queryProvider: bidBookQueryProvider,
      searchHint: 'Search invoice, garden or buyer',
      emptyIcon: AppIcons.bids,
      emptyTitle: 'Add your first lot',
      emptyBody: 'Lots under negotiation show up here with their prices.',
      newLabel: 'New lot',
      onNew: () => context.pushNamed(Routes.bidNew),
      actions: [AddButton(semanticLabel: 'New lot', onPressed: () => context.pushNamed(Routes.bidNew))],
      segments: const SegmentConfig(param: 'tab', options: {
        'all': 'All',
        'open': 'Open',
        'parked': 'Parked',
        'held': 'Held',
        'awaiting_allocation': 'Awaiting',
      }),
      filters: [
        ChoiceFilter('grade', 'Grade', {for (final g in kTeaGrades) g: g}),
        const PickerFilter('mark', 'Mark', pickMark),
      ],
      // All lots of one mark together, in invoice order.
      grouping: ListGrouping(section: (b) => b.gardenName, order: (b) => b.invoiceNumber),
      itemBuilder: (context, b) => BidRow(bid: b),
    );
  }
}

/// One line per lot: grade and invoice, asking price and max bid, status.
/// Packages, buyer and negotiator are on the detail screen.
class BidRow extends StatelessWidget {
  const BidRow({super.key, required this.bid});
  final Bid bid;

  static String _price(double? v) => v == null ? '–' : '₹${Fmt.number(v)}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = bid;
    final figures = AppText.footnote.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pushNamed(Routes.bidDetail, pathParameters: {'id': '${b.id}'}, extra: b),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg - 2, vertical: AppSpace.sm),
            child: Row(
              children: [
                Expanded(
                  child: OneLineText('${b.grade} · ${b.invoiceNumber}',
                      style: AppText.callout.copyWith(fontWeight: FontWeight.w500, color: c.textPrimary)),
                ),
                const SizedBox(width: AppSpace.sm),
                Text('Ask ', style: figures.copyWith(color: c.textTertiary)),
                Text(_price(b.incoming), style: figures.copyWith(color: c.textPrimary)),
                const SizedBox(width: AppSpace.md),
                Text('Max ', style: figures.copyWith(color: c.textTertiary)),
                Text(_price(b.maxBid), style: figures.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
                const SizedBox(width: AppSpace.md),
                StatusBadge(b.status.label, tone: b.status.tone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BidFormScreen extends ConsumerStatefulWidget {
  const BidFormScreen({super.key, this.editing});
  final Bid? editing;

  @override
  ConsumerState<BidFormScreen> createState() => _BidFormScreenState();
}

class _BidFormScreenState extends ConsumerState<BidFormScreen> with FormSubmit {
  late final Bid? _e = widget.editing;
  late final _garden = TextEditingController(text: _e?.gardenName);
  late final _invoice = TextEditingController(text: _e?.invoiceNumber);
  late final _pkgs = TextEditingController(text: _e?.packages?.toString());
  late final _net = TextEditingController(text: Fmt.editable(_e?.netWeight));
  late final _incoming = TextEditingController(text: Fmt.editable(_e?.incoming));
  late final _max = TextEditingController(text: Fmt.editable(_e?.maxBid));
  late final _neg = TextEditingController(text: Fmt.editable(_e?.negotiated));
  late final _pencil = TextEditingController(text: Fmt.editable(_e?.pencil));
  late final _remarks = TextEditingController(text: _e?.remarks);
  late String? _grade = _e?.grade;
  late BidStatus _status = _e?.status ?? BidStatus.open;
  late MasterItem? _buyer = _e?.buyerId == null ? null : MasterItem(_e!.buyerId!, _e.buyerName ?? '#${_e.buyerId}');
  late MasterItem? _negotiator =
      _e?.negotiatorId == null ? null : MasterItem(_e!.negotiatorId!, _e.negotiatorName ?? '#${_e.negotiatorId}');

  @override
  void dispose() {
    for (final c in [_garden, _invoice, _pkgs, _net, _incoming, _max, _neg, _pencil, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final body = <String, Object?>{
      'garden_name': _garden.text.trim(),
      'grade': _grade,
      'invoice_number': _invoice.text.trim(),
      'packages': int.tryParse(_pkgs.text),
      'net_weight': Fmt.parse(_net.text),
      'seller_incoming_price': Fmt.parse(_incoming.text),
      'max_bid': Fmt.parse(_max.text),
      'negotiated_price': Fmt.parse(_neg.text),
      'pencil_price': Fmt.parse(_pencil.text),
      'status': _status.api,
      'buyer_id': _buyer?.id,
      'negotiator_id': _negotiator?.id,
      'remarks': _remarks.text.trim(),
    };
    final repo = ref.read(bidBookRepositoryProvider);
    final ok = await submit<bool>(
      () async {
        if (_e == null) {
          await repo.create(body);
        } else {
          await repo.update(_e.id, body);
        }
        return true;
      },
      clientErrors: {
        if (_garden.text.trim().isEmpty) 'garden_name': 'Enter the garden or mark.',
        if (_grade == null) 'grade': 'Choose a grade.',
        if (_invoice.text.trim().isEmpty) 'invoice_number': 'Enter the invoice number.',
        if (int.tryParse(_pkgs.text) == null) 'packages': 'Enter the packages.',
        if (Fmt.parse(_net.text) == null) 'net_weight': 'Enter the net weight.',
      },
    );
    if (ok == true && mounted) {
      ref.invalidate(bidBookListProvider);
      refreshSummaries(ref);
      context.toast(_e == null ? 'Lot saved' : 'Lot updated');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    TextInputType money() => const TextInputType.numberWithOptions(decimal: true);
    return FormScaffold(
      title: _e == null ? 'New lot' : 'Edit lot',
      submitLabel: _e == null ? 'Save lot' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Lot',
          children: [
            FieldInput(label: 'Garden or mark', hint: 'Assam Valley', controller: _garden, error: err('garden_name')),
            GradePickerRow(value: _grade, onChanged: (g) => setState(() => _grade = g), error: err('grade')),
            FieldInput(label: 'Invoice number', hint: 'INV-BB-891', controller: _invoice, error: err('invoice_number')),
            Row(children: [
              Expanded(child: FieldInput(label: 'Packages', hint: '30', controller: _pkgs, error: err('packages'), keyboardType: TextInputType.number, inputFormatters: digitsOnly)),
              Expanded(child: FieldInput(label: 'Net weight', hint: '1050', suffix: 'kg', controller: _net, error: err('net_weight'), keyboardType: money(), inputFormatters: decimalOnly)),
            ]),
          ],
        ),
        GroupedSection(
          label: 'Pricing per kg',
          children: [
            Row(children: [
              Expanded(child: FieldInput(label: 'Seller incoming', hint: '270.00', suffix: '₹', controller: _incoming, keyboardType: money(), inputFormatters: decimalOnly)),
              Expanded(child: FieldInput(label: 'Max bid', hint: '290.00', suffix: '₹', controller: _max, keyboardType: money(), inputFormatters: decimalOnly)),
            ]),
            Row(children: [
              Expanded(child: FieldInput(label: 'Negotiated', hint: '285.00', suffix: '₹', controller: _neg, keyboardType: money(), inputFormatters: decimalOnly)),
              Expanded(child: FieldInput(label: 'Pencil', hint: '288.00', suffix: '₹', controller: _pencil, keyboardType: money(), inputFormatters: decimalOnly)),
            ]),
          ],
        ),
        GroupedSection(
          label: 'Assignment',
          footer: const Text('Leave the buyer empty to keep the lot unallocated.'),
          children: [
            ValueRow(
              label: 'Status',
              value: _status.label,
              error: err('status'),
              onTap: () async {
                final s = await showPickerSheet<BidStatus>(context,
                    title: 'Status', selected: _status, options: [for (final s in BidStatus.values) PickOption(s, s.label)]);
                if (s != null) setState(() => _status = s);
              },
            ),
            MasterPickerRow(label: 'Buyer', provider: buyersProvider, value: _buyer, placeholder: 'Unallocated', onChanged: (b) => setState(() => _buyer = b), error: err('buyer_id')),
            MasterPickerRow(label: 'Negotiator', provider: negotiatorsProvider, value: _negotiator, placeholder: 'None', onChanged: (n) => setState(() => _negotiator = n), error: err('negotiator_id')),
          ],
        ),
        GroupedSection(children: [FieldInput(label: 'Remarks', hint: 'High quality orthodox lot', controller: _remarks, maxLines: 3)]),
      ],
    );
  }
}

class BidDetailScreen extends ConsumerStatefulWidget {
  const BidDetailScreen({super.key, required this.bid});
  final Bid? bid;

  @override
  ConsumerState<BidDetailScreen> createState() => _BidDetailScreenState();
}

class _BidDetailScreenState extends ConsumerState<BidDetailScreen> {
  late BidStatus? _status = widget.bid?.status;
  bool _busy = false;

  Future<void> _setStatus(BidStatus s) async {
    final b = widget.bid!;
    if (_busy || s == _status) return;
    setState(() => _busy = true);
    try {
      await ref.read(bidBookRepositoryProvider).update(b.id, {'status': s.api});
      if (!mounted) return;
      setState(() => _status = s);
      ref.invalidate(bidBookListProvider);
      refreshSummaries(ref);
      context.toast('Lot marked ${s.label.toLowerCase()}');
    } on AppFailure catch (f) {
      if (mounted) context.toast(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bid;
    if (b == null) return const MissingItemScreen(what: 'lot');
    final c = context.colors;
    final status = _status ?? b.status;
    return DetailScaffold(
      title: b.gardenName,
      actions: [LinkButton(label: 'Edit', onPressed: () => context.pushNamed(Routes.bidEdit, pathParameters: {'id': '${b.id}'}, extra: b))],
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: OneLineText('${b.grade} · ${b.invoiceNumber}', style: AppText.headline)),
                StatusBadge(status.label, tone: status.tone),
              ]),
              const SizedBox(height: AppSpace.lg),
              for (final (label, v, strong) in [
                ('Seller incoming', b.incoming, false),
                ('Max bid', b.maxBid, false),
                ('Negotiated', b.negotiated, true),
                ('Pencil', b.pencil, false),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Text(label, style: AppText.callout.copyWith(color: c.textSecondary))),
                    Text(Fmt.money(v), style: AppText.callout.copyWith(color: strong ? c.accent : c.textPrimary, fontWeight: strong ? FontWeight.w600 : FontWeight.w400)),
                  ]),
                ),
            ],
          ),
        ),
        GroupedSection(
          label: 'Lot',
          children: [
            InfoRow('Packages', Fmt.number(b.packages)),
            InfoRow('Net weight', Fmt.kg(b.netWeight)),
            InfoRow('Buyer', b.buyerName ?? (b.buyerId == null ? 'Unallocated' : '#${b.buyerId}'), valueColor: b.buyerId == null ? c.warning : null),
            InfoRow('Negotiator', b.negotiatorName ?? (b.negotiatorId == null ? null : '#${b.negotiatorId}')),
            if (b.remarks != null) InfoBlock('Remarks', b.remarks!),
          ],
        ),
        GroupedSection(
          label: 'Change status',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Segmented<BidStatus>(
                options: {for (final s in BidStatus.values) s: s.label},
                selected: status,
                onChanged: _setStatus,
              ),
            ),
          ],
        ),
        DeleteRecordButton(
          what: 'lot',
          name: '${b.gardenName} · ${b.grade} (${b.invoiceNumber})',
          onDelete: (ref) => ref.read(bidBookRepositoryProvider).delete(b.id),
          onDeleted: (ref) => ref.invalidate(bidBookListProvider),
        ),
      ],
    );
  }
}
