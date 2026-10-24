import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../client_dashboard.dart' show ClientProfilePage;

/// Dedicated client profile route bound to the authenticated user document.
class ClientMyProfilePage extends StatelessWidget {
  const ClientMyProfilePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) => ClientProfilePage(profile: profile);
}
