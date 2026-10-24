import 'package:flutter/material.dart';

import '../client_dashboard.dart' show SavedLawyersPage;

/// Dedicated client route for lawyers saved from the directory.
class ClientSavedLawyersPage extends StatelessWidget {
  const ClientSavedLawyersPage({
    super.key,
    required this.savedLawyerIds,
    required this.onSavedChanged,
  });

  final Set<String> savedLawyerIds;
  final Future<void> Function(String) onSavedChanged;

  @override
  Widget build(BuildContext context) => SavedLawyersPage(
    savedLawyerIds: savedLawyerIds,
    onSavedChanged: onSavedChanged,
  );
}
