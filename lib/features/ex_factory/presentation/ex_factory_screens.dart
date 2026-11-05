import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/delete_record_button.dart';
import '../../../core/widgets/detail.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../core/widgets/module_list.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/ex_factory_repository.dart';

class ExFactoryListScreen extends ConsumerStatefulWidget {
  const ExFactoryListScreen({super.key});

  @override
  ConsumerState<ExFactoryListScreen> createState() => _ExFactoryListScreenState();
}

class _ExFactoryListScreenState extends ConsumerState<ExFactoryListScreen> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await ref.read(exFactoryRepositoryProvider).export(ref.read(exFactoryQueryProvider));
      await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: 'text/csv')]));
    } on AppFailure catch (f) {
      if (mounted) context.toast(f.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(exFactoryMetricsProvider).value;
    final current = ref.watch(exFactoryQueryProvider).params['register_status'];
    final c = context.colors;
    return ModuleListScreen<ExFactoryBill>(
      title: 'Ex-factory',
      inTabs: false,
      listProvider: exFactoryListProvider,
      queryProvider: exFactoryQueryProvider,
      searchHint: 'Search bill, supplier, mark or transporter',
      emptyIcon: CupertinoIcons.doc_chart,
      emptyTitle: 'Add your first bill',
      emptyBody: 'Bills are matched against the sales register automatically.',
      newLabel: 'New bill',
      onNew: () => context.pushNamed(Routes.exFactoryNew),
      actions: [
        _exporting
            ? const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: CupertinoActivityIndicator())
            : LinkButton(label: 'Export', onPressed: _export),
        AddButton(semanticLabel: 'New bill', onPressed: () => context.pushNamed(Routes.exFactoryNew)),
      ],
      filters: const [DateFilter('start_date', 'From'), DateFilter('end_date', 'To')],
      header: [
        GridView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 64,
          ),
          children: [
            for (final s in RegisterStatus.values)
              AppCard(
                onTap: () => ref.read(exFactoryQueryProvider.notifier).setParam('register_status', current == s.api ? null : s.api),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  color: current == s.api ? c.accentTint : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OneLineText(s.label, style: AppText.footnote.copyWith(color: c.textTertiary)),
                      FitText(metrics == null ? '–' : Fmt.number(metrics[s]),
                          style: AppText.headline.copyWith(color: toneColor(context, s.tone))),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
      ],
      itemBuilder: (context, b) => AppListRow(
        title: [b.billNo ?? b.mark ?? 'Bill', Fmt.invoice(b.invoicePrefix, b.invoiceNo)].where((e) => e.isNotEmpty).join(' · '),
        subtitle: [b.supplierName, b.mark, Fmt.day(b.billDate)].whereType<String>().join(' · '),
        onTap: () => context.pushNamed(Routes.exFactoryDetail, pathParameters: {'id': '${b.id}'}, extra: b),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Fmt.money(b.total), style: AppText.callout.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (b.status != null) StatusBadge(b.status!.label, tone: b.status!.tone),
          ],
        ),
      ),
    );
  }
}

class ExFactoryFormScreen extends ConsumerStatefulWidget {
  const ExFactoryFormScreen({super.key});

  @override
  ConsumerState<ExFactoryFormScreen> createState() => _ExFactoryFormScreenState();
}

class _ExFactoryFormScreenState extends ConsumerState<ExFactoryFormScreen> with FormSubmit {
  static const _gstRate = 0.05;
  DateTime _date = DateTime.now();
  DateTime? _cnDate;
  MasterItem? _supplier;
  bool _igst = true;
  bool _totalEdited = false;
  final _mark = TextEditingController();
  final _prefix = TextEditingController();
  final _inv = TextEditingController();
  final _pkgs = TextEditingController();
  final _nett = TextEditingController();
  final _taxable = TextEditingController();
  final _igstAmt = TextEditingController();
  final _cgstAmt = TextEditingController();
  final _sgstAmt = TextEditingController();
  final _total = TextEditingController();
  final _cn = TextEditingController();
  final _transport = TextEditingController();
  final _credit = TextEditingController();

  @override
  void dispose() {
    for (final c in [_mark, _prefix, _inv, _pkgs, _nett, _taxable, _igstAmt, _cgstAmt, _sgstAmt, _total, _cn, _transport, _credit]) {
      c.dispose();
    }
    super.dispose();
  }

