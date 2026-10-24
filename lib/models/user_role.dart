enum UserRole { client, lawyer }

extension UserRoleText on UserRole {
  String get label => this == UserRole.client ? 'User' : 'Advocate';
}
