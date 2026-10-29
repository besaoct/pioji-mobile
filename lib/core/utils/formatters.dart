import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _num = NumberFormat.decimalPattern('en_IN');
  static final _day = DateFormat('d MMM yyyy');
  static final _dayShort = DateFormat('d MMM');
  static final _api = DateFormat('yyyy-MM-dd');
  static final _weekday = DateFormat('EEEE');
  static final _long = DateFormat('EEEE, d MMMM yyyy');
  static final _time = DateFormat('HH:mm');

  static String money(num? v) => v == null ? '–' : _inr.format(v);
  static String number(num? v) => v == null ? '–' : _num.format(v);
  static String kg(num? v) => v == null ? '–' : '${_num.format(v)} kg';
  static String day(DateTime? d) => d == null ? '–' : _day.format(d);
  static String dayShort(DateTime? d) => d == null ? '–' : _dayShort.format(d);
  static String longDay(DateTime d) => _long.format(d);
  static String time(DateTime d) => _time.format(d);
  static String weekday(DateTime d) => _weekday.format(d);

  /// The API's date format, `yyyy-MM-dd`.
  static String api(DateTime d) => _api.format(d);

  /// Trims trailing zeros for editable fields: 40.0 -> "40", 2.5 -> "2.5".
  static String editable(num? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static double? parse(String s) => double.tryParse(s.trim().replaceAll(',', ''));

  static String invoice(String? prefix, String? number) =>
      [prefix, number].whereType<String>().where((e) => e.isNotEmpty).join(' ');

  static String titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}