  double _tax() => _igst
      ? (Fmt.parse(_igstAmt.text) ?? 0)
      : (Fmt.parse(_cgstAmt.text) ?? 0) + (Fmt.parse(_sgstAmt.text) ?? 0);

  void _recalc() {
    if (!_totalEdited) {
      final t = Fmt.parse(_taxable.text);
      _total.text = t == null ? '' : (t + _tax()).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _suggestTax() {
    final t = Fmt.parse(_taxable.text);
    if (t == null) return;
    if (_igst) {
      _igstAmt.text = (t * _gstRate).toStringAsFixed(2);
    } else {
      _cgstAmt.text = (t * _gstRate / 2).toStringAsFixed(2);
      _sgstAmt.text = (t * _gstRate / 2).toStringAsFixed(2);
    }
    _recalc();
  }

  Future<void> _save() async {
    final res = await submit<({ExFactoryBill? bill})>(
      () async => (bill: await ref.read(exFactoryRepositoryProvider).create({
        'bill_date': Fmt.api(_date),
        'mark': _mark.text.trim(),
        'invoice_no': _inv.text.trim(),
        'invoice_prefix': _prefix.text.trim(),
        'supplier_id': _supplier?.id,
        'pkgs': int.tryParse(_pkgs.text),
        'nett': Fmt.parse(_nett.text),
        'taxable_value': Fmt.parse(_taxable.text),
        'gst_type': _igst ? 'igst' : 'cgst_sgst',
        'igst_amount': _igst ? Fmt.parse(_igstAmt.text) : null,
        'cgst_amount': _igst ? null : Fmt.parse(_cgstAmt.text),
        'sgst_amount': _igst ? null : Fmt.parse(_sgstAmt.text),
        'total_bill_value': Fmt.parse(_total.text),
        'cn_number': _cn.text.trim(),
        'cn_date': _cnDate == null ? null : Fmt.api(_cnDate!),
        'transport': _transport.text.trim(),
        'credit_days': int.tryParse(_credit.text),
      })),
      clientErrors: {
        if (_mark.text.trim().isEmpty) 'mark': 'Enter the mark.',
        if (_inv.text.trim().isEmpty) 'invoice_no': 'Enter the invoice number.',
        if (int.tryParse(_pkgs.text) == null) 'pkgs': 'Enter the packages.',
        if (Fmt.parse(_nett.text) == null) 'nett': 'Enter the total weight.',
        if (Fmt.parse(_taxable.text) == null) 'taxable_value': 'Enter the taxable value.',
      },
    );
    if (res == null || !mounted) return;
    ref.invalidate(exFactoryListProvider);
    ref.invalidate(exFactoryMetricsProvider);
    refreshSummaries(ref);
    final s = res.bill?.status;
    context.toast(s == null ? 'Bill saved' : 'Bill saved · ${s.label}');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    TextInputType dec() => const TextInputType.numberWithOptions(decimal: true);
    return FormScaffold(
      title: 'New bill',
      submitLabel: 'Save bill',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Bill',
          children: [
            DateRow(label: 'Bill date', value: _date, onChanged: (d) => setState(() => _date = d), error: err('bill_date')),
            MasterPickerRow(label: 'Supplier', provider: sellersProvider, value: _supplier, placeholder: 'Optional', onChanged: (s) => setState(() => _supplier = s)),
            FieldInput(label: 'Mark', hint: 'Assam Valley Mark', controller: _mark, error: err('mark')),
            Row(children: [
              SizedBox(width: 120, child: FieldInput(label: 'Prefix', hint: 'IVP', controller: _prefix, textCapitalization: TextCapitalization.characters)),
              Expanded(child: FieldInput(label: 'Invoice no', hint: '9812', controller: _inv, error: err('invoice_no'))),
            ]),
          ],
        ),
        GroupedSection(
          label: 'Quantity',
          children: [
            Row(children: [
              Expanded(child: FieldInput(label: 'Packages', hint: '25', controller: _pkgs, error: err('pkgs'), keyboardType: TextInputType.number, inputFormatters: digitsOnly)),
              Expanded(child: FieldInput(label: 'Nett', hint: '875', suffix: 'kg', controller: _nett, error: err('nett'), keyboardType: dec(), inputFormatters: decimalOnly)),
            ]),
          ],
        ),
        GroupedSection(
          label: 'Tax',
          footer: Text('Suggested GST is 5% of the taxable value. You can edit it.'),
          children: [
            FieldInput(label: 'Taxable value', hint: '271250.00', suffix: '₹', controller: _taxable, error: err('taxable_value'), onChanged: (_) => _recalc(), keyboardType: dec(), inputFormatters: decimalOnly),
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Segmented<bool>(
                options: const {true: 'IGST', false: 'CGST + SGST'},
                selected: _igst,
                onChanged: (v) {
                  _igst = v;
                  _recalc();
                },
              ),
            ),
            if (_igst)
              FieldInput(label: 'IGST amount', hint: '13562.50', suffix: '₹', controller: _igstAmt, error: err('igst_amount'), onChanged: (_) => _recalc(), keyboardType: dec(), inputFormatters: decimalOnly,
                  trailing: LinkButton(label: 'Fill 5%', style: AppText.footnote, onPressed: _suggestTax))
            else ...[
              FieldInput(label: 'CGST amount', hint: '6781.25', suffix: '₹', controller: _cgstAmt, error: err('cgst_amount'), onChanged: (_) => _recalc(), keyboardType: dec(), inputFormatters: decimalOnly,
                  trailing: LinkButton(label: 'Fill 5%', style: AppText.footnote, onPressed: _suggestTax)),
              FieldInput(label: 'SGST amount', hint: '6781.25', suffix: '₹', controller: _sgstAmt, error: err('sgst_amount'), onChanged: (_) => _recalc(), keyboardType: dec(), inputFormatters: decimalOnly),
            ],
            FieldInput(
              label: 'Total bill value',
              caption: _totalEdited ? null : 'Calculated',
              captionAccent: !_totalEdited,
              suffix: '₹',
              controller: _total,
              onChanged: (_) => setState(() => _totalEdited = true),
              keyboardType: dec(),
              inputFormatters: decimalOnly,
            ),
          ],
        ),
        GroupedSection(
          label: 'Dispatch',
          children: [
            FieldInput(label: 'CN number', hint: 'CN-44129', controller: _cn),
            DateRow(label: 'CN date', value: _cnDate, onChanged: (d) => setState(() => _cnDate = d)),
            FieldInput(label: 'Transport', hint: 'V-Trans Logistics', controller: _transport),
            FieldInput(label: 'Credit days', hint: '15', controller: _credit, keyboardType: TextInputType.number, inputFormatters: digitsOnly, textInputAction: TextInputAction.done),
          ],
        ),
      ],
    );
  }
}

