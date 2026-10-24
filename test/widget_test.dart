import 'package:aapkelawyer/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user roles have the correct labels', () {
    expect(UserRole.client.label, 'User');
    expect(UserRole.lawyer.label, 'Advocate');
  });
}
