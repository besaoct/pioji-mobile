import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
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
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/courier_repository.dart';

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class CourierListScreen extends StatelessWidget {
  const CourierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<CourierEntry>(
      title: 'Courier register',
      inTabs: false,
      listProvider: courierListProvider,
      queryProvider: courierQueryProvider,
      searchHint: 'Search entry, tracking, courier or buyer',
      emptyIcon: CupertinoIcons.cube_box,
      emptyTitle: 'Log your first parcel',
      emptyBody: 'Sample parcels sent to buyers show up here with their tracking number.',
      newLabel: 'New entry',
      onNew: () => context.pushNamed(Routes.courierNew),
      actions: [AddButton(semanticLabel: 'New courier entry', onPressed: () => context.pushNamed(Routes.courierNew))],
      filters: [
        const DateFilter('date', 'Date'),
        ChoiceFilter('pickup_day', 'Pickup day', {for (final d in _days) d: d}),
      ],
      itemBuilder: (context, e) => AppListRow(
        title: e.buyerName ?? e.destinationAddress ?? 'Courier entry',
        subtitle: [e.courierName, e.trackingNumber].whereType<String>().join(' · '),
        onTap: () => context.pushNamed(Routes.courierDetail, pathParameters: {'id': '${e.id}'}, extra: e),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Fmt.dayShort(e.pickupDate), style: AppText.callout.copyWith(color: context.colors.textSecondary)),
            if (e.weight != null) Text(Fmt.kg(e.weight), style: AppText.footnote.copyWith(color: context.colors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class CourierFormScreen extends ConsumerStatefulWidget {
  const CourierFormScreen({super.key, this.editing});

  /// The entry to edit; null creates a new one.
  final CourierEntry? editing;

  @override
  ConsumerState<CourierFormScreen> createState() => _CourierFormScreenState();
}

class _CourierFormScreenState extends ConsumerState<CourierFormScreen> with FormSubmit {
  late final CourierEntry? _e = widget.editing;
  late bool _toBuyer = _e == null || _e.courierAddressId == null;
  late MasterItem? _buyer = _e?.buyerId == null ? null : MasterItem(_e!.buyerId!, _e.buyerName ?? '#${_e.buyerId}');
  late MasterItem? _address = _e?.courierAddressId == null
      ? null
      : MasterItem(_e!.courierAddressId!, _e.destinationAddress ?? '#${_e.courierAddressId}');
  late MasterItem? _service = _e?.courierServiceId == null
      ? null
      : MasterItem(_e!.courierServiceId!, _e.courierName ?? '#${_e.courierServiceId}');
  String? _phone;
  late DateTime _pickup = _e?.pickupDate ?? DateTime.now();
  late String _day = _e?.pickupDay ?? Fmt.weekday(_pickup);
  late bool _auc = _e?.isAuc ?? false;
  late bool _pvt = _e?.isPvt ?? false;
  String? _photo;
  late Set<int> _postingIds = {...?_e?.postingListIds};
  late final _addressText = TextEditingController(text: _e?.destinationAddress);
  late final _courierName = TextEditingController(text: _e?.courierServiceId == null ? _e?.courierName : null);
  late final _tracking = TextEditingController(text: _e?.trackingNumber);
  late final _weight = TextEditingController(text: Fmt.editable(_e?.weight));
  late final _desc = TextEditingController(text: _e?.description);

  @override
  void dispose() {
    for (final c in [_addressText, _courierName, _tracking, _weight, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onBuyer(MasterItem? b) async {
    setState(() => _buyer = b);
    if (b == null) return;
    try {
      final a = await ref.read(courierRepositoryProvider).buyerAddress(b.id);
      if (!mounted) return;
      setState(() {
        if (a.address != null) _addressText.text = a.address!;
        _phone = [a.phone, if (a.whatsapp != null && a.whatsapp != a.phone) 'WhatsApp ${a.whatsapp}'].whereType<String>().join(' · ');
      });
    } catch (_) {}
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _ScannerScreen()));
    if (code != null) {
      setState(() => _tracking.text = code.replaceAll(RegExp('[^A-Za-z0-9]'), ''));
    }
  }

  Future<void> _addPhoto() async {
    final choice = await chooseAction(
      context,
      title: 'Add a photo',
      actions: const {'camera': 'Take photo', 'gallery': 'Choose from library'},
    );
    if (choice == null) return;
    final file = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 75, // keeps uploads small on field networks
    );
    if (file != null) setState(() => _photo = file.path);
  }

  Future<void> _pickPosting() async {
    final items = await ref.read(postingListsProvider.future);
    if (!mounted) return;
    if (items.isEmpty) {
      context.toast("Posting lists aren't available yet.");
      return;
    }
    final sel = await showMultiPickerSheet<int>(
      context,
      title: 'Posting lists',
      selected: _postingIds,
      options: [for (final p in items) PickOption(p.id, p.name)],
    );
    if (sel != null) setState(() => _postingIds = sel);
  }

  Future<void> _save() async {
    final tracking = _tracking.text.trim();
    final ok = await submit<bool>(
      () async {
        final repo = ref.read(courierRepositoryProvider);
        final body = <String, Object?>{
          'destination_type': _toBuyer ? 'buyer' : 'custom',
          'buyer_id': _toBuyer ? _buyer?.id : null,
          'courier_address_id': _toBuyer ? null : _address?.id,
          'courier_service_id': _service?.id,
          'courier_name': _service == null ? _courierName.text.trim() : _service!.name,
          'tracking_number': tracking,
          'destination_address': _addressText.text.trim(),
          'pickup_date': Fmt.api(_pickup),
          'pickup_day': _day,
          'is_auc': _auc,
          'is_pvt': _pvt,
          'weight': Fmt.parse(_weight.text),
          'description': _desc.text.trim(),
          'posting_list_ids': _postingIds.toList(),
        };
        if (_e == null) {
          await repo.create(body, photoPath: _photo);
        } else {
          await repo.update(_e.id, body);
        }
        return true;
      },
      clientErrors: {
        if (tracking.isEmpty) 'tracking_number': 'Enter or scan the tracking number.',
        if (tracking.isNotEmpty && !RegExp(r'^[A-Za-z0-9]+$').hasMatch(tracking)) 'tracking_number': 'Use letters and numbers only.',
        if (_toBuyer && _buyer == null) 'buyer_id': 'Choose a buyer.',
        if (!_toBuyer && _address == null) 'courier_address_id': 'Choose an address.',
      },
    );
    if (ok == true && mounted) {
      ref.invalidate(courierListProvider);
      refreshSummaries(ref);
      context.toast(_e == null ? 'Courier entry saved' : 'Courier entry updated');
      if (_e == null) {
        context.pop();
      } else {
        context.goNamed(Routes.courier);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final options = ref.watch(courierOptionsProvider).value;
    return FormScaffold(
      title: _e == null ? 'New courier entry' : 'Edit courier entry',
      submitLabel: _e == null ? 'Save entry' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        Segmented<bool>(
          options: const {true: 'Buyer', false: 'Custom address'},
          selected: _toBuyer,
          onChanged: (v) => setState(() => _toBuyer = v),
        ),
        GroupedSection(
          label: 'Destination',
          children: [
            if (_toBuyer)
              MasterPickerRow(label: 'Buyer', provider: buyersProvider, value: _buyer, onChanged: _onBuyer, error: err('buyer_id'))
            else
              ValueRow(
                label: 'Address',
                value: _address?.name,
                error: err('courier_address_id'),
                onTap: () async {
                  final list = options?.addresses ?? const <MasterItem>[];
                  if (list.isEmpty) {
                    context.toast('No saved addresses yet. Add one in the admin panel.');
                    return;
                  }
                  final a = await showPickerSheet<MasterItem>(
                    context,
                    title: 'Saved addresses',
                    options: [for (final a in list) PickOption(a, a.name)],
                  );
                  if (a != null) setState(() => _address = a);
                },
              ),
            FieldInput(
              label: 'Address',
              caption: _toBuyer && _buyer != null ? 'Filled from buyer' : null,
              hint: 'Plot 12, Tea Park, Kolkata 700001',
              controller: _addressText,
              maxLines: 3,
            ),
            if (_phone != null && _phone!.isNotEmpty) InfoRow('Phone', _phone),
          ],
        ),
        GroupedSection(
          label: 'Courier',
          children: [
            ValueRow(
              label: 'Service',
              value: _service?.name,
              placeholder: 'Type a name below',
              onTap: () async {
                final list = options?.services ?? const <MasterItem>[];
                if (list.isEmpty) {
                  context.toast('No courier services listed. Type the courier name.');
                  return;
                }
                final s = await showPickerSheet<MasterItem>(
                  context,
                  title: 'Courier service',
                  options: [for (final s in list) PickOption(s, s.name)],
                );
                if (s != null) setState(() => _service = s);
              },
            ),
            if (_service == null) FieldInput(label: 'Courier name', hint: 'Blue Dart Express', controller: _courierName),
            FieldInput(
              label: 'Tracking number',
              hint: 'BD98273491',
              controller: _tracking,
              error: err('tracking_number'),
              inputFormatters: alphanumericOnly,
              textCapitalization: TextCapitalization.characters,
              trailing: CircleIconButton(
                icon: CupertinoIcons.barcode_viewfinder,
                tinted: true,
                semanticLabel: 'Scan barcode',
                onPressed: _scan,
              ),
            ),
          ],
        ),
        GroupedSection(
          label: 'Pickup',
          children: [
            DateRow(
              label: 'Pickup date',
              value: _pickup,
              onChanged: (d) => setState(() {
                _pickup = d;
                _day = Fmt.weekday(d);
              }),
            ),
            ValueRow(
              label: 'Pickup day',
              value: _day,
              onTap: () async {
                final d = await showPickerSheet<String>(
                  context,
                  title: 'Pickup day',
                  selected: _day,
                  searchable: false,
                  options: [for (final d in _days) PickOption(d, d)],
                );
                if (d != null) setState(() => _day = d);
              },
            ),
            SwitchRow(label: 'Auction (AUC)', value: _auc, onChanged: (v) => setState(() => _auc = v)),
            SwitchRow(label: 'Private (PVT)', value: _pvt, onChanged: (v) => setState(() => _pvt = v)),
            FieldInput(
              label: 'Weight',
              hint: '2.5',
              suffix: 'kg',
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: decimalOnly,
            ),
            FieldInput(label: 'Description', hint: '5 sample packets for evaluation', controller: _desc, maxLines: 2),
            ValueRow(
              label: 'Posting lists',
              value: _postingIds.isEmpty ? null : '${_postingIds.length} selected',
              placeholder: 'None',
              onTap: _pickPosting,
            ),
          ],
        ),
        // A photo can only be attached when creating (edits are sent as JSON).
        if (_e == null)
          Row(
            children: [
              GestureDetector(
                onTap: _addPhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: ShapeDecoration(color: c.surface, shape: AppRadius.cardBorder, shadows: c.cardShadow),
                  child: _photo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.camera, color: c.accent),
                            const SizedBox(height: 2),
                            Text('Photo', style: AppText.caption.copyWith(color: c.accent)),
                          ],
                        )
                      : Icon(CupertinoIcons.checkmark_alt_circle_fill, color: c.success, size: 30),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _photo == null
                    ? Text('Add a photo of the parcel. Optional.', style: AppText.footnote.copyWith(color: c.textTertiary))
                    : Row(
                        children: [
                          Expanded(child: Text('Photo attached', style: AppText.callout)),
                          LinkButton(label: 'Remove', color: c.danger, onPressed: () => setState(() => _photo = null)),
                        ],
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final v = capture.barcodes.firstOrNull?.rawValue;
              if (v == null || _done) return;
              _done = true;
              Navigator.pop(context, v);
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: LinkButton(label: 'Cancel', color: Colors.white, onPressed: () => Navigator.pop(context)),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CourierDetailScreen extends StatelessWidget {
  const CourierDetailScreen({super.key, required this.entry});
  final CourierEntry? entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const MissingItemScreen(what: 'courier entry');
    return DetailScaffold(
      title: e.entryNo ?? 'Courier entry',
      actions: [
        LinkButton(
          label: 'Edit',
          onPressed: () => context.pushNamed(Routes.courierEdit, pathParameters: {'id': '${e.id}'}, extra: e),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Expanded(child: Text(e.trackingNumber ?? '–', style: AppText.headline)),
              if (e.isAuc)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: StatusBadge('AUC', tone: Tone.accent),
                ),
              if (e.isPvt)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: StatusBadge('PVT', tone: Tone.accent),
                ),
            ],
          ),
        ),
        GroupedSection(
          children: [
            InfoRow('Courier', e.courierName),
            InfoRow('Buyer', e.buyerName),
            InfoRow('Pickup', '${Fmt.day(e.pickupDate)}${e.pickupDay == null ? '' : ' · ${e.pickupDay}'}'),
            InfoRow('Weight', Fmt.kg(e.weight)),
            if (e.destinationAddress != null) InfoBlock('Address', e.destinationAddress!),
            if (e.description != null) InfoBlock('Description', e.description!),
          ],
        ),
        DeleteRecordButton(
          what: 'courier entry',
          name: [e.entryNo, e.trackingNumber].whereType<String>().join(' · '),
          onDelete: (ref) => ref.read(courierRepositoryProvider).delete(e.id),
          onDeleted: (ref) => ref.invalidate(courierListProvider),
        ),
      ],
    );
  }
}
