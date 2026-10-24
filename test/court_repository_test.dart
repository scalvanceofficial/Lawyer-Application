import 'package:aapkelawyer/repositories/court_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = CourtRepository();

  test('parses high courts using the Firebase object key as the name', () {
    final courts = repository.parseHighCourts({
      'Bombay High Court': {
        'benches': ['Nagpur', 'Aurangabad', 'Goa'],
        'seat': 'Mumbai',
        'statesCovered': ['Maharashtra', 'Goa'],
      },
    });

    expect(courts.single.name, 'Bombay High Court');
    expect(courts.single.seat, 'Mumbai');
    expect(courts.single.benches, contains('Nagpur'));
  });

  test('flattens masterData into searchable district court items', () {
    final courts = repository.parseDistrictCourts({
      'MH': {
        'districts': {
          'Mumbai': {
            'courts': ['Mumbai City Civil Court', 'Mumbai Small Cause Court'],
          },
          'Pune': {
            'courts': ['District Court Pune'],
          },
        },
        'stateName': 'Maharashtra',
      },
    });

    expect(courts, hasLength(3));
    expect(repository.searchDistrictCourts(courts, 'civil'), hasLength(1));
    expect(repository.searchDistrictCourts(courts, 'mumbai'), hasLength(2));
    expect(
      repository.searchDistrictCourts(courts, 'maharashtra'),
      hasLength(3),
    );
    expect(
      repository.searchDistrictCourts(courts, 'pune').single.name,
      'District Court Pune',
    );
  });
}
