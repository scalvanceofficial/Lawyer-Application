import 'package:aapkelawyer/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionService.addMonths', () {
    test('preserves ordinary calendar dates', () {
      final result = SubscriptionService.addMonths(
        DateTime.utc(2026, 7, 23, 10),
        6,
      );

      expect(result, DateTime.utc(2027, 1, 23, 10));
    });

    test('clamps dates at the end of shorter months', () {
      final result = SubscriptionService.addMonths(
        DateTime.utc(2026, 1, 31),
        1,
      );

      expect(result, DateTime.utc(2026, 2, 28));
    });
  });
}