class ExFactoryDetailScreen extends StatelessWidget {
  const ExFactoryDetailScreen({super.key, required this.bill});
  final ExFactoryBill? bill;

  @override
  Widget build(BuildContext context) {
    final b = bill;
    if (b == null) return const MissingItemScreen(what: 'bill');
    return DetailScaffold(
      title: b.billNo ?? b.mark ?? 'Bill',
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text(Fmt.money(b.total), style: AppText.metric)),
            if (b.status != null) StatusBadge(b.status!.label, tone: b.status!.tone),
          ]),
        ),
        GroupedSection(
          label: 'Bill',
          children: [
            InfoRow('Date', Fmt.day(b.billDate)),
            InfoRow('Supplier', b.supplierName),
            InfoRow('Mark', b.mark),
            InfoRow('Invoice', Fmt.invoice(b.invoicePrefix, b.invoiceNo)),
            InfoRow('Packages', b.pkgs?.toString()),
            InfoRow('Nett', Fmt.kg(b.nett)),
          ],
        ),
        GroupedSection(
          label: 'Tax',
          children: [
            InfoRow('Taxable value', Fmt.money(b.taxableValue)),
            if (b.gstType == 'cgst_sgst') ...[
              InfoRow('CGST', Fmt.money(b.cgst)),
              InfoRow('SGST', Fmt.money(b.sgst)),
            ] else
              InfoRow('IGST', Fmt.money(b.igst)),
          ],
        ),
        GroupedSection(
          label: 'Dispatch',
          children: [
            InfoRow('CN number', b.cnNumber),
            InfoRow('Transport', b.transport),
            InfoRow('Credit days', b.creditDays?.toString()),
          ],
        ),
        DeleteRecordButton(
          what: 'bill',
          name: [b.billNo, b.mark, Fmt.invoice(b.invoicePrefix, b.invoiceNo)].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
          onDelete: (ref) => ref.read(exFactoryRepositoryProvider).delete(b.id),
          onDeleted: (ref) {
            ref.invalidate(exFactoryListProvider);
            ref.invalidate(exFactoryMetricsProvider);
          },
        ),
      ],
    );
  }
}
