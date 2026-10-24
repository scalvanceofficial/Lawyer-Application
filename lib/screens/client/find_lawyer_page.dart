import 'package:flutter/material.dart';

import '../client_dashboard.dart' show FindLawyerPage;

/// Dedicated client route for discovering and filtering lawyers.
class ClientFindLawyerPage extends StatelessWidget {
  const ClientFindLawyerPage({
    super.key,
    required this.savedLawyerIds,
    required this.onSavedChanged,
  });

  final Set<String> savedLawyerIds;
  final Future<void> Function(String) onSavedChanged;

  @override
  Widget build(BuildContext context) => FindLawyerPage(
    savedLawyerIds: savedLawyerIds,
    onSavedChanged: onSavedChanged,
  );
}
