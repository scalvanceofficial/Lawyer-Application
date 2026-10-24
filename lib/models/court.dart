enum CourtType { supremeCourt, highCourt, districtCourt }

extension CourtTypeLabel on CourtType {
  String get label => switch (this) {
    CourtType.supremeCourt => 'Supreme Court',
    CourtType.highCourt => 'High Court',
    CourtType.districtCourt => 'District Court',
  };
}

class HighCourt {
  const HighCourt({
    required this.name,
    required this.seat,
    required this.benches,
    required this.statesCovered,
    required this.data,
  });

  final String name;
  final String seat;
  final List<String> benches;
  final List<String> statesCovered;
  final Map<String, dynamic> data;

  factory HighCourt.fromMap(Map<String, dynamic> map, {String? fallbackName}) {
    final name = _firstText(map, const [
      'name',
      'courtName',
      'court_name',
      'highCourtName',
      'high_court_name',
      'highcourt_name',
      'hc_name',
      'highcourt',
      'high_court',
      'High Court',
    ], fallback: fallbackName);
    return HighCourt(
      name: name,
      seat: (map['seat'] ?? '').toString().trim(),
      benches: _stringList(map['benches']),
      statesCovered: _stringList(map['statesCovered']),
      data: Map.unmodifiable(map),
    );
  }
}

List<String> _stringList(Object? value) => value is Iterable
    ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

class DistrictCourt {
  const DistrictCourt({
    required this.state,
    required this.district,
    required this.name,
    required this.data,
  });

  final String state;
  final String district;
  final String name;
  final Map<String, dynamic> data;

  factory DistrictCourt.fromMap(
    Map<String, dynamic> map, {
    String? fallbackState,
    String? fallbackDistrict,
    String? fallbackName,
  }) {
    return DistrictCourt(
      state: _firstText(map, const [
        'state',
        'stateName',
        'state_name',
        'State',
      ], fallback: fallbackState),
      district: _firstText(map, const [
        'district',
        'districtName',
        'district_name',
        'District',
      ], fallback: fallbackDistrict),
      name: _firstText(map, const [
        'name',
        'courtName',
        'court_name',
        'court_establishment_name',
        'establishment_name',
        'complex_name',
        'court',
        'Court Name',
      ], fallback: fallbackName),
      data: Map.unmodifiable(map),
    );
  }

  String get searchText => '$name $district $state'.toLowerCase();
}

String _firstText(
  Map<String, dynamic> map,
  List<String> keys, {
  String? fallback,
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  final normalizedKeys = keys
      .map((key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''))
      .toSet();
  for (final entry in map.entries) {
    final normalized = entry.key.toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    if (normalizedKeys.contains(normalized) &&
        entry.value is String &&
        (entry.value as String).trim().isNotEmpty) {
      return (entry.value as String).trim();
    }
  }
  return fallback?.trim() ?? '';
}
