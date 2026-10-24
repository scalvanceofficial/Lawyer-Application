import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/court.dart';

class CourtRepository {
  CourtRepository({FirebaseDatabase? database}) : _database = database;

  final FirebaseDatabase? _database;
  FirebaseDatabase get _resolvedDatabase =>
      _database ??
      FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://lawyer-417809-default-rtdb.firebaseio.com',
      );
  Future<List<HighCourt>>? _highCourtsCache;
  Future<List<DistrictCourt>>? _districtCourtsCache;

  Future<List<HighCourt>> fetchHighCourts() async {
    final cached = _highCourtsCache;
    if (cached != null) return cached;
    final request = _loadHighCourts();
    _highCourtsCache = request;
    try {
      return await request;
    } catch (_) {
      if (identical(_highCourtsCache, request)) _highCourtsCache = null;
      rethrow;
    }
  }

  Future<List<DistrictCourt>> fetchDistrictCourts() async {
    final cached = _districtCourtsCache;
    if (cached != null) return cached;
    final request = _loadDistrictCourts();
    _districtCourtsCache = request;
    try {
      return await request;
    } catch (_) {
      if (identical(_districtCourtsCache, request)) {
        _districtCourtsCache = null;
      }
      rethrow;
    }
  }

  Future<List<HighCourt>> _loadHighCourts() async {
    final snapshot = await _resolvedDatabase.ref('highcourtdata').get();
    return parseHighCourts(snapshot.value);
  }

  Future<List<DistrictCourt>> _loadDistrictCourts() async {
    final snapshot = await _resolvedDatabase.ref('masterData').get();
    return parseDistrictCourts(snapshot.value);
  }

  List<HighCourt> searchHighCourts(List<HighCourt> courts, String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return courts;
    return courts
        .where((court) => court.name.toLowerCase().contains(term))
        .toList();
  }

  List<DistrictCourt> searchDistrictCourts(
    List<DistrictCourt> courts,
    String query,
  ) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return courts;
    return courts.where((court) => court.searchText.contains(term)).toList();
  }

  List<HighCourt> parseHighCourts(Object? value) {
    if (value is! Map) return const [];
    final courts = <HighCourt>[];
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final data = Map<String, dynamic>.from(
        (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
      final court = HighCourt.fromMap(data, fallbackName: entry.key.toString());
      if (court.name.isNotEmpty) courts.add(court);
    }
    courts.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(courts);
  }

  List<DistrictCourt> parseDistrictCourts(Object? value) {
    if (value is! Map) return const [];
    final courts = <DistrictCourt>[];
    for (final stateEntry in value.entries) {
      if (stateEntry.value is! Map) continue;
      final stateData = stateEntry.value as Map;
      final state = (stateData['stateName'] ?? stateEntry.key)
          .toString()
          .trim();
      final districts = stateData['districts'];
      if (districts is! Map) continue;
      for (final districtEntry in districts.entries) {
        final district = districtEntry.key.toString().trim();
        if (districtEntry.value is! Map) continue;
        final courtValues = (districtEntry.value as Map)['courts'];
        if (courtValues is! Iterable) continue;
        for (final courtValue in courtValues) {
          final data = courtValue is Map
              ? Map<String, dynamic>.from(
                  courtValue.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : <String, dynamic>{'name': courtValue.toString()};
          final court = DistrictCourt.fromMap(
            data,
            fallbackState: state,
            fallbackDistrict: district,
            fallbackName: courtValue is String ? courtValue : null,
          );
          if (court.name.isNotEmpty) courts.add(court);
        }
      }
    }
    courts.sort((a, b) {
      final byState = a.state.compareTo(b.state);
      if (byState != 0) return byState;
      final byDistrict = a.district.compareTo(b.district);
      return byDistrict != 0 ? byDistrict : a.name.compareTo(b.name);
    });
    return List.unmodifiable(courts);
  }
}
