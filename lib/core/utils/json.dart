/// Tolerant JSON readers: the API's exact shapes are not verified yet, so every
/// model reads through these instead of casting.
abstract final class J {
  static String? str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? integer(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
    return null;
  }

  static int intOr(Object? v, int fallback) => integer(v) ?? fallback;

  static double? dbl(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', ''));
    return null;
  }

  static bool boolOr(Object? v, bool fallback) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return fallback;
  }

  static DateTime? date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

  static Map<String, dynamic>? map(Object? v) => v is Map<String, dynamic> ? v : null;

  /// Reads `garden_name`, or `garden.name` when the API nests the relation.
  static String? nested(Map<String, dynamic> j, String flatKey, String relation,
      [String field = 'name']) {
    return str(j[flatKey]) ?? str(map(j[relation])?[field]);
  }

  /// A value that is either text or an object like `{code: "BP"}` / `{name: …}`.
  static String? code(Object? v) {
    if (v is Map) return str(v['code']) ?? str(v['name']) ?? str(v['grade_name']);
    return str(v);
  }

  static List<int> ints(Object? v) =>
      v is List ? v.map(integer).whereType<int>().toList() : const [];
}

/// Unwraps `{success, message, data}` and returns `data`, or the body itself.
Object? unwrap(Object? body) {
  if (body is Map<String, dynamic> && body.containsKey('data')) return body['data'];
  return body;
}

/// Drops null and empty values so GET query strings stay clean.
Map<String, dynamic> cleanQuery(Map<String, Object?> q) => {
      for (final e in q.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
    };

/// Drops nulls from a request body; keeps empty lists out too.
Map<String, dynamic> cleanBody(Map<String, Object?> b) => {
      for (final e in b.entries)
        if (e.value != null && !(e.value is String && (e.value as String).isEmpty) &&
            !(e.value is List && (e.value as List).isEmpty))
          e.key: e.value,
    };
