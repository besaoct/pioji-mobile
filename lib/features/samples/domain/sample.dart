import '../../../core/utils/json.dart';
import '../../../core/widgets/status_badge.dart';

enum SampleStatus {
  received('received', 'Received', Tone.success),
  pendingEvaluation('pending_evaluation', 'Pending evaluation', Tone.warning),
  evaluated('evaluated', 'Evaluated', Tone.accent),
  assignedToBuyers('assigned_to_buyers', 'Assigned', Tone.accent),
  approved('approved', 'Approved', Tone.success),
  unknown('', 'Unknown', Tone.neutral);

  const SampleStatus(this.api, this.label, this.tone);
  final String api;
  final String label;
  final Tone tone;

  static SampleStatus parse(Object? v) =>
      values.firstWhere((s) => s.api == v?.toString(), orElse: () => unknown);

  static const pickable = [received, pendingEvaluation, evaluated, assignedToBuyers, approved];
}

class Sample {
  const Sample({
    required this.id,
    this.arrivalDate,
    this.gardenId,
    this.gardenName,
    this.grade,
    this.invoicePrefix,
    this.invoiceNo,
    this.packages,
    this.weight,
    this.totalKgs,
    this.sampleType,
    this.status = SampleStatus.unknown,
    this.statusRaw,
    this.remarks,
    this.batchId,
  });

  final int id;
  final DateTime? arrivalDate;
  final int? gardenId;
  final String? gardenName;
  final String? grade;
  final String? invoicePrefix;
  final String? invoiceNo;
  final int? packages;
  final double? weight;
  final double? totalKgs;
  final String? sampleType;
  final SampleStatus status;
  final String? statusRaw;
  final String? remarks;
  final int? batchId;

  String get title => [gardenName ?? 'Garden #${gardenId ?? '–'}', ?grade].join(' · ');
  String get statusLabel => status == SampleStatus.unknown ? (statusRaw ?? 'Unknown') : status.label;

  factory Sample.fromJson(Map<String, dynamic> j) => Sample(
        id: J.intOr(j['id'], 0),
        arrivalDate: J.date(j['arrival_date']),
        gardenId: J.integer(j['garden_id']),
        gardenName: J.nested(j, 'garden_name', 'garden'),
        grade: J.str(j['grade']),
        invoicePrefix: J.str(j['invoice_prefix']),
        invoiceNo: J.str(j['inv_no']) ?? J.str(j['invoice_no']),
        packages: J.integer(j['packages'] ?? j['pkgs']),
        weight: J.dbl(j['weight'] ?? j['nett']),
        totalKgs: J.dbl(j['total_kgs']),
        sampleType: J.str(j['sample_type']),
        status: SampleStatus.parse(j['status']),
        statusRaw: J.str(j['status']),
        remarks: J.str(j['remarks']),
        batchId: J.integer(j['batch_id']),
      );
}
